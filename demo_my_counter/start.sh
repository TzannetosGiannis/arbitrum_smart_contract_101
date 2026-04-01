#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTNODE_DIR="$REPO_ROOT/nitro-testnode"

echo "=== Starting Arbitrum Local Testnode ==="

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker Desktop first."
  exit 1
fi

# Clone testnode if not present
if [ ! -d "$TESTNODE_DIR" ]; then
  echo "Cloning nitro-testnode..."
  git clone -b release --recurse-submodules https://github.com/OffchainLabs/nitro-testnode.git "$TESTNODE_DIR"
fi

# Start the testnode
cd "$TESTNODE_DIR"
./test-node.bash --init

echo ""
echo "=== Testnode is running ==="
echo "L2 RPC:     http://localhost:8547"
echo "Chain ID:   412346"
echo "Funded key: 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"
echo "Funded addr: 0x3f1Eae7D46d88F08fc2F8ed27FCb2AB183EB2d0E"
