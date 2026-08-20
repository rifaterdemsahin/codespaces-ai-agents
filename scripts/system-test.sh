#!/usr/bin/env bash
# Run the system tests. Never prints secret values.
#
#   ./scripts/system-test.sh
#   ./scripts/system-test.sh --json
#   ./scripts/system-test.sh --live     # grok -p READY (needs grok login)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
exec python3 tests/test_system.py "$@"
