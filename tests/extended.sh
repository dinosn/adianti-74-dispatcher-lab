#!/usr/bin/env bash
# shellcheck disable=SC1003 # The SQLi corpus intentionally contains literal quotes.
set -euo pipefail

B="${B:-http://127.0.0.1:18080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$B" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "Refusing non-local base URL: $B" >&2
    exit 2
    ;;
esac

fail() {
  echo "FAIL_$1" >&2
  exit 1
}

assert_contains() {
  [[ "$2" == *"$3"* ]] || fail "$1"
  echo "PASS_$1"
}

headers="$(curl -sS -D - -o /dev/null "$B/")"
assert_contains cookie_name "$headers" 'PHPSESSID_AdiantiLab='

fatal_body="$(mktemp)"
trap 'rm -f "$fatal_body"' EXIT
fatal_status="$(curl -sS -o "$fatal_body" -w '%{http_code}' "$B/engine.php?class=LoginForm&method=__bogus__&static=1")"
[[ "$fatal_status" == '200' ]] || fail "fatal_status:$fatal_status"
echo 'PASS_fatal_status'
cmp -s "$ROOT/tests/expected-login-bogus.txt" "$fatal_body" || fail 'fatal_trace_exact'
echo 'PASS_fatal_trace_exact'

root="$(curl -sS "$B/")"
wrapped="$(curl -sS "$B/index.php?class=AnythingAtAll&method=__bogus__")"
[[ "$root" == "$wrapped" ]] || fail 'index_query_ignored'
echo 'PASS_index_query_ignored'

wrong="$(curl -sS "$B/engine.php?class=LoginForm&method=onLogin&static=1" --data 'login=admin&password=wrong')"
assert_contains known_user_wrong_password "$wrong" 'Senha inválida'

synthetic_success="$(curl -sS "$B/engine.php?class=LoginForm&method=onLogin&static=1" --data 'login=admin&password=LabAdmin%21740')"
assert_contains synthetic_login "$synthetic_success" "__adianti_load_page('index.php')"

missing_method="$(curl -sS "$B/engine.php?class=LoginForm&static=1")"
assert_contains missing_method_fatal "$missing_method" 'Method LoginForm::() does not exist'

for absent_method in onConfirm onSave; do
  reset_bogus="$(curl -sS "$B/engine.php?class=SystemPasswordResetForm&method=$absent_method&static=1")"
  assert_contains "reset_${absent_method}_fatal" "$reset_bogus" "Method SystemPasswordResetForm::$absent_method() does not exist"
done

request_bogus="$(curl -sS "$B/engine.php?class=SystemRequestPasswordResetForm&method=__bogus__&static=1")"
assert_contains request_reset_bogus_denied "$request_bogus" 'Permissão negada'

unknown="$(curl -sS "$B/engine.php?class=NoSuchClassZZ&method=onX&static=1")"
protected="$(curl -sS "$B/engine.php?class=SystemModulesCheckView&method=onShow&static=1")"
[[ "$unknown" == "$protected" ]] || fail 'permission_responses_equal'
echo 'PASS_permission_responses_equal'

for denied_class in AdiantiUploaderService AdiantiAutocompleteService AdiantiMultiSearchService TStandardSeek AdiantiHttpClient; do
  denied="$(curl -sS "$B/engine.php?class=$denied_class&method=show&static=1")"
  [[ "$denied" == "$unknown" ]] || fail "legacy_service_gate:$denied_class"
done
echo 'PASS_legacy_services_denied'

nonuser_baseline="$(curl -sS "$B/engine.php?class=LoginForm&method=onLogin&static=1" --data 'login=zzz&password=x')"
for payload in "'" '"' "x'" 'x"' '\' "' OR '1'='1" "admin'-- -" $'x\nOR 1=1'; do
  response="$(curl -sS "$B/engine.php?class=LoginForm&method=onLogin&static=1" \
    --data-urlencode "login=$payload" --data 'password=x')"
  [[ "$response" == *'Usuário não encontrado'* ]] || fail 'extended_sqli_body'
  [[ "$response" == "$nonuser_baseline" ]] || fail 'extended_sqli_differential'
  [[ "$response" != *'SQLSTATE'* && "$response" != *'PDOException'* ]] || fail 'extended_sqli_error'
done
echo 'PASS_extended_sqli_inert'

manifest="$(curl -sS "$B/manifest.json")"
assert_contains manifest "$manifest" '"lab_id": "adianti-74-dispatcher-lab-v1"'

shell="$(curl -sS "$B/")"
assert_contains shell_title "$shell" '<title> Adianti 7.4 Dispatcher Lab </title>'
assert_contains shell_nav "$shell" 'Authorization Routing Lab'
assert_contains shell_content_div "$shell" '<div id="adianti_div_content">'
assert_contains shell_runtime_name "$shell" "__adianti_set_name('AdiantiLab')"
assert_contains shell_runtime_language "$shell" "__adianti_set_language('pt')"
assert_contains shell_runtime_debug "$shell" '__adianti_set_debug(0)'
assert_contains register_commented "$shell" '<!-- <a href="index.php?class=SystemRegistrationForm">Criar conta</a> -->'
assert_contains reset_commented "$shell" '<!-- <a href="index.php?class=SystemRequestPasswordResetForm">Redefinir senha</a> -->'

expected_tail="<script language='JavaScript'>setTimeout( function() { __adianti_load_page('index.php?class=LoginForm&previous_class=SystemLoginForm'); }, 1 )</script>"
[[ "$shell" == *"$expected_tail" ]] || fail 'shell_tail_exact'
echo 'PASS_shell_tail_exact'

array_login="$(curl -sS "$B/engine.php?class=LoginForm&method=onLogin&static=1" --data 'login[]=x&password=x')"
assert_contains array_login_rejected "$array_login" 'O campo Login é obrigatório'
[[ "$array_login" != *'SQLSTATE'* && "$array_login" != *'PDOException'* ]] || fail 'array_login_error_leak'
echo 'PASS_array_login_no_error_leak'

for denied_path in \
  '/application.ini' \
  '/bootstrap.php' \
  '/app/config/lab.ini' \
  '/app/control/LoginForm.php' \
  '/app/model/SystemUser.php' \
  '/lib/adianti/core/AdiantiCoreApplication.php'; do
  denied_status="$(curl -sS -o /dev/null -w '%{http_code}' "$B$denied_path")"
  [[ "$denied_status" == '403' ]] || fail "source_path_status:$denied_path:$denied_status"
done
echo 'PASS_source_paths_denied'
