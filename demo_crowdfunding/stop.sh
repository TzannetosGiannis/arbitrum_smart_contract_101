#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTNODE_DIR="$REPO_ROOT/nitro-testnode"

echo "=== Stopping Arbitrum Local Testnode ==="

if [ ! -d "$TESTNODE_DIR" ]; then
  echo "ERROR: nitro-testnode directory not found. Nothing to stop."
  exit 1
fi

cd "$TESTNODE_DIR"
docker compose down

echo "=== Testnode stopped ==="
