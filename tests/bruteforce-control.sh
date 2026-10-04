#!/usr/bin/env bash
set -euo pipefail

B="${B:-http://127.0.0.1:18080}"
ATTEMPTS="${ATTEMPTS:-25}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT/tools/loopback_guard.py" "$B"

case "$ATTEMPTS" in
  ''|*[!0-9]*)
    echo "ATTEMPTS must be an integer" >&2
    exit 2
    ;;
esac

cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT

baseline=''
for ((attempt = 1; attempt <= ATTEMPTS; attempt++)); do
  response="$(curl -sS -b "$cookie_jar" -c "$cookie_jar" \
    "$B/engine.php?class=LoginForm&method=onLogin&static=1" \
    --data 'login=admin&password=definitely-wrong')"

  [[ "$response" == *'Senha inválida'* ]] || {
    echo "FAIL_unexpected_failure_response_at_$attempt" >&2
    exit 1
  }

  if [[ -z "$baseline" ]]; then
    baseline="$response"
  else
    [[ "$response" == "$baseline" ]] || {
      echo "FAIL_failure_response_changed_at_$attempt" >&2
      exit 1
    }
  fi
done

success="$(curl -sS -b "$cookie_jar" -c "$cookie_jar" \
  "$B/engine.php?class=LoginForm&method=onLogin&static=1" \
  --data 'login=admin&password=LabAdmin%21740')"

[[ "$success" == *"__adianti_load_page('index.php')"* ]] || {
  echo 'FAIL_account_locked_or_success_rejected' >&2
  exit 1
}

echo "PASS_no_account_lock_after_${ATTEMPTS}_failures"
