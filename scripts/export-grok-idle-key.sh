#!/usr/bin/env bash
# Write grok-idle + grok-idle-termius.zip to ~/Downloads for WhatsApp Document transfer.
# Does not print the key. Procedure: ops-whatsapp-key.html
set -euo pipefail
# Prefer local key; fall back to Key Vault. Never print the key.
if [ -f "$HOME/.ssh/grok-idle" ]; then
  SRC="$HOME/.ssh/grok-idle"
else
  TMP=$(mktemp)
  az keyvault secret show --vault-name dp-kv-deliverypilot --name grok-idle-ssh-private-key --query value -o tsv > "$TMP"
  SRC="$TMP"
fi
OUT_DIR="${HOME}/Downloads"
cp "$SRC" "$OUT_DIR/grok-idle"
chmod 600 "$OUT_DIR/grok-idle"
( cd "$OUT_DIR" && rm -f grok-idle-termius.zip && zip -j -X grok-idle-termius.zip grok-idle >/dev/null )
chmod 600 "$OUT_DIR/grok-idle-termius.zip"
echo "Wrote ${OUT_DIR}/grok-idle"
echo "Wrote ${OUT_DIR}/grok-idle-termius.zip  — send the ZIP as a WhatsApp Document to yourself"
echo "Fingerprint (must match Termius):"
ssh-keygen -lf "$HOME/.ssh/grok-idle.pub"
rm -f "${TMP:-}"
