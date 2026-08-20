#!/usr/bin/env bash
# Create / request / destroy a UK South micro VM for grok/agy.
# Caps spend with a $5 monthly budget on this resource group only.
# Idle SSH → the VM deletes itself (managed identity).
# Account: info@deliverypilot.net / Azure subscription 1
set -euo pipefail

SUB="${AZURE_SUBSCRIPTION_ID:-b85b029d-9f7c-4c5a-8939-819480780c5d}"
RG="${AZURE_IDLE_RG:-dp-grok-idle-rg}"
LOC="${AZURE_IDLE_LOCATION:-westeurope}"
VM="${AZURE_IDLE_VM:-grok-idle}"
# B2ats_v2 (ARM) is cheaper but this subscription has 0 Basv2 quota in uksouth.
# Standard_B2s is BS-family (quota 10) — 2 vCPU / 4 GB, still <$5 if idle-deleted.
SKU="${AZURE_IDLE_SKU:-Standard_B2s}"
IMAGE="${AZURE_IDLE_IMAGE:-Canonical:ubuntu-24_04-lts:server:latest}"
ADMIN="${AZURE_IDLE_ADMIN:-azureuser}"
BUDGET_NAME="${AZURE_IDLE_BUDGET:-grok-idle-5usd}"
BUDGET_USD="${AZURE_IDLE_BUDGET_USD:-5}"
EMAIL="${AZURE_IDLE_EMAIL:-info@deliverypilot.net}"
SSH_KEY="${AZURE_IDLE_SSH_KEY:-$HOME/.ssh/grok-idle.pub}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLOUDINIT="${ROOT}/scripts/azure-idle-cloud-init.yaml"

usage() {
  cat <<'EOF'
Usage: ./scripts/azure-idle-vm.sh <command>

  infra     Resource group, NSG, $5 budget, action group (no VM)
  request   Create or recreate the VM (self-deletes when SSH idle)
  status    Show RG, VM, public IP, budget
  destroy   Delete the VM (+ NIC/IP/disk). Keeps RG + budget
  nuke      Delete the whole resource group (stops all idle-VM spend)

Requires: az login as info@deliverypilot.net
EOF
}

need_az() {
  command -v az >/dev/null
  az account set --subscription "$SUB"
  local user
  user="$(az account show --query user.name -o tsv)"
  if [ "$user" != "$EMAIL" ]; then
    echo "Expected Azure user ${EMAIL}, got ${user}" >&2
    exit 1
  fi
}

ensure_ssh_key() {
  local priv="${SSH_KEY%.pub}"
  if [ ! -f "$SSH_KEY" ]; then
    mkdir -p "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$priv" -N "" -C "grok-idle@deliverypilot"
    echo "Created ${priv}  (add the public key to Termius)"
  fi
}

cmd_infra() {
  need_az
  if az group show -n "$RG" >/dev/null 2>&1; then
    echo "RG ${RG} already exists"
  else
    az group create -n "$RG" -l "$LOC" --tags purpose=grok-idle costcap=5usd owner="$EMAIL" >/dev/null
  fi
  local nsg="${VM}-nsg-${LOC}"
  az network nsg create -g "$RG" -n "$nsg" -l "$LOC" >/dev/null
  az network nsg rule create -g "$RG" --nsg-name "$nsg" -n ssh \
    --priority 1000 --access Allow --protocol Tcp --direction Inbound \
    --destination-port-ranges 22 --source-address-prefixes Internet >/dev/null 2>&1 || true

  az monitor action-group create -n grok-idle-ag -g "$RG" --short-name grok5 \
    --action email owner "$EMAIL" >/dev/null

  local ag_id
  ag_id="$(az monitor action-group show -n grok-idle-ag -g "$RG" --query id -o tsv)"
  local start end
  start="$(date -u +%Y-%m-01)"
  end="$(date -u -v+1y +%Y-%m-01 2>/dev/null || date -u -d '+1 year' +%Y-%m-01)"

  python3 - "$SUB" "$RG" "$BUDGET_NAME" "$BUDGET_USD" "$EMAIL" "$ag_id" "$start" "$end" <<'PY'
import json, subprocess, sys
sub, rg, name, amount, email, ag, start, end = sys.argv[1:]
body = {
  "properties": {
    "category": "Cost",
    "amount": float(amount),
    "timeGrain": "Monthly",
    "timePeriod": {"startDate": start + "T00:00:00Z", "endDate": end + "T00:00:00Z"},
    "filter": {
      "dimensions": {
        "name": "ResourceGroupName",
        "operator": "In",
        "values": [rg],
      }
    },
    "notifications": {
      "Alert80": {
        "enabled": True,
        "operator": "GreaterThanOrEqualTo",
        "threshold": 80,
        "thresholdType": "Actual",
        "contactEmails": [email],
        "contactGroups": [ag],
        "contactRoles": ["Owner"],
      },
      "Alert100Stop": {
        "enabled": True,
        "operator": "GreaterThanOrEqualTo",
        "threshold": 100,
        "thresholdType": "Actual",
        "contactEmails": [email],
        "contactGroups": [ag],
        "contactRoles": ["Owner"],
      },
      "Forecast100": {
        "enabled": True,
        "operator": "GreaterThanOrEqualTo",
        "threshold": 100,
        "thresholdType": "Forecasted",
        "contactEmails": [email],
        "contactGroups": [ag],
      },
    },
  }
}
url = (
    f"https://management.azure.com/subscriptions/{sub}"
    f"/providers/Microsoft.CostManagement/budgets/{name}?api-version=2023-11-01"
)
subprocess.run(
    ["az", "rest", "--method", "put", "--url", url, "--body", json.dumps(body)],
    check=True,
)
print(f"Budget {name} = ${amount}/month on RG {rg}")
PY

  echo "Infra ready: RG=${RG} location=${LOC} budget=\$${BUDGET_USD}"
}

