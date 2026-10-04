#!/usr/bin/env bash
# shellcheck disable=SC2016 # PHP source patterns are intentionally literal.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core_version="$(tr -d '[:space:]' < "$ROOT/www/lib/VERSION")"
[[ "$core_version" == '7.4' ]] || {
  echo "FAIL_core_version:$core_version" >&2
  exit 1
}
echo 'PASS_core_version'

core_line="$(sed -n '79p' "$ROOT/www/lib/adianti/core/AdiantiCoreApplication.php")"
[[ "$core_line" == *'new ReflectionMethod($class, $method)'* ]] || {
  echo 'FAIL_core_line_79' >&2
  exit 1
}
echo 'PASS_core_line_79'

engine_parent_line="$(sed -n '37p' "$ROOT/www/engine.php")"
[[ "$engine_parent_line" == *'parent::run($debug)'* ]] || {
  echo 'FAIL_engine_line_37' >&2
  exit 1
}
echo 'PASS_engine_line_37'

engine_run_line="$(sed -n '66p' "$ROOT/www/engine.php")"
[[ "$engine_run_line" == *'TApplication::run()'* ]] || {
  echo 'FAIL_engine_line_66' >&2
  exit 1
}
echo 'PASS_engine_line_66'

grep -Fq 'prep = "1"' "$ROOT/www/app/config/lab.ini" || {
  echo 'FAIL_prepared_config' >&2
  exit 1
}
grep -Fq "SystemUser::where('login', '=', \$login)->first()" "$ROOT/www/app/control/LoginForm.php" || {
  echo 'FAIL_orm_lookup' >&2
  exit 1
}
grep -Fq 'prepare ( $sql->getInstruction( TRUE )' "$ROOT/www/lib/adianti/database/TRepository.php" || {
  echo 'FAIL_orm_prepare' >&2
  exit 1
}
grep -Fq 'execute ( $criteria->getPreparedVars() )' "$ROOT/www/lib/adianti/database/TRepository.php" || {
  echo 'FAIL_orm_bind' >&2
  exit 1
}
echo 'PASS_prepared_orm_path'

grep -Fq 'class LoginForm extends TPage' "$ROOT/www/app/control/LoginForm.php" || {
  echo 'FAIL_login_tpage_inheritance' >&2
  exit 1
}
grep -Fq 'class SystemPasswordResetForm extends TPage' "$ROOT/www/app/control/SystemPasswordResetForm.php" || {
  echo 'FAIL_reset_tpage_inheritance' >&2
  exit 1
}
grep -Fq "\$class  = isset(\$_GET['class'])" "$ROOT/www/lib/adianti/control/TPage.php" || {
  echo 'FAIL_tpage_get_class_dispatch' >&2
  exit 1
}
grep -Fq "\$method = isset(\$_GET['method'])" "$ROOT/www/lib/adianti/control/TPage.php" || {
  echo 'FAIL_tpage_get_method_dispatch' >&2
  exit 1
}
grep -Fq "\$class = isset(\$_REQUEST['class'])" "$ROOT/www/engine.php" || {
  echo 'FAIL_outer_request_dispatch' >&2
  exit 1
}
echo 'PASS_mixed_source_dispatch_path'

grep -Fq 'TSession::regenerate()' "$ROOT/www/app/control/LoginForm.php" || {
  echo 'FAIL_login_session_rotation' >&2
  exit 1
}
grep -Fq "\$user->active === 'N'" "$ROOT/www/app/control/LoginForm.php" || {
  echo 'FAIL_login_active_check' >&2
  exit 1
}
echo 'PASS_login_state_controls'

grep -Fq 'lab_id' "$ROOT/www/manifest.json" || {
  echo 'FAIL_lab_marker_missing' >&2
  exit 1
}
grep -Fq 'ipaddress.ip_address(address).is_loopback' "$ROOT/tools/f001_admin_access.py" || {
  echo 'FAIL_loopback_guard_missing' >&2
  exit 1
}
echo 'PASS_lab_only_boundary'

for excluded_path in \
  "$ROOT/www/lib/adianti/service/AdiantiUploaderService.php" \
  "$ROOT/www/lib/adianti/service/AdiantiAutocompleteService.php" \
  "$ROOT/www/lib/adianti/service/AdiantiMultiSearchService.php" \
  "$ROOT/www/lib/adianti/base/TStandardSeek.php" \
  "$ROOT/www/lib/adianti/http/AdiantiHttpClient.php"; do
  [[ ! -e "$excluded_path" ]] || {
    echo "FAIL_excluded_legacy_path:$excluded_path" >&2
    exit 1
  }
done
echo 'PASS_legacy_paths_excluded'
