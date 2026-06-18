#!/usr/bin/env bash
# lab-status.sh — Show current state of lab resources.
# Quick check to see if VMs are running/deallocated and whether Bastion exists.
#
# Usage:
#   ./scripts/lab-status.sh -g <resource-group> [-n <lab-name>]
#
# Prerequisites:
#   - Azure CLI (az) authenticated with Reader on the lab RG

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
LAB_NAME="azure101lab"
RESOURCE_GROUP=""

# ── Parse args ────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 -g <resource-group> [-n <lab-name>]"
  echo "  -g  Resource group containing the lab resources"
  echo "  -n  Lab name prefix (default: azure101lab)"
  exit 1
}

while getopts "g:n:h" opt; do
  case $opt in
    g) RESOURCE_GROUP="$OPTARG" ;;
    n) LAB_NAME="$OPTARG" ;;
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

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Lab Cost Management — STATUS                               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Resource Group : $RESOURCE_GROUP"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── VM Status ─────────────────────────────────────────────────────────────────
get_vm_status() {
  local vm_name=$1
  local status
  status=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP" --name "$vm_name" \
    --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" -o tsv 2>/dev/null | tr -d '\r' || echo "Not Found")
  echo "$status"
}

vm1_status=$(get_vm_status "$VM1_NAME")
vm2_status=$(get_vm_status "$VM2_NAME")

echo "  Virtual Machines:"
printf "    %-30s %s\n" "$VM1_NAME" "$vm1_status"
printf "    %-30s %s\n" "$VM2_NAME" "$vm2_status"

# ── Bastion Status ────────────────────────────────────────────────────────────
echo ""
echo "  Azure Bastion:"
bastion_state=$(az network bastion show --resource-group "$RESOURCE_GROUP" --name "$BASTION_NAME" \
  --query "provisioningState" -o tsv 2>/dev/null | tr -d '\r' || echo "Not Deployed")
if [[ -z "$bastion_state" ]]; then bastion_state="Not Deployed"; fi
printf "    %-30s %s\n" "$BASTION_NAME" "$bastion_state"

pip_state=$(az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$BASTION_PIP_NAME" \
  --query "provisioningState" -o tsv 2>/dev/null | tr -d '\r' || echo "Not Deployed")
if [[ -z "$pip_state" ]]; then pip_state="Not Deployed"; fi
printf "    %-30s %s\n" "$BASTION_PIP_NAME" "$pip_state"

# ── Cost estimate ─────────────────────────────────────────────────────────────
echo ""
echo "  ────────────────────────────────────────────────────────────"

hourly_cost=0
if [[ "$vm1_status" == "VM running" ]]; then hourly_cost=$(echo "$hourly_cost + 0.05" | bc); fi
if [[ "$vm2_status" == "VM running" ]]; then hourly_cost=$(echo "$hourly_cost + 0.05" | bc); fi
if [[ "$bastion_state" == "Succeeded" ]]; then hourly_cost=$(echo "$hourly_cost + 0.19" | bc); fi

if command -v bc &>/dev/null; then
  daily_cost=$(echo "$hourly_cost * 24" | bc)
  echo "  Estimated running cost: ~\$$hourly_cost/hr (~\$$daily_cost/day)"
else
  echo "  Estimated running cost: ~\$$hourly_cost/hr"
fi

if [[ "$vm1_status" == "VM deallocated" && "$vm2_status" == "VM deallocated" && "$bastion_state" == "Not Deployed" ]]; then
  echo "  💤 Lab is fully stopped (no compute charges)"
elif [[ "$vm1_status" == "VM running" && "$vm2_status" == "VM running" && "$bastion_state" == "Succeeded" ]]; then
  echo "  🟢 Lab is fully running"
else
  echo "  ⚠️  Lab is in a mixed state"
fi
echo ""