cmd_request() {
  need_az
  cmd_infra
  ensure_ssh_key
  if az vm show -g "$RG" -n "$VM" >/dev/null 2>&1; then
    echo "VM exists — starting"
    az vm start -g "$RG" -n "$VM" --no-wait
    az vm wait -g "$RG" -n "$VM" --updated
  else
    echo "Creating ${VM} ${SKU} in ${LOC}"
    az vm create \
      --resource-group "$RG" \
      --name "$VM" \
      --location "$LOC" \
      --image "$IMAGE" \
      --size "$SKU" \
      --admin-username "$ADMIN" \
      --ssh-key-values "$SSH_KEY" \
      --nsg "${VM}-nsg-${LOC}" \
      --public-ip-sku Standard \
      --os-disk-size-gb 30 \
      --os-disk-delete-option Delete \
      --nic-delete-option Delete \
      --assign-identity \
      --custom-data "$CLOUDINIT" \
      --tags purpose=grok-idle costcap=5usd owner="$EMAIL"
  fi
  local oid
  oid="$(az vm show -g "$RG" -n "$VM" --query identity.principalId -o tsv)"
  az role assignment create --assignee-object-id "$oid" --assignee-principal-type ServicePrincipal \
    --role Contributor --scope "$(az group show -n "$RG" --query id -o tsv)" >/dev/null 2>&1 || true
  az vm auto-shutdown -g "$RG" -n "$VM" --time 2100 --email "$EMAIL" >/dev/null 2>&1 || \
    az rest --method put \
      --url "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/microsoft.devtestlab/schedules/shutdown-computevm-${VM}?api-version=2018-09-15" \
      --body "{\"location\":\"${LOC}\",\"properties\":{\"status\":\"Enabled\",\"taskType\":\"ComputeVmShutdownTask\",\"dailyRecurrence\":{\"time\":\"2100\"},\"timeZoneId\":\"GMT Standard Time\",\"targetResourceId\":\"$(az vm show -g "$RG" -n "$VM" --query id -o tsv)\",\"notificationSettings\":{\"status\":\"Enabled\",\"emailRecipient\":\"${EMAIL}\",\"timeInMinutes\":30}}}" \
      >/dev/null || true
  cmd_status
}

cmd_status() {
  need_az
  echo "user:    $(az account show --query user.name -o tsv)"
  echo "rg:      $RG"
  if az group show -n "$RG" >/dev/null 2>&1; then
    az vm show -d -g "$RG" -n "$VM" --query "{name:name,state:powerState,ip:publicIps,sku:hardwareProfile.vmSize}" -o jsonc 2>/dev/null || echo "VM: not present (deleted/idle)"
  else
    echo "RG missing — run: $0 infra && $0 request"
  fi
}

cmd_destroy() {
  need_az
  az vm delete -g "$RG" -n "$VM" --yes --force-deletion true 2>/dev/null || true
  echo "VM deleted (RG + \$5 budget kept)"
}

cmd_nuke() {
  need_az
  az group delete -n "$RG" --yes --no-wait
  echo "Deleting resource group ${RG}"
}

main() {
  case "${1:-}" in
    infra) cmd_infra ;;
    request) cmd_request ;;
    status) cmd_status ;;
    destroy) cmd_destroy ;;
    nuke) cmd_nuke ;;
    -h|--help|help|"") usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
