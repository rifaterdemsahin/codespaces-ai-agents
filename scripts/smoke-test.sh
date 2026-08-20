#!/usr/bin/env bash
# Local / CI checks. Never prints secret values.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
fail=0

ok() { echo "PASS  $*"; }
bad() { echo "FAIL  $*"; fail=1; }

need_file() {
  if [[ -f "$1" ]]; then ok "file $1"; else bad "missing $1"; fi
}

need_file ".devcontainer/devcontainer.json"
need_file ".devcontainer/post-create.sh"
need_file ".gitignore"
need_file "index.html"
need_file "iphone.html"
need_file "styles.css"
need_file "README.md"
need_file "SUBSCRIPTION.md"
need_file "AGENTS.md"
need_file ".env.example"
need_file "scripts/kv-env.sh"
need_file ".github/workflows/pages.yml"
need_file ".github/workflows/ci.yml"

if grep -q '^\.env$' .gitignore; then ok ".gitignore covers .env"; else bad ".gitignore missing .env"; fi
if grep -q 'devcontainer.zip' .gitignore 2>/dev/null; then ok "zip ignored"; else :; fi

if python3 -c 'import json,sys; json.load(open(".devcontainer/devcontainer.json"))' 2>/dev/null; then
  ok "devcontainer.json is valid JSON"
else
  bad "devcontainer.json is not valid JSON"
fi

if bash -n .devcontainer/post-create.sh && bash -n scripts/kv-env.sh && bash -n scripts/smoke-test.sh; then
  ok "shell scripts parse"
else
  bad "shell script syntax"
fi

if curl -fsSIL https://x.ai/cli/install.sh >/dev/null; then
  ok "grok install URL reachable"
else
  bad "grok install URL"
fi

if curl -fsSIL https://antigravity.google/cli/install.sh >/dev/null; then
  ok "agy install URL reachable"
else
  bad "agy install URL"
fi

if command -v az >/dev/null 2>&1 && az account show >/dev/null 2>&1; then
  if az keyvault show --name dp-kv-deliverypilot --query name -o tsv >/dev/null; then
    ok "Key Vault dp-kv-deliverypilot reachable"
  else
    bad "Key Vault not reachable"
  fi
  for n in xai-api-key ANTHROPIC-API-KEY OPENAI-API-KEY GEMINI-API-KEY-PRIMARY; do
    if az keyvault secret show --vault-name dp-kv-deliverypilot --name "$n" --query "length(value)" -o tsv >/dev/null; then
      ok "vault secret $n present"
    else
      bad "vault secret $n missing"
    fi
  done
else
  echo "SKIP  Azure login (CI or logged-out machine) — vault checks not run"
fi

# Guard against accidental secret commits. Exclude this file: the pattern
# strings live here and would be a false positive.
if git grep -I -E 'xai-[A-Za-z0-9]{20,}|sk-ant-|sk-or-' -- ':!scripts/smoke-test.sh' >/dev/null 2>&1; then
  bad "possible API key pattern in tracked files"
else
  ok "no obvious API key patterns in tracked files"
fi

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "All smoke checks passed."
  exit 0
fi
echo "Some checks failed."
exit 1
