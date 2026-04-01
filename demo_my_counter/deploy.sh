#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/my_counter"
DEPLOYED_ADDRESS_FILE="$SCRIPT_DIR/.contract_address"

RPC="http://localhost:8547"
PRIVATE_KEY="0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"

echo "=== Deploying Stylus Contract ==="

# Check testnode is running
if ! cast chain-id --rpc-url "$RPC" > /dev/null 2>&1; then
  echo "ERROR: Testnode is not running on $RPC"
  echo "       Run ./start.sh first."
  exit 1
fi

cd "$PROJECT_DIR"

# Deploy and capture output
OUTPUT=$(cargo stylus deploy \
  --endpoint "$RPC" \
  --private-key "$PRIVATE_KEY" 2>&1)

echo "$OUTPUT"

# Extract and save contract address (strip ANSI codes first)
CLEAN_OUTPUT=$(echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')
ADDRESS=$(echo "$CLEAN_OUTPUT" | grep -oE "deployed code at address: 0x[0-9a-fA-F]+" | grep -oE "0x[0-9a-fA-F]+")

if [ -z "$ADDRESS" ]; then
  echo ""
  echo "ERROR: Could not extract contract address from deploy output."
  exit 1
fi

echo "$ADDRESS" > "$DEPLOYED_ADDRESS_FILE"

echo ""
echo "=== Deployment complete ==="
echo "Contract address: $ADDRESS"
echo "Address saved to: $DEPLOYED_ADDRESS_FILE"
echo ""
echo "Run ./interact.sh to interact with the contract."
