#!/usr/bin/env bash
# Delete the grok-idle Azure VM. Keeps RG + $5 budget so you can request again.
#   ./scripts/delete-azure-idle-vm.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/scripts/azure-idle-vm.sh" destroy "$@"
