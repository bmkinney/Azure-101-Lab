#!/usr/bin/env bash
# lab-teardown.sh — Permanently delete ALL lab resources after the lab is complete.
# Removes both resource groups, subscription-level resources (budget, policy
# assignments, diagnostic settings), and VNet flow logs from NetworkWatcherRG.
#
# ⚠️  THIS IS DESTRUCTIVE AND IRREVERSIBLE. All data, disks, and logs are lost.
#
# Usage:
#   ./scripts/lab-teardown.sh -g <lab-resource-group> [-n <lab-name>] [-l <location>] [--yes]
#
# Prerequisites:
#   - Azure CLI (az) authenticated with Contributor on the subscription
#   - bash 4+

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
LAB_NAME="azure101lab"
RESOURCE_GROUP=""
LOCATION=""
SKIP_CONFIRM=false

# ── Parse args ────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 -g <lab-resource-group> [-n <lab-name>] [-l <location>] [--yes]"
  echo "  -g     Lab resource group name (e.g., azure101lab-rg)"
  echo "  -n     Lab name prefix (default: azure101lab)"
  echo "  -l     Azure region (auto-detected from RG if omitted)"
  echo "  --yes  Skip confirmation prompt (for CI/CD use)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -g) RESOURCE_GROUP="$2"; shift 2 ;;
    -n) LAB_NAME="$2"; shift 2 ;;
    -l) LOCATION="$2"; shift 2 ;;
    --yes) SKIP_CONFIRM=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "ERROR: -g <lab-resource-group> is required." >&2
  usage
fi

SHARED_RG="${LAB_NAME}-shared-rg"
BUDGET_NAME="${LAB_NAME}-monthly-budget"
DIAG_NAME="${LAB_NAME}-activity-to-law"
VNET1_FLOWLOG="${LAB_NAME}-vnet1-flowlog"
VNET2_FLOWLOG="${LAB_NAME}-vnet2-flowlog"

# Auto-detect location from lab RG if not provided
if [[ -z "$LOCATION" ]]; then
  LOCATION=$(az group show --name "$RESOURCE_GROUP" --query "location" -o tsv 2>/dev/null | tr -d '\r' || echo "")
  if [[ -z "$LOCATION" ]]; then
    # Lab RG may already be gone, try shared RG
    LOCATION=$(az group show --name "$SHARED_RG" --query "location" -o tsv 2>/dev/null | tr -d '\r' || echo "")
  fi
fi

SUBSCRIPTION=$(az account show --query "name" -o tsv | tr -d '\r')
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv | tr -d '\r')

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Lab Cost Management — TEARDOWN                             ║"
echo "║  ⚠️  THIS WILL PERMANENTLY DELETE ALL LAB RESOURCES          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Subscription   : $SUBSCRIPTION"
echo "║  Lab RG          : $RESOURCE_GROUP"
echo "║  Shared RG       : $SHARED_RG"
echo "║  Location        : ${LOCATION:-unknown}"
echo "║  Budget          : $BUDGET_NAME"
echo "║  Policy          : audit-department-tag, audit-environment-tag"
echo "║  Diagnostic      : $DIAG_NAME"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Confirmation ──────────────────────────────────────────────────────────────
if [[ "$SKIP_CONFIRM" != true ]]; then
  echo "This action is IRREVERSIBLE. All VMs, disks, data, and logs will be deleted."
  echo ""
  read -rp "Type the lab name ($LAB_NAME) to confirm: " confirm
  if [[ "$confirm" != "$LAB_NAME" ]]; then
    echo "Confirmation failed. Aborting." >&2
    exit 1
  fi
  echo ""
fi

# ── Helper: delete resource if it exists ──────────────────────────────────────
delete_if_exists() {
  local label=$1
  shift
  echo "  ⏳ $label..."
  if "$@" 2>/dev/null; then
    echo "  ✓ $label"
  else
    echo "  ⚠ $label (not found or already removed)"
  fi
}

# ── 1. Delete VNet flow logs (in NetworkWatcherRG, before lab RG deletion) ────
echo "▶ Removing VNet flow logs from NetworkWatcherRG..."

if [[ -n "$LOCATION" ]]; then
  delete_if_exists "Deleting $VNET1_FLOWLOG" \
    az network watcher flow-log delete --name "$VNET1_FLOWLOG" --location "$LOCATION"
  delete_if_exists "Deleting $VNET2_FLOWLOG" \
    az network watcher flow-log delete --name "$VNET2_FLOWLOG" --location "$LOCATION"
else
  echo "  ⚠ Location unknown, skipping flow log cleanup"
fi

# ── 2. Delete lab resource group ──────────────────────────────────────────────
echo ""
echo "▶ Deleting lab resource group: $RESOURCE_GROUP..."

rg_exists=$(az group exists --name "$RESOURCE_GROUP" 2>/dev/null | tr -d '\r' || echo "false")
if [[ "$rg_exists" == "true" ]]; then
  az group delete --name "$RESOURCE_GROUP" --yes --no-wait
  echo "  ✓ Deletion initiated (runs in background)"
else
  echo "  ✓ Already removed"
fi

# ── 3. Delete shared resource group ──────────────────────────────────────────
echo ""
echo "▶ Deleting shared resource group: $SHARED_RG..."

shared_exists=$(az group exists --name "$SHARED_RG" 2>/dev/null | tr -d '\r' || echo "false")
if [[ "$shared_exists" == "true" ]]; then
  az group delete --name "$SHARED_RG" --yes --no-wait
  echo "  ✓ Deletion initiated (runs in background)"
else
  echo "  ✓ Already removed"
fi

# ── 4. Remove subscription-level budget ───────────────────────────────────────
echo ""
echo "▶ Removing subscription budget..."

delete_if_exists "Deleting budget: $BUDGET_NAME" \
  az consumption budget delete --budget-name "$BUDGET_NAME"

# ── 5. Remove policy assignments ─────────────────────────────────────────────
echo ""
echo "▶ Removing policy assignments..."

delete_if_exists "Deleting policy: audit-department-tag" \
  az policy assignment delete --name "audit-department-tag"

delete_if_exists "Deleting policy: audit-environment-tag" \
  az policy assignment delete --name "audit-environment-tag"

# ── 6. Remove activity log diagnostic setting ────────────────────────────────
echo ""
echo "▶ Removing activity log diagnostic setting..."

delete_if_exists "Deleting diagnostic: $DIAG_NAME" \
  az monitor diagnostic-settings subscription delete --name "$DIAG_NAME" --yes

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ Teardown initiated!"
echo ""
echo "  Resource group deletions run in the background and typically"
echo "  take 5-15 minutes to complete. Monitor progress:"
echo ""
echo "    az group exists --name $RESOURCE_GROUP"
echo "    az group exists --name $SHARED_RG"
echo ""
echo "  Subscription-level resources (budget, policies, diagnostics)"
echo "  have been removed immediately."
echo "════════════════════════════════════════════════════════════════"
