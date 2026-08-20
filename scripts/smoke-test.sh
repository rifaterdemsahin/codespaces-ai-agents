#!/usr/bin/env bash
# Wrapper for CI. Full suite: tests/test_system.py
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
exec python3 tests/test_system.py -v "$@"
