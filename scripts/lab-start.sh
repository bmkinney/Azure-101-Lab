#!/usr/bin/env bash
# lab-start.sh — Start lab resources ahead of a scheduled lab session.
# Starts both VMs and recreates Azure Bastion + Public IP.
#
# Usage:
#   ./scripts/lab-start.sh -g <resource-group> [-n <lab-name>] [-l <location>]
#
# Prerequisites:
#   - Azure CLI (az) authenticated with Contributor on the lab RG
#   - bash 4+
#
# Recommendation: Run 30 minutes before lab to allow Azure Monitor Agent
# to populate Log Analytics with fresh metrics and logs.

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
LAB_NAME="azure101lab"
RESOURCE_GROUP=""
LOCATION=""

# ── Parse args ────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 -g <resource-group> [-n <lab-name>] [-l <location>]"
  echo "  -g  Resource group containing the lab VMs"
  echo "  -n  Lab name prefix (default: azure101lab)"
  echo "  -l  Azure region (auto-detected from RG if omitted)"
  exit 1
}

while getopts "g:n:l:h" opt; do
  case $opt in
    g) RESOURCE_GROUP="$OPTARG" ;;
    n) LAB_NAME="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "ERROR: -g <resource-group> is required." >&2
  usage
fi

VM1_NAME="${LAB_NAME}-vm1"
VM2_NAME="${LAB_NAME}-vm2"
BASTION_NAME="${LAB_NAME}-bastion"
BASTION_PIP_NAME="${LAB_NAME}-bastion-pip"
VNET_NAME="${LAB_NAME}-vnet1"

# Auto-detect location from resource group if not provided
if [[ -z "$LOCATION" ]]; then
  LOCATION=$(az group show --name "$RESOURCE_GROUP" --query "location" -o tsv | tr -d '\r')
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Lab Cost Management — START                                ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Resource Group : $RESOURCE_GROUP"
echo "║  Location       : $LOCATION"
echo "║  VMs            : $VM1_NAME, $VM2_NAME"
echo "║  Bastion        : $BASTION_NAME"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Start VMs (parallel) ─────────────────────────────────────────────────────
echo "▶ Starting VMs..."

start_vm() {
  local vm_name=$1
  local status
  status=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP" --name "$vm_name" \
    --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" -o tsv 2>/dev/null | tr -d '\r' || echo "NotFound")

  if [[ "$status" == "VM running" ]]; then
    echo "  ✓ $vm_name already running"
  elif [[ "$status" == "NotFound" ]]; then
    echo "  ✗ $vm_name not found — cannot start" >&2
    return 1
  else
    echo "  ⏳ Starting $vm_name (was: $status)..."
    az vm start --resource-group "$RESOURCE_GROUP" --name "$vm_name" --no-wait
  fi
}

start_vm "$VM1_NAME"
start_vm "$VM2_NAME"

echo "  ⏳ Waiting for VMs to reach running state..."
az vm wait --resource-group "$RESOURCE_GROUP" --name "$VM1_NAME" --custom "instanceView.statuses[?code=='PowerState/running']" 2>/dev/null || true
az vm wait --resource-group "$RESOURCE_GROUP" --name "$VM2_NAME" --custom "instanceView.statuses[?code=='PowerState/running']" 2>/dev/null || true
echo "  ✓ VMs running"

# ── Recreate Bastion Public IP ────────────────────────────────────────────────
echo ""
echo "▶ Ensuring Bastion Public IP exists..."

pip_exists=$(az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$BASTION_PIP_NAME" --query "name" -o tsv 2>/dev/null | tr -d '\r' || echo "")

if [[ -z "$pip_exists" ]]; then
  echo "  ⏳ Creating Public IP: $BASTION_PIP_NAME..."
  az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_PIP_NAME" \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static \
    --output none
  echo "  ✓ Public IP created"
else
  echo "  ✓ Public IP already exists"
fi

# ── Recreate Bastion ──────────────────────────────────────────────────────────
echo ""
echo "▶ Ensuring Azure Bastion exists..."

bastion_exists=$(az network bastion show --resource-group "$RESOURCE_GROUP" --name "$BASTION_NAME" --query "name" -o tsv 2>/dev/null | tr -d '\r' || echo "")

if [[ -z "$bastion_exists" ]]; then
  echo "  ⏳ Creating Bastion: $BASTION_NAME (this takes 3-5 minutes)..."
  az network bastion create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_NAME" \
    --location "$LOCATION" \
    --public-ip-address "$BASTION_PIP_NAME" \
    --vnet-name "$VNET_NAME" \
    --sku Basic \
    --output none
  echo "  ✓ Bastion created"
else
  echo "  ✓ Bastion already exists"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ Lab resources started!"
echo ""
echo "  Warm-up timeline:"
echo "     • VMs: Running now (SSH via Bastion available)"
echo "     • Azure Monitor Agent: ~5 min to reconnect"
echo "     • Log Analytics data: ~15-20 min for metrics/logs"
echo "     • Alerts: ~20-30 min for metric alerts to evaluate"
echo ""
echo "  💡 Tip: Start 30 min before lab for a fully populated"
echo "     monitoring experience (alerts, KQL queries, dashboards)."
echo "════════════════════════════════════════════════════════════════"
