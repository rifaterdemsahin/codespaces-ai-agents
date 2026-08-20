#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Grok Build, Antigravity CLI, and Azure helpers"

export PATH="${HOME}/.grok/bin:${HOME}/.local/bin:${PATH}"

if ! command -v grok >/dev/null 2>&1; then
  echo "==> Installing grok"
  curl -fsSL https://x.ai/cli/install.sh | bash
else
  echo "==> grok already installed"
fi

if ! command -v agy >/dev/null 2>&1; then
  echo "==> Installing agy"
  curl -fsSL https://antigravity.google/cli/install.sh | bash
else
  echo "==> agy already installed"
fi

PROFILE="${HOME}/.bashrc"
touch "${PROFILE}"
if ! grep -q '.grok/bin' "${PROFILE}"; then
  {
    echo ''
    echo '# Grok Build + Antigravity'
    echo 'export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"'
  } >> "${PROFILE}"
fi

chmod +x scripts/*.sh 2>/dev/null || true

echo "==> Versions"
command -v grok && grok --version || echo "grok not on PATH yet (open a new terminal)"
command -v agy && agy --version || echo "agy not on PATH yet (open a new terminal)"
command -v az && az version --query '"azure-cli"' -o tsv || echo "az not on PATH yet"
command -v gh && gh --version | head -1 || echo "gh not on PATH yet"

echo
echo "==> Next steps (subscription login, no API keys by default)"
echo "    unset XAI_API_KEY"
echo "    grok login --device-auth     # approve the code on your phone"
echo "    agy                          # open the Google login URL on your phone"
echo
echo "==> Optional: Azure Key Vault (dp-kv-deliverypilot)"
echo "    az login --use-device-code"
echo "    ./scripts/kv-env.sh status"
echo "    ./scripts/kv-env.sh write            # common keys, not XAI"
echo "    ./scripts/kv-env.sh write --include-xai   # also writes XAI_API_KEY (pay-per-token)"
echo "    See SUBSCRIPTION.md and the GitHub Pages site"
