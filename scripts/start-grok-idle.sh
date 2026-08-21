#!/usr/bin/env bash
# Start (or recreate) grok-idle and print SSH / Termius details. Never prints the private key.
# Slash command: /start   Page: ongoing-costs.html
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT}/scripts/azure-idle-vm.sh" start "$@"
