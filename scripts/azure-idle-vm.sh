#!/usr/bin/env bash
# Create / request / destroy a UK South micro VM for grok/agy.
# Caps spend with a $5 monthly budget on this resource group only.
# Idle SSH → the VM deletes itself (managed identity).
# Account: info@deliverypilot.net / Azure subscription 1
set -euo pipefail

SUB="${AZURE_SUBSCRIPTION_ID:-b85b029d-9f7c-4c5a-8939-819480780c5d}"
RG="${AZURE_IDLE_RG:-dp-grok-idle-rg}"
LOC="${AZURE_IDLE_LOCATION:-uksouth}"
VM="${AZURE_IDLE_VM:-grok-idle}"
# B2s/B4s failed (capacity / invalid size). D2s_v3 UK South succeeded 2026-08-20.
SKU="${AZURE_IDLE_SKU:-Standard_D2s_v3}"
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
  start     Create or start the VM, wait for SSH, print connection details
  request   Same as start (kept for older docs)
  status    Show RG, VM, public IP
  destroy   Delete the VM (+ NIC/disk). Keeps RG + budget + static IP
  delete    Same as destroy
  nuke      Delete the whole resource group (stops all idle-VM spend)

Requires: az login as info@deliverypilot.net
Never prints the private key.
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

create_vm() {
  local extra=()
  if az network public-ip show -g "$RG" -n "${VM}PublicIP" >/dev/null 2>&1; then
    echo "Reusing static IP ${VM}PublicIP"
    extra+=(--public-ip-address "${VM}PublicIP")
  else
    extra+=(--public-ip-sku Standard)
  fi
  if az network vnet show -g "$RG" -n "${VM}VNET" >/dev/null 2>&1; then
    extra+=(--vnet-name "${VM}VNET" --subnet "${VM}Subnet")
  fi
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
    --os-disk-size-gb 30 \
    --os-disk-delete-option Delete \
    --nic-delete-option Delete \
    --assign-identity \
    --custom-data "$CLOUDINIT" \
    --tags purpose=grok-idle costcap=5usd owner="$EMAIL" \
    "${extra[@]}"
}

post_create() {
  local oid
  oid="$(az vm show -g "$RG" -n "$VM" --query identity.principalId -o tsv)"
  az role assignment create --assignee-object-id "$oid" --assignee-principal-type ServicePrincipal \
    --role Contributor --scope "$(az group show -n "$RG" --query id -o tsv)" >/dev/null 2>&1 || true
  az vm auto-shutdown -g "$RG" -n "$VM" --time 2100 --email "$EMAIL" >/dev/null 2>&1 || \
    az rest --method put \
      --url "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/microsoft.devtestlab/schedules/shutdown-computevm-${VM}?api-version=2018-09-15" \
      --body "{\"location\":\"${LOC}\",\"properties\":{\"status\":\"Enabled\",\"taskType\":\"ComputeVmShutdownTask\",\"dailyRecurrence\":{\"time\":\"2100\"},\"timeZoneId\":\"GMT Standard Time\",\"targetResourceId\":\"$(az vm show -g "$RG" -n "$VM" --query id -o tsv)\",\"notificationSettings\":{\"status\":\"Enabled\",\"emailRecipient\":\"${EMAIL}\",\"timeInMinutes\":30}}}" \
      >/dev/null || true
}

wait_ssh() {
  local ip priv i
  ip="$(az vm show -d -g "$RG" -n "$VM" --query publicIps -o tsv)"
  priv="${SSH_KEY%.pub}"
  if [ -z "$ip" ]; then
    echo "No public IP yet" >&2
    return 1
  fi
  ssh-keygen -R "$ip" >/dev/null 2>&1 || true
  echo "Waiting for sshd on ${ip} (new VM = new host key)..."
  for i in $(seq 1 24); do
    if ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
      -i "$priv" "${ADMIN}@${ip}" 'true' >/dev/null 2>&1; then
      echo "SSH ready"
      return 0
    fi
    sleep 5
  done
  echo "SSH not ready after ~2 min — VM may still be booting" >&2
  return 1
}

print_connection() {
  local ip state priv fp
  ip="$(az vm show -d -g "$RG" -n "$VM" --query publicIps -o tsv 2>/dev/null || true)"
  state="$(az vm show -d -g "$RG" -n "$VM" --query powerState -o tsv 2>/dev/null || echo "not present")"
  priv="${SSH_KEY%.pub}"
  fp="$(ssh-keygen -lf "${priv}.pub" 2>/dev/null | awk '{print $2}' || true)"
  cat <<EOF

=== grok-idle connection ===
state:     ${state}
host:      ${ip:-unknown}
port:      22
user:      ${ADMIN}
key file:  ${priv}
client fp: ${fp:-unknown}
ssh:       ssh -i ${priv} ${ADMIN}@${ip}

Termius
  Address   ${ip}
  Port      22
  Username  ${ADMIN}
  Key       grok-idle   (Import / Paste Key — never Export Key)
  Host key  accept if it changed (idle-delete recreates the VM)

Idle-delete: ~20 min with no SSH (8 min grace after boot)
Costs:       see ongoing-costs.html  (static IP still bills while VM is gone)
EOF
}

cmd_start() {
  need_az
  if az group show -n "$RG" >/dev/null 2>&1; then
    echo "RG ${RG} exists"
  else
    cmd_infra
  fi
  ensure_ssh_key
  if az vm show -g "$RG" -n "$VM" >/dev/null 2>&1; then
    local state
    state="$(az vm show -d -g "$RG" -n "$VM" --query powerState -o tsv)"
    if echo "$state" | grep -qi running; then
      echo "VM already running"
    else
      echo "Starting existing VM (${state})"
      az vm start -g "$RG" -n "$VM"
    fi
  else
    create_vm
    post_create
  fi
  wait_ssh || true
  print_connection
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
    start|request) cmd_start ;;
    status) cmd_status ;;
    destroy|delete) cmd_destroy ;;
    nuke) cmd_nuke ;;
    -h|--help|help|"") usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
