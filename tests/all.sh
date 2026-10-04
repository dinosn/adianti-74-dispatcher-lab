#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"
./tests/static-audit.sh
./tests/parity.sh
./tests/extended.sh
./tests/bruteforce-control.sh
./tests/dispatcher-authorization-bypass.sh
./tests/f001-admin-access.sh
