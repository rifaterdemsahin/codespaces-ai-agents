#!/usr/bin/env bash
# Login to Azure (device code) and optionally write Key Vault secrets to .env.
# Never prints secret values.
set -euo pipefail

VAULT="${AZURE_KEY_VAULT:-dp-kv-deliverypilot}"
SUBSCRIPTION="${AZURE_SUBSCRIPTION:-Azure subscription 1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/.env"

usage() {
  cat <<'EOF'
Usage: ./scripts/kv-env.sh <command>

  status            Azure login check + list relevant secret names (no values)
  login             az login --use-device-code (Codespaces / SSH friendly)
  write             Write common AI keys to .env (does not write XAI_API_KEY)
  write --include-xai
                    Also write XAI_API_KEY from vault secret xai-api-key
                    This overrides Grok subscription login (pay-per-token).

Vault: dp-kv-deliverypilot (override with AZURE_KEY_VAULT)
EOF
}

need_az() {
  if ! command -v az >/dev/null 2>&1; then
    echo "Azure CLI (az) is not installed." >&2
    exit 1
  fi
}

ensure_login() {
  need_az
  if az account show >/dev/null 2>&1; then
    return 0
  fi
  echo "Not logged in to Azure. Starting device-code login..."
  az login --use-device-code >/dev/null
  az account set --subscription "${SUBSCRIPTION}" >/dev/null
}

secret_exists() {
  local name="$1"
  az keyvault secret show --vault-name "${VAULT}" --name "${name}" --query name -o tsv >/dev/null 2>&1
}

write_secret() {
  local kv_name="$1"
  local env_name="$2"
  if ! secret_exists "${kv_name}"; then
    echo "skip  ${env_name}  (vault secret ${kv_name} not found)"
    return 0
  fi
  local value
  value="$(az keyvault secret show --vault-name "${VAULT}" --name "${kv_name}" --query value -o tsv)"
  if [[ -z "${value}" ]]; then
    echo "skip  ${env_name}  (empty)"
    return 0
  fi
  if grep -q "^${env_name}=" "${ENV_FILE}" 2>/dev/null; then
    # Replace existing line without printing the value
    local tmp
    tmp="$(mktemp)"
    awk -v key="${env_name}" -v val="${value}" '
      BEGIN { done=0 }
      $0 ~ "^" key "=" { print key "=" val; done=1; next }
      { print }
      END { if (!done) print key "=" val }
    ' "${ENV_FILE}" > "${tmp}"
    mv "${tmp}" "${ENV_FILE}"
  else
    printf '%s=%s\n' "${env_name}" "${value}" >> "${ENV_FILE}"
  fi
  echo "wrote ${env_name}  (from ${kv_name}, ${#value} chars)"
}

cmd_status() {
  ensure_login
  echo "Azure user:  $(az account show --query user.name -o tsv)"
  echo "Subscription: $(az account show --query name -o tsv)"
  echo "Vault:       ${VAULT}"
  echo
  echo "Relevant secrets (names only):"
  local names=(
    xai-api-key
    XAI-GROK-API-KEY
    xai-alwayson-key
    ANTHROPIC-API-KEY
    OPENAI-API-KEY
    GEMINI-API-KEY-PRIMARY
    OPENROUTER-API-KEY
    FAL-AI-KEY
  )
  for n in "${names[@]}"; do
    if secret_exists "${n}"; then
      local len
      len="$(az keyvault secret show --vault-name "${VAULT}" --name "${n}" --query "length(value)" -o tsv)"
      echo "  OK   ${n}  (${len} chars)"
    else
      echo "  MISS ${n}"
    fi
  done
}

cmd_login() {
  need_az
  az login --use-device-code
  az account set --subscription "${SUBSCRIPTION}"
  az account show --query '{user:user.name,subscription:name}' -o jsonc
}

cmd_write() {
  local include_xai=0
  if [[ "${1:-}" == "--include-xai" ]]; then
    include_xai=1
  fi
  ensure_login
  touch "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"

  write_secret "ANTHROPIC-API-KEY" "ANTHROPIC_API_KEY"
  write_secret "OPENAI-API-KEY" "OPENAI_API_KEY"
  write_secret "GEMINI-API-KEY-PRIMARY" "GEMINI_API_KEY"
  write_secret "OPENROUTER-API-KEY" "OPENROUTER_API_KEY"
  write_secret "FAL-AI-KEY" "FAL_KEY"

  if [[ "${include_xai}" -eq 1 ]]; then
    echo "WARNING: writing XAI_API_KEY overrides Grok subscription login (pay-per-token)."
    write_secret "xai-api-key" "XAI_API_KEY"
  else
    echo "skipped XAI_API_KEY (pass --include-xai to write it from vault secret xai-api-key)"
  fi

  echo
  echo "Wrote ${ENV_FILE} (gitignored). Load with: set -a && source .env && set +a"
}

main() {
  local cmd="${1:-status}"
  shift || true
  case "${cmd}" in
    status) cmd_status ;;
    login) cmd_login ;;
    write) cmd_write "${1:-}" ;;
    -h|--help|help) usage ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
