#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
B="${B:-http://127.0.0.1:18080}"
OUT="$ROOT/tests/.tmp/f001-admin-access.json"
PAGE="$ROOT/tests/.tmp/f001-admin-users-page.html"

python3 "$ROOT/tools/loopback_guard.py" "$B"

mkdir -p "$ROOT/tests/.tmp"
rm -f "$OUT" "$PAGE"

python3 "$ROOT/tools/f001_admin_access.py" \
  --base-url "$B" \
  --login admin \
  --change-and-restore \
  --current-password 'LabAdmin!740' \
  --output "$OUT" \
  --page-output "$PAGE"

grep -Fq '"verdict": "passwordless_admin_access_and_reversible_password_change_confirmed"' "$OUT"
grep -Fq '"restored": true' "$OUT"
grep -Fq 'LAB_ADMIN_USER_LIST' "$PAGE"
if grep -Fq 'LabAdmin!740' "$OUT"; then
  echo 'FAIL_fixture_password_in_evidence' >&2
  exit 1
fi
echo 'PASS_f001_change_validate_restore'

if python3 "$ROOT/tools/f001_admin_access.py" --base-url 'http://192.0.2.1:18080' >/dev/null 2>&1; then
  echo 'FAIL_f001_remote_url_accepted' >&2
  exit 1
fi
echo 'PASS_f001_remote_url_rejected'

if python3 "$ROOT/tools/f001_admin_access.py" --proxy 'http://192.0.2.1:8080' >/dev/null 2>&1; then
  echo 'FAIL_f001_remote_proxy_accepted' >&2
  exit 1
fi
echo 'PASS_f001_remote_proxy_rejected'
