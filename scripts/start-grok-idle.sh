#!/usr/bin/env bash
# REFUSED: Azure grok-idle is too expensive. Does not create or start a VM.
# Slash command: /start   Page: ongoing-costs.html
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT}/scripts/azure-idle-vm.sh" start "$@"
