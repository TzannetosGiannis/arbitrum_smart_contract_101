#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYED_ADDRESS_FILE="$SCRIPT_DIR/.contract_address"

RPC="http://localhost:8547"

# ─── Accounts ───────────────────────────────────────────────────
# Owner (pre-funded dev account) — creates the campaign and claims funds
OWNER_PK="0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"
OWNER_ADDR="0x3f1Eae7D46d88F08fc2F8ed27FCb2AB183EB2d0E"

# Three contributors — generated deterministically
ALICE_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
BOB_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
CHARLIE_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

# ─── Resolve contract address ───────────────────────────────────
if [ -n "${1:-}" ]; then
  CONTRACT="$1"
elif [ -f "$DEPLOYED_ADDRESS_FILE" ]; then
  CONTRACT=$(cat "$DEPLOYED_ADDRESS_FILE")
else
  echo "Usage: ./simulate.sh [CONTRACT_ADDRESS]"
  echo "No contract address. Run ./deploy.sh first."
  exit 1
fi

# ─── Helpers ────────────────────────────────────────────────────
fmt_eth() {
  cast from-wei "$1" 2>/dev/null || echo "$1 wei"
}

show_balance() {
  local label="$1" addr="$2"
  local bal
  bal=$(cast balance "$addr" --rpc-url "$RPC")
  echo "  $label: $(fmt_eth "$bal") ETH  ($addr)"
}

send_quiet() {
  cast send "$@" > /dev/null 2>&1
}

divider() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ─── Derive addresses ──────────────────────────────────────────
ALICE_ADDR=$(cast wallet address "$ALICE_PK")
BOB_ADDR=$(cast wallet address "$BOB_PK")
CHARLIE_ADDR=$(cast wallet address "$CHARLIE_PK")

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         CROWDFUNDING CONTRACT — LIVE SIMULATION             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Contract:  $CONTRACT"
echo "RPC:       $RPC"
echo ""
echo "Accounts:"
echo "  Owner:   $OWNER_ADDR"
echo "  Alice:   $ALICE_ADDR"
echo "  Bob:     $BOB_ADDR"
echo "  Charlie: $CHARLIE_ADDR"

divider

# ─── Step 0: Fund contributor accounts ─────────────────────────
echo "▸ STEP 0: Funding contributor accounts"
echo ""

send_quiet "$ALICE_ADDR"   --value 5ether  --rpc-url "$RPC" --private-key "$OWNER_PK"
send_quiet "$BOB_ADDR"     --value 5ether  --rpc-url "$RPC" --private-key "$OWNER_PK"
send_quiet "$CHARLIE_ADDR" --value 5ether  --rpc-url "$RPC" --private-key "$OWNER_PK"

echo "Balances after funding:"
show_balance "Owner  " "$OWNER_ADDR"
show_balance "Alice  " "$ALICE_ADDR"
show_balance "Bob    " "$BOB_ADDR"
show_balance "Charlie" "$CHARLIE_ADDR"

divider

# ─── Step 1: Initialize campaign ──────────────────────────────
echo "▸ STEP 1: Owner initializes campaign"
echo "  Goal: 1 ETH | Duration: 3600 seconds"
echo ""

# 1 ETH = 1000000000000000000 wei
GOAL="1000000000000000000"
DURATION=3600

send_quiet "$CONTRACT" "initialize(uint256,uint64)" "$GOAL" "$DURATION" \
  --rpc-url "$RPC" --private-key "$OWNER_PK"

GOAL_VAL=$(cast call "$CONTRACT" "goal()(uint256)" --rpc-url "$RPC")
DEADLINE_VAL=$(cast call "$CONTRACT" "deadline()(uint64)" --rpc-url "$RPC")
IS_ACTIVE=$(cast call "$CONTRACT" "isActive()(bool)" --rpc-url "$RPC")

echo "  ✓ Campaign initialized"
echo "  Goal:     $(fmt_eth "$GOAL_VAL") ETH"
echo "  Deadline: $DEADLINE_VAL (unix timestamp)"
echo "  Active:   $IS_ACTIVE"

divider

# ─── Step 2: Alice contributes 0.3 ETH ────────────────────────
echo "▸ STEP 2: Alice contributes 0.3 ETH"
echo ""

ALICE_BAL_BEFORE=$(cast balance "$ALICE_ADDR" --rpc-url "$RPC")

send_quiet "$CONTRACT" "contribute()" \
  --value 0.3ether --rpc-url "$RPC" --private-key "$ALICE_PK"

ALICE_BAL_AFTER=$(cast balance "$ALICE_ADDR" --rpc-url "$RPC")
TOTAL=$(cast call "$CONTRACT" "totalRaised()(uint256)" --rpc-url "$RPC")
ALICE_CONTRIB=$(cast call "$CONTRACT" "contributionOf(address)(uint256)" "$ALICE_ADDR" --rpc-url "$RPC")
CONTRACT_BAL=$(cast call "$CONTRACT" "balance()(uint256)" --rpc-url "$RPC")

echo "  ✓ Alice contributed 0.3 ETH"
echo "  Alice balance: $(fmt_eth "$ALICE_BAL_BEFORE") → $(fmt_eth "$ALICE_BAL_AFTER") ETH"
echo "  Alice's contribution on-chain: $(fmt_eth "$ALICE_CONTRIB") ETH"
echo "  Total raised: $(fmt_eth "$TOTAL") ETH"
echo "  Contract balance: $(fmt_eth "$CONTRACT_BAL") ETH"
echo "  Goal reached: $(cast call "$CONTRACT" "goalReached()(bool)" --rpc-url "$RPC")"

divider

