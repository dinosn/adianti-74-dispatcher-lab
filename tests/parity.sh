#!/usr/bin/env bash
# shellcheck disable=SC1003 # The SQLi corpus intentionally contains literal quotes.
set -euo pipefail

B="${B:-http://127.0.0.1:18080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT/tools/loopback_guard.py" "$B"

fail() {
  echo "FAIL_$1" >&2
  exit 1
}

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

request() {
  local name="$1"
  shift

  RESPONSE_STATUS="$(curl -sS -o "$response_file" -w '%{http_code}' "$@")"
  [[ "$RESPONSE_STATUS" == '200' ]] || fail "$name:status:$RESPONSE_STATUS"
  RESPONSE_BODY="$(<"$response_file")"
}

contains() {
  local name="$1"
  local body="$2"
  local needle="$3"

  [[ "$body" == *"$needle"* ]] || fail "$name"
  echo "PASS_$name"
}

request shell_status "$B/"
shell="$RESPONSE_BODY"
contains shell "$shell" 'Adianti 7.4 Dispatcher Lab'
contains bootstrap "$shell" "__adianti_load_page('index.php?class=LoginForm"

request login_req_status "$B/engine.php?class=LoginForm&method=onLogin&static=1" --data 'password=x'
body="$RESPONSE_BODY"
contains login_req "$body" 'O campo Login é obrigatório'

request pw_req_status "$B/engine.php?class=LoginForm&method=onLogin&static=1" --data 'login=zzz'
body="$RESPONSE_BODY"
contains pw_req "$body" 'O campo Senha é obrigatório'

request nouser_status "$B/engine.php?class=LoginForm&method=onLogin&static=1" --data 'login=zzz&password=x'
body="$RESPONSE_BODY"
contains nouser "$body" 'Usuário não encontrado'
nouser_baseline="$body"

for payload in "'" '"' "x'" "' OR '1'='1" "admin'-- -" 'x"' '\'; do
  request sqli_status "$B/engine.php?class=LoginForm&method=onLogin&static=1" \
    --data-urlencode "login=$payload" --data 'password=x'
  body="$RESPONSE_BODY"
  [[ "$body" == *'Usuário não encontrado'* ]] || fail "sqli_differential:$payload"
  [[ "$body" == "$nouser_baseline" ]] || fail "sqli_body_differential:$payload"
  [[ "$body" != *'SQLSTATE'* ]] || fail "sqli_error:$payload"
done
echo 'PASS_sqli_inert'

request reset_disabled_status "$B/engine.php?class=SystemRequestPasswordResetForm&method=onRequest&static=1" --data 'email=a@b.c'
body="$RESPONSE_BODY"
contains reset_disabled "$body" 'recuperação de senhas está desabilitada'

request empty_pw_status "$B/engine.php?class=SystemPasswordResetForm&method=onReset&static=1" --data 'key=z&password1=&password2='
body="$RESPONSE_BODY"
contains empty_pw "$body" 'Senha vazia'

request mismatch_status "$B/engine.php?class=SystemPasswordResetForm&method=onReset&static=1" --data 'key=z&password1=A1&password2=B2'
body="$RESPONSE_BODY"
contains mismatch "$body" 'As senhas não conferem'

request seed_guard_status "$B/engine.php?class=SystemPasswordResetForm&method=onReset&static=1" --data 'key=z&password1=A1&password2=A1'
body="$RESPONSE_BODY"
contains seed_guard "$body" 'nova seed é necessária'

request raw_fatal_status "$B/engine.php?class=LoginForm&method=__bogus__&static=1"
body="$RESPONSE_BODY"
contains raw_fatal "$body" 'Uncaught ReflectionException: Method LoginForm::__bogus__() does not exist'
contains path_leak "$body" '/var/www/html/lib/adianti/core/AdiantiCoreApplication.php'

RESPONSE_STATUS="$(curl -sS -o "$response_file" -w '%{http_code}' "$B/engine.php?class=NoSuchClassZZ&method=onX&static=1")"
[[ "$RESPONSE_STATUS" == '401' ]] || fail "perm_denied_status:$RESPONSE_STATUS"
body="$(<"$response_file")"
contains perm_denied "$body" 'Permissão negada'

request index_wrapped_status "$B/index.php?class=LoginForm&method=__bogus__"
body="$RESPONSE_BODY"
[[ "$body" != *'Uncaught ReflectionException'* ]] || fail 'index_leaks'
echo 'PASS_index_wrapped'
