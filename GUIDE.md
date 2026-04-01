# Running a Stylus Smart Contract Locally on Arbitrum

A step-by-step guide to setting up your environment, writing a Stylus (Rust) smart contract, deploying it to a local devnode, and interacting with it.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install the Rust Toolchain](#2-install-the-rust-toolchain)
3. [Install Docker](#3-install-docker)
4. [Install cargo-stylus CLI](#4-install-cargo-stylus-cli)
5. [Install Foundry (Cast)](#5-install-foundry-cast)
6. [Create a New Stylus Project](#6-create-a-new-stylus-project)
7. [Understand the Contract Code](#7-understand-the-contract-code)
8. [Run a Local Arbitrum Devnode](#8-run-a-local-arbitrum-devnode)
9. [Check, Deploy, and Activate the Contract](#9-check-deploy-and-activate-the-contract)
10. [Interact with the Contract](#10-interact-with-the-contract)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **Rust** | 1.88+ | Compiles the smart contract to WASM |
| **Docker** | Latest stable | Runs the local Arbitrum nitro-devnode |
| **cargo-stylus** | Latest | CLI for Stylus project creation, deployment, and management |
| **Foundry (cast)** | Latest | CLI for calling/sending transactions to deployed contracts |

---

## 2. Install the Rust Toolchain

Install Rust via `rustup`:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

After installation, verify:

```bash
rustup --version
rustc --version
cargo --version
```

Add the WASM compilation target:

```bash
rustup target add wasm32-unknown-unknown
```

---

## 3. Install Docker

Download and install Docker from [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/).

Verify:

```bash
docker --version
```

Make sure the Docker daemon is running before proceeding.

---

## 4. Install cargo-stylus CLI

Install the official Stylus CLI tool:

```bash
cargo install --force cargo-stylus
```

Verify:

```bash
cargo stylus --version
```

This provides commands for project scaffolding, WASM compilation checks, deployment, and activation.

---

## 5. Install Foundry (Cast)

Install Foundry (which includes `cast`):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify:

```bash
cast --version
```

`cast` is used to call view functions and send transactions to your deployed contract.

---

## 6. Create a New Stylus Project

Generate a new project from the Counter template:

```bash
cargo stylus new my_counter
cd my_counter
```

This scaffolds a complete Stylus project with:

- `src/lib.rs` — your contract code
- `Cargo.toml` — dependencies and build configuration
- A ready-to-compile project structure

### Recommended VS Code Extensions

- **rust-analyzer** — smart completion, inline errors
- **Error Lens** — inline diagnostics
- **Even Better TOML** — config file support

---

## 7. Understand the Contract Code

Open `src/lib.rs`. The generated Counter contract looks like this:

```rust
#![no_main]
#![no_std]
use stylus_sdk::{prelude::*, storage::StorageU256};

#[storage]
#[entrypoint]
pub struct Counter {
    count: StorageU256,
}

#[public]
impl Counter {
    /// Returns the current count value (free view call, no gas).
    pub fn number(&self) -> U256 {
        self.count.get()
    }

    /// Sets the counter to a specific value (state-changing, costs gas).
    pub fn set_number(&mut self, new_number: U256) {
        self.count.set(new_number);
    }

    /// Increments the counter by 1 (state-changing, costs gas).
    pub fn increment(&mut self) {
        let count = self.count.get();
        self.count.set(count + 1);
    }
}
```

### Key Concepts

| Rust / Stylus | Solidity Equivalent | Explanation |
|---------------|---------------------|-------------|
| `#[storage]` | State variables | Marks the struct as on-chain storage |
| `#[entrypoint]` | `contract` | Designates the main contract entry point |
| `StorageU256` | `uint256` | A 256-bit unsigned integer stored on-chain |
| `#[public]` | `public` functions | Exposes methods as callable contract functions |
| `&self` | `view` | Read-only access (no state modification) |
| `&mut self` | (default) | Mutable access (state modification) |
| `#![no_std]` | N/A | No standard library — required for WASM contracts |

---

## 8. Run a Local Arbitrum Devnode

The local devnode gives you a private Arbitrum chain with pre-funded wallets and zero gas costs for testing.

### Start the Devnode

Clone and run the Nitro devnode:

```bash
git clone https://github.com/OffchainLabs/nitro-devnode.git
cd nitro-devnode
./run-dev-node.sh
```

Or run directly with Docker:

```bash
docker run --rm -it -p 8547:8547 -p 8548:8548 offchainlabs/nitro-devnode:latest
```

The devnode exposes an RPC endpoint at `http://localhost:8547`.

### Pre-funded Development Account

The devnode comes with a pre-funded account for testing:

- **Private Key:** `0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659`
- **Address:** Derived from the key above

> This is a **development-only** key. Never use it on mainnet or testnets.

---

## 9. Check, Deploy, and Activate the Contract

Navigate back to your project directory and run through the full lifecycle.

### Step 1: Check (Validate WASM Compilation)

```bash
cargo stylus check \
  --endpoint http://localhost:8547
```

This compiles your Rust code to WASM and validates that it passes all safety checks (gas metering, depth-checking, memory charging) without actually deploying.

### Step 2: Deploy (Post WASM Bytecode On-Chain)

```bash
cargo stylus deploy \
  --endpoint http://localhost:8547 \
  --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
```

This will:
1. Compile the contract to WASM
2. Post the WASM bytecode to the local chain
3. Activate the contract (compile WASM to native machine code on-chain)
4. Output the **contract address** and **transaction hash**

**Save the contract address** — you'll need it for the next step.

Example output:

```
Contract deployed and activated at: 0x1234...abcd
Transaction hash: 0xabcd...1234
```

### Understanding Activation

- Activation is a **one-time process** per deployment
- During activation, safety checks run: gas metering, stack depth checking, memory charging
- Contracts must be **reactivated annually** (every 365 days) or after Stylus upgrades
- An expired contract becomes **uncallable** until reactivated

---

## 10. Interact with the Contract

Use `cast` to read and write to your deployed contract. Replace `<CONTRACT_ADDRESS>` with the address from the deploy step.

### Read the Current Counter Value (Free Call)

```bash
cast call <CONTRACT_ADDRESS> \
  "number()(uint256)" \
  --rpc-url http://localhost:8547
```

Expected output: `0` (the counter starts at zero).

### Set the Counter to a Specific Value

```bash
cast send <CONTRACT_ADDRESS> \
  "setNumber(uint256)" 42 \
  --rpc-url http://localhost:8547 \
  --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
```

### Verify the Value Was Set

```bash
cast call <CONTRACT_ADDRESS> \
  "number()(uint256)" \
  --rpc-url http://localhost:8547
```

Expected output: `42`.

### Increment the Counter

```bash
cast send <CONTRACT_ADDRESS> \
  "increment()" \
  --rpc-url http://localhost:8547 \
  --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
```

### Read Again to Confirm

```bash
cast call <CONTRACT_ADDRESS> \
  "number()(uint256)" \
  --rpc-url http://localhost:8547
```

Expected output: `43`.

---

## 11. Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| `cargo stylus` not found | Run `cargo install --force cargo-stylus` |
| WASM target missing | Run `rustup target add wasm32-unknown-unknown` |
| Docker devnode won't start | Ensure Docker daemon is running: `docker info` |
| Deployment fails with gas error | Make sure you're using the pre-funded private key |
| Contract calls return errors | Verify the contract was activated (check deploy output) |
| `cast` not found | Run `foundryup` to install/update Foundry tools |
| Expired contract (after 365 days) | Reactivate with `cargo stylus activate` |

### Useful Commands

```bash
# Check contract compiles correctly
cargo stylus check --endpoint http://localhost:8547

# Export the ABI (for frontend integration or Solidity interop)
cargo stylus export-abi

# Reactivate an expired contract
cargo stylus activate --endpoint http://localhost:8547 \
  --private-key <PRIVATE_KEY>
```

---

## Quick Reference: The Full Lifecycle

```
 Write          Check           Deploy          Activate         Interact
┌──────┐     ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Rust │ ──► │  WASM    │ ──►│ On-Chain │ ──►│  Native  │ ──►│  cast    │
│ Code │     │ Compile  │    │ Bytecode │    │  Code    │    │ call/send│
└──────┘     └──────────┘    └──────────┘    └──────────┘    └──────────┘
src/lib.rs   cargo stylus    cargo stylus    (automatic)     cast call
             check           deploy                          cast send
```

---

## Beyond Local: Deploying to Testnet and Mainnet

Once you're confident with local development, deploy to public networks:

### Arbitrum Sepolia Testnet

```bash
cargo stylus deploy \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc \
  --private-key <YOUR_TESTNET_PRIVATE_KEY>
```

Get free testnet ETH from an Arbitrum Sepolia faucet.

### Arbitrum One Mainnet

```bash
cargo stylus deploy \
  --endpoint https://arb1.arbitrum.io/rpc \
  --private-key <YOUR_MAINNET_PRIVATE_KEY>
```

Verify your deployment on [Arbiscan](https://arbiscan.io) using the contract address.

---

## Performance Notes: Ink vs Gas

Stylus introduces **ink**, a sub-gas unit for WASM execution:

- **1 gas = 10,000 ink** (default exchange rate)
- Users never see ink — transaction receipts show gas as usual
- A simple `ADD` costs ~0.0003 gas in Stylus vs 3 gas in EVM (**10,000x cheaper**)
- This makes compute-heavy operations (cryptography, ML inference, game physics) economically viable on-chain

---

## Resources

- [Arbitrum Stylus Documentation](https://docs.arbitrum.io/stylus/stylus-gentle-introduction)
- [Stylus SDK (Rust)](https://github.com/OffchainLabs/stylus-sdk-rs)
- [cargo-stylus CLI](https://github.com/OffchainLabs/cargo-stylus)
- [Nitro Devnode](https://github.com/OffchainLabs/nitro-devnode)
- [Foundry / Cast](https://book.getfoundry.sh/)
