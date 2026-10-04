# Local validation procedure

## Scope

This procedure validates only the disposable Compose lab in this repository.
All HTTP requests must remain on loopback. The expected web endpoint is
`http://127.0.0.1:18080`, and the database has no host-published port.

The seeded credentials are `admin` / `LabAdmin!740`. They are synthetic and
may be discarded with the database volume.

## Clean start

Remove prior containers and state before a validation run:

```bash
docker compose down -v --remove-orphans
docker compose up -d --build --wait
docker compose ps
```

Confirm that the web port is loopback-only:

```bash
docker compose port web 80
```

Expected mapping:

```text
127.0.0.1:18080
```

## Regression suite

Run the complete suite:

```bash
./tests/all.sh
```

The suite must complete with no `FAIL_` line. It covers:

- the Adianti 7.4 dispatcher and inherited page-dispatch source anchors;
- baseline shell and authentication behavior;
- prepared-query injection controls;
- reflection-error and wrapper controls;
- protected-class direct denial;
- mixed GET/POST and cookie/query dispatch conflicts;
- side-effect-free framework dispatch;
- repeated wrong-password behavior; and
- session and protected-route controls supplied by the local application.

The dispatcher authorization test must prove both sides of the oracle:

```text
direct protected request       -> denied
mixed request via public page  -> protected method reached
```

An HTTP success status alone is not a valid oracle. The response must contain
the expected protected marker, and the direct control must contain the denial
marker.

## Read-only F001 validation

```bash
mkdir -p tests/.tmp
python3 tools/f001_admin_access.py \
  --base-url http://127.0.0.1:18080 \
  --login admin \
  --page-output tests/.tmp/admin-users.html \
  --output tests/.tmp/f001-read.json
```

Required assertions:

1. Direct unauthenticated impersonation is denied.
2. The mixed-source request establishes a session for the exact synthetic
   `admin` identity.
3. The resulting session reads the administrator-only Users page.
4. The page contains the expected synthetic table structure and record.
5. An independent fresh session is denied access to the same page.
6. Logout invalidates the bypass-created session.
7. The post-logout request is denied.

The generated JSON must omit cookies, CSRF tokens, passwords, and response
bodies. Generated HTML and JSON belong under `tests/.tmp/` and must remain
untracked.

## Change-and-restore validation

Run the mutation workflow only against the clean loopback lab:

```bash
python3 tools/f001_admin_access.py \
  --base-url http://127.0.0.1:18080 \
  --login admin \
  --change-and-restore \
  --current-password 'LabAdmin!740' \
  --page-output tests/.tmp/admin-users-change.html \
  --output tests/.tmp/f001-change.json
```

Required password differential:

| Stage | Original password | Temporary password | Protected identity page |
|---|---:|---:|---|
| Before change | succeeds | fails | original session allowed |
| After change | fails | succeeds | temporary session allowed |
| After restoration | succeeds | fails | restored session allowed |

The workflow must also prove:

- the temporary password is generated in memory and is absent from output;
- invalid CSRF does not modify any user field;
- the valid change modifies only the password value;
- restoration uses a fresh authenticated session and fresh CSRF token;
- all non-password fields match their pre-change values;
- fresh and logged-out sessions remain denied; and
- success is reported only after the restored password authenticates and the
  temporary password fails.

If the process is interrupted or restoration cannot be proved, treat the run
as failed and recreate the database volume before any further validation:

```bash
docker compose down -v --remove-orphans
docker compose up -d --build --wait
```

## Optional proxy observation

Burp may listen on `127.0.0.1:8080` while the lab remains on port 18080:

```bash
python3 tools/f001_admin_access.py \
  --base-url http://127.0.0.1:18080 \
  --login admin \
  --proxy http://127.0.0.1:8080
```

The loopback guard applies even when a proxy is configured.

## Final cleanup

```bash
docker compose down -v --remove-orphans
rm -rf tests/.tmp
```

Confirm that no lab service remains published:

```bash
docker compose ps
```

## Verified reference run

On 2026-10-04, the full suite completed twice against the PHP 7.4.33/MySQL
5.7 Compose lab with no `FAIL_` result. The F001 workflow recorded 33 bounded
loopback requests and returned:

```text
verdict: passwordless_admin_access_and_reversible_password_change_confirmed
RESULT_request_count:33
RESULT_password_restored:True
PASS_f001_change_validate_restore
PASS_f001_remote_url_rejected
PASS_f001_remote_proxy_rejected
```

A separate read-only run through a temporary recording proxy observed all
eight expected requests at the proxy and ended with
`passwordless_admin_access_confirmed`.