# ─── Step 3: Bob contributes 0.4 ETH ──────────────────────────
echo "▸ STEP 3: Bob contributes 0.4 ETH"
echo ""

BOB_BAL_BEFORE=$(cast balance "$BOB_ADDR" --rpc-url "$RPC")

send_quiet "$CONTRACT" "contribute()" \
  --value 0.4ether --rpc-url "$RPC" --private-key "$BOB_PK"

BOB_BAL_AFTER=$(cast balance "$BOB_ADDR" --rpc-url "$RPC")
TOTAL=$(cast call "$CONTRACT" "totalRaised()(uint256)" --rpc-url "$RPC")
BOB_CONTRIB=$(cast call "$CONTRACT" "contributionOf(address)(uint256)" "$BOB_ADDR" --rpc-url "$RPC")
CONTRACT_BAL=$(cast call "$CONTRACT" "balance()(uint256)" --rpc-url "$RPC")

echo "  ✓ Bob contributed 0.4 ETH"
echo "  Bob balance: $(fmt_eth "$BOB_BAL_BEFORE") → $(fmt_eth "$BOB_BAL_AFTER") ETH"
echo "  Bob's contribution on-chain: $(fmt_eth "$BOB_CONTRIB") ETH"
echo "  Total raised: $(fmt_eth "$TOTAL") ETH"
echo "  Contract balance: $(fmt_eth "$CONTRACT_BAL") ETH"
echo "  Goal reached: $(cast call "$CONTRACT" "goalReached()(bool)" --rpc-url "$RPC")"

divider

# ─── Step 4: Charlie contributes 0.5 ETH (reaches goal!) ──────
echo "▸ STEP 4: Charlie contributes 0.5 ETH — this should reach the goal!"
echo ""

CHARLIE_BAL_BEFORE=$(cast balance "$CHARLIE_ADDR" --rpc-url "$RPC")

send_quiet "$CONTRACT" "contribute()" \
  --value 0.5ether --rpc-url "$RPC" --private-key "$CHARLIE_PK"

CHARLIE_BAL_AFTER=$(cast balance "$CHARLIE_ADDR" --rpc-url "$RPC")
TOTAL=$(cast call "$CONTRACT" "totalRaised()(uint256)" --rpc-url "$RPC")
CHARLIE_CONTRIB=$(cast call "$CONTRACT" "contributionOf(address)(uint256)" "$CHARLIE_ADDR" --rpc-url "$RPC")
CONTRACT_BAL=$(cast call "$CONTRACT" "balance()(uint256)" --rpc-url "$RPC")
GOAL_REACHED=$(cast call "$CONTRACT" "goalReached()(bool)" --rpc-url "$RPC")

echo "  ✓ Charlie contributed 0.5 ETH"
echo "  Charlie balance: $(fmt_eth "$CHARLIE_BAL_BEFORE") → $(fmt_eth "$CHARLIE_BAL_AFTER") ETH"
echo "  Charlie's contribution on-chain: $(fmt_eth "$CHARLIE_CONTRIB") ETH"
echo "  Total raised: $(fmt_eth "$TOTAL") ETH"
echo "  Contract balance: $(fmt_eth "$CONTRACT_BAL") ETH"
echo ""
echo "  ★ GOAL REACHED: $GOAL_REACHED ★"

divider

# ─── Step 5: Snapshot before claim ─────────────────────────────
echo "▸ STEP 5: Balance snapshot BEFORE owner claims"
echo ""

show_balance "Owner   " "$OWNER_ADDR"
show_balance "Contract" "$CONTRACT"
show_balance "Alice   " "$ALICE_ADDR"
show_balance "Bob     " "$BOB_ADDR"
show_balance "Charlie " "$CHARLIE_ADDR"

divider

# ─── Step 6: Owner claims the funds ───────────────────────────
echo "▸ STEP 6: Owner claims the raised funds"
echo ""

OWNER_BAL_BEFORE=$(cast balance "$OWNER_ADDR" --rpc-url "$RPC")

send_quiet "$CONTRACT" "claim()" \
  --rpc-url "$RPC" --private-key "$OWNER_PK"

OWNER_BAL_AFTER=$(cast balance "$OWNER_ADDR" --rpc-url "$RPC")
CONTRACT_BAL_AFTER=$(cast call "$CONTRACT" "balance()(uint256)" --rpc-url "$RPC")
CLAIMED=$(cast call "$CONTRACT" "claimed()(bool)" --rpc-url "$RPC")

echo "  ✓ Funds claimed by owner"
echo "  Owner balance:    $(fmt_eth "$OWNER_BAL_BEFORE") → $(fmt_eth "$OWNER_BAL_AFTER") ETH"
echo "  Contract balance: $(fmt_eth "$CONTRACT_BAL_AFTER") ETH (should be 0)"
echo "  Claimed flag:     $CLAIMED"

divider

# ─── Step 7: Final balance snapshot ───────────────────────────
echo "▸ STEP 7: Final balance snapshot"
echo ""

show_balance "Owner   " "$OWNER_ADDR"
show_balance "Contract" "$CONTRACT"
show_balance "Alice   " "$ALICE_ADDR"
show_balance "Bob     " "$BOB_ADDR"
show_balance "Charlie " "$CHARLIE_ADDR"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   SIMULATION COMPLETE                       ║"
echo "║                                                             ║"
echo "║  3 contributors funded the campaign:                        ║"
echo "║    Alice:   0.3 ETH                                        ║"
echo "║    Bob:     0.4 ETH                                        ║"
echo "║    Charlie: 0.5 ETH                                        ║"
echo "║  Total:     1.2 ETH (goal was 1 ETH)                       ║"
echo "║  Owner claimed all 1.2 ETH successfully.                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
