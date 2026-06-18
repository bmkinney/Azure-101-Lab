#!/usr/bin/env bash
# lab-stop.sh — Deallocate lab resources to stop incurring cost.
# Stops both VMs and deletes Azure Bastion + its Public IP.
#
# Usage:
#   ./scripts/lab-stop.sh -g <resource-group> [-b <bastion-name>] [-n <lab-name>]
#
# Prerequisites:
#   - Azure CLI (az) authenticated with Contributor on the lab RG
#   - bash 4+

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
LAB_NAME="azure101lab"
RESOURCE_GROUP=""
BASTION_NAME=""

# ── Parse args ────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 -g <resource-group> [-n <lab-name>] [-b <bastion-name>]"
  echo "  -g  Resource group containing the lab VMs and Bastion"
  echo "  -n  Lab name prefix (default: azure101lab)"
  echo "  -b  Bastion host name (default: <lab-name>-bastion)"
  exit 1
}

while getopts "g:n:b:h" opt; do
  case $opt in
    g) RESOURCE_GROUP="$OPTARG" ;;
    n) LAB_NAME="$OPTARG" ;;
    b) BASTION_NAME="$OPTARG" ;;
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
BASTION_NAME="${BASTION_NAME:-${LAB_NAME}-bastion}"
BASTION_PIP_NAME="${LAB_NAME}-bastion-pip"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Lab Cost Management — STOP                                 ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Resource Group : $RESOURCE_GROUP"
echo "║  VMs            : $VM1_NAME, $VM2_NAME"
echo "║  Bastion        : $BASTION_NAME"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Deallocate VMs (parallel) ─────────────────────────────────────────────────
echo "▶ Deallocating VMs..."

deallocate_vm() {
  local vm_name=$1
  local status
  status=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP" --name "$vm_name" \
    --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" -o tsv 2>/dev/null || echo "NotFound")

  if [[ "$status" == "VM deallocated" ]]; then
    echo "  ✓ $vm_name already deallocated"
  elif [[ "$status" == "NotFound" ]]; then
    echo "  ⚠ $vm_name not found (skipping)"
  else
    echo "  ⏳ Deallocating $vm_name (was: $status)..."
    az vm deallocate --resource-group "$RESOURCE_GROUP" --name "$vm_name" --no-wait
  fi
}

deallocate_vm "$VM1_NAME"
deallocate_vm "$VM2_NAME"

# Wait for both deallocations to complete
echo "  ⏳ Waiting for VM deallocations to complete..."
az vm wait --resource-group "$RESOURCE_GROUP" --name "$VM1_NAME" --custom "instanceView.statuses[?code=='PowerState/deallocated']" 2>/dev/null || true
az vm wait --resource-group "$RESOURCE_GROUP" --name "$VM2_NAME" --custom "instanceView.statuses[?code=='PowerState/deallocated']" 2>/dev/null || true
echo "  ✓ VMs deallocated"

# ── Delete Bastion ────────────────────────────────────────────────────────────
echo ""
echo "▶ Removing Azure Bastion (cannot be stopped, must be deleted)..."

bastion_exists=$(az network bastion show --resource-group "$RESOURCE_GROUP" --name "$BASTION_NAME" --query "name" -o tsv 2>/dev/null || echo "")

if [[ -n "$bastion_exists" ]]; then
  echo "  ⏳ Deleting $BASTION_NAME..."
  az network bastion delete --resource-group "$RESOURCE_GROUP" --name "$BASTION_NAME" --no-wait
  echo "  ✓ Bastion deletion initiated"
else
  echo "  ✓ Bastion already removed"
fi

# ── Delete Bastion PIP ────────────────────────────────────────────────────────
echo ""
echo "▶ Removing Bastion Public IP..."

# Wait briefly for Bastion delete to release the PIP
sleep 5
pip_exists=$(az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$BASTION_PIP_NAME" --query "name" -o tsv 2>/dev/null || echo "")

if [[ -n "$pip_exists" ]]; then
  # PIP may still be attached if Bastion delete hasn't finished — retry with wait
  echo "  ⏳ Waiting for Bastion to fully delete before removing PIP..."
  for i in {1..12}; do
    bastion_check=$(az network bastion show --resource-group "$RESOURCE_GROUP" --name "$BASTION_NAME" --query "name" -o tsv 2>/dev/null || echo "")
    if [[ -z "$bastion_check" ]]; then break; fi
    sleep 10
  done
  az network public-ip delete --resource-group "$RESOURCE_GROUP" --name "$BASTION_PIP_NAME" 2>/dev/null || true
  echo "  ✓ Public IP removed"
else
  echo "  ✓ Public IP already removed"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ Lab resources stopped. Estimated savings: ~\$0.29/hr"
echo "     • 2x VMs deallocated (compute charges stopped, disks retained)"
echo "     • Bastion + PIP deleted"
echo ""
echo "  To restart before the next lab session:"
echo "    ./scripts/lab-start.sh -g $RESOURCE_GROUP"
echo "  (Recommend starting 30 min early for metrics/logs to populate)"
echo "════════════════════════════════════════════════════════════════"
