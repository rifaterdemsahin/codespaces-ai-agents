#!/usr/bin/env bash
# Write the Termius key to the desktop (AirDrop that file). Does not print the key.
set -euo pipefail
OUT="${HOME}/Desktop/grok-idle"
az keyvault secret show --vault-name dp-kv-deliverypilot --name grok-idle-ssh-private-key --query value -o tsv > "$OUT"
chmod 600 "$OUT"
echo "Wrote ${OUT}  — AirDrop to iPhone → Termius → Keys → Import"
echo "Fingerprint (must match Termius):"
ssh-keygen -lf "$OUT.pub" 2>/dev/null || ssh-keygen -lf "$HOME/.ssh/grok-idle.pub"
