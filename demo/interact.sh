#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYED_ADDRESS_FILE="$SCRIPT_DIR/.contract_address"

RPC="http://localhost:8547"
PRIVATE_KEY="0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"

# Resolve contract address: argument > saved file
if [ -n "${1:-}" ]; then
  CONTRACT="$1"
elif [ -f "$DEPLOYED_ADDRESS_FILE" ]; then
  CONTRACT=$(cat "$DEPLOYED_ADDRESS_FILE")
else
  echo "Usage: ./interact.sh [CONTRACT_ADDRESS]"
  echo ""
  echo "No contract address provided and no previous deployment found."
  echo "Run ./deploy.sh first, or pass the address as an argument."
  exit 1
fi

echo "=== Interacting with Counter Contract ==="
echo "Contract: $CONTRACT"
echo "RPC:      $RPC"
echo ""

# 1. Read initial value
echo "--- 1. Read current counter ---"
VALUE=$(cast call "$CONTRACT" "number()(uint256)" --rpc-url "$RPC")
echo "counter = $VALUE"
echo ""

# 2. Set counter to 42
echo "--- 2. Set counter to 42 ---"
cast send "$CONTRACT" "setNumber(uint256)" 42 \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY" > /dev/null 2>&1
VALUE=$(cast call "$CONTRACT" "number()(uint256)" --rpc-url "$RPC")
echo "counter = $VALUE"
echo ""

# 3. Increment
echo "--- 3. Increment counter ---"
cast send "$CONTRACT" "increment()" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY" > /dev/null 2>&1
VALUE=$(cast call "$CONTRACT" "number()(uint256)" --rpc-url "$RPC")
echo "counter = $VALUE"
echo ""

# 4. Increment again
echo "--- 4. Increment counter again ---"
cast send "$CONTRACT" "increment()" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY" > /dev/null 2>&1
VALUE=$(cast call "$CONTRACT" "number()(uint256)" --rpc-url "$RPC")
echo "counter = $VALUE"
echo ""

echo "=== Done ==="
