#!/bin/bash
# Quick execution script for Kestra Proxmox flows
# Usage: ./execute-flow.sh [flow-name] [inputs-file]

set -e

KESTRA_URL="${KESTRA_URL:-http://172.22.95.179:8080}"
FLOW_NAME="${1:-proxmox-vm-cloudinit}"
INPUTS_FILE="${2:-inputs-example.json}"

if [[ ! -f "$INPUTS_FILE" ]]; then
    echo "Error: Inputs file '$INPUTS_FILE' not found"
    echo "Usage: $0 [flow-name] [inputs-file]"
    echo "Example: $0 proxmox-vm-cloudinit inputs-example.json"
    exit 1
fi

echo "Executing flow: $FLOW_NAME"
echo "Kestra URL: $KESTRA_URL"
echo "Inputs file: $INPUTS_FILE"
echo ""

curl -X POST "$KESTRA_URL/api/v1/executions/$FLOW_NAME" \
  -H "Content-Type: application/json" \
  -d @"$INPUTS_FILE" \
  -s | jq '.'