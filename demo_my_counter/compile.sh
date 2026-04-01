#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/my_counter"

echo "=== Compiling Stylus Contract ==="

cd "$PROJECT_DIR"

# Build WASM
echo "[1/2] Building WASM..."
cargo build --release --target wasm32-unknown-unknown

# Check against the local testnode (if running)
RPC="http://localhost:8547"
if cast chain-id --rpc-url "$RPC" > /dev/null 2>&1; then
  echo "[2/2] Validating against testnode..."
  cargo stylus check --endpoint "$RPC"
else
  echo "[2/2] Testnode not running — skipping on-chain validation."
  echo "      Run ./start.sh first, then re-run this script to validate."
fi

echo ""
echo "=== Compilation complete ==="
echo "WASM output: target/wasm32-unknown-unknown/release/my_counter.wasm"
