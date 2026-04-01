# Running a Stylus Smart Contract Locally on Arbitrum

A step-by-step guide to setting up your environment, writing a Stylus (Rust) smart contract, deploying it to a local testnode, and interacting with it.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install the Rust Toolchain](#2-install-the-rust-toolchain)
3. [Install Docker](#3-install-docker)
4. [Install cargo-stylus CLI](#4-install-cargo-stylus-cli)
5. [Install Foundry (Cast)](#5-install-foundry-cast)
6. [Create a New Stylus Project](#6-create-a-new-stylus-project)
7. [Understand the Contract Code](#7-understand-the-contract-code)
8. [Run a Local Arbitrum Testnode](#8-run-a-local-arbitrum-testnode)
9. [Check, Deploy, and Activate the Contract](#9-check-deploy-and-activate-the-contract)
10. [Interact with the Contract](#10-interact-with-the-contract)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **Rust** | 1.91.0 | Compiles the smart contract to WASM (required by stylus-sdk 0.10.2) |
| **Docker** | Latest stable | Runs the local Arbitrum nitro-testnode |
| **cargo-stylus** | 0.10.2 | CLI for Stylus project creation, deployment, and management |
| **Foundry (cast)** | Latest | CLI for calling/sending transactions to deployed contracts |

---

## 2. Install the Rust Toolchain

Install Rust via `rustup`:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

After installation, source the environment and verify:

```bash
source "$HOME/.cargo/env"
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

Make sure the Docker daemon is running before proceeding. On macOS, open Docker Desktop from Applications.

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

Create the project directory:

```bash
mkdir my_counter && cd my_counter
mkdir src
```

### Cargo.toml

Create `Cargo.toml` with the following content. Only `stylus-sdk` is needed as a direct dependency — the compatible versions of `alloy-primitives` and `alloy-sol-types` are resolved automatically as transitive dependencies.

```toml
[package]
name = "my_counter"
version = "0.1.0"
edition = "2021"

[dependencies]
stylus-sdk = "0.10.2"

[dev-dependencies]
tokio = "1.44"

[features]
export-abi = ["stylus-sdk/export-abi"]

[lib]
crate-type = ["lib", "cdylib"]
```

### rust-toolchain.toml

Pin the Rust version to 1.91.0 (required by stylus-sdk 0.10.2) and include the WASM target:

```toml
[toolchain]
channel = "1.91.0"
targets = ["wasm32-unknown-unknown"]
```

### Stylus.toml

Create a minimal Stylus configuration file:

```toml
[workspace]

[workspace.networks]

[contract]
```

### Project Structure

After setup, your project should look like this:

```
my_counter/
├── Cargo.toml
├── Stylus.toml
├── rust-toolchain.toml
└── src/
    ├── lib.rs          # Contract logic
    └── main.rs         # ABI export entrypoint (required for deployment)
```

### Recommended VS Code Extensions

- **rust-analyzer** — smart completion, inline errors
- **Error Lens** — inline diagnostics
- **Even Better TOML** — config file support

---

## 7. Understand the Contract Code

### src/lib.rs

This is the main contract file. Create `src/lib.rs` with the following content:

```rust
#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

use stylus_sdk::{alloy_primitives::U256, prelude::*, storage::StorageU256};

#[storage]
#[entrypoint]
pub struct Counter {
    number: StorageU256,
}

#[public]
impl Counter {
    /// Returns the current count value.
    pub fn number(&self) -> Result<U256, Vec<u8>> {
        Ok(self.number.get())
    }

    /// Sets the counter to a specific value.
    pub fn set_number(&mut self, number: U256) -> Result<(), Vec<u8>> {
        self.number.set(number);
        Ok(())
    }

    /// Increments the counter by 1.
    pub fn increment(&mut self) -> Result<(), Vec<u8>> {
        let number = self.number.get() + U256::from(1);
        self.number.set(number);
        Ok(())
    }
}
```

### src/main.rs

This file is **required** for `cargo stylus deploy` to work. It provides the ABI export entrypoint that the CLI uses to check for constructors and generate the ABI.

```rust
#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]

#[cfg(not(any(test, feature = "export-abi")))]
#[no_mangle]
pub extern "C" fn main() {}

#[cfg(feature = "export-abi")]
fn main() {
    my_counter::print_from_args();
}
```

> **Note:** `print_from_args()` is a function automatically generated by the `#[entrypoint]` macro in `lib.rs`. It prints the contract's ABI to stdout.

### Key Concepts

| Rust / Stylus | Solidity Equivalent | Explanation |
|---------------|---------------------|-------------|
| `#[storage]` | State variables | Marks the struct as on-chain storage |
| `#[entrypoint]` | `contract` | Designates the main contract entry point |
| `StorageU256` | `uint256` | A 256-bit unsigned integer stored on-chain |
| `#[public]` | `public` functions | Exposes methods as callable contract functions |
| `&self` | `view` | Read-only access (no state modification) |
| `&mut self` | (default) | Mutable access (state modification) |
| `Result<T, Vec<u8>>` | revert | All public methods return `Result` for error handling |
| `extern crate alloc` | N/A | Required — the SDK uses the `alloc` crate internally |
| `cfg_attr(... no_main)` | N/A | Conditional — `no_main` for WASM, normal main for ABI export |

### Solidity Comparison

For reference, here's the equivalent Solidity contract:

```solidity
pragma solidity ^0.8.0;

contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
```

### Build the Contract

Verify everything compiles to WASM:

```bash
cargo build --release --target wasm32-unknown-unknown
```

---

## 8. Run a Local Arbitrum Testnode

The local testnode gives you a private Arbitrum chain with pre-funded wallets for testing.

> **Important:** There is no single Docker image for the devnode. The testnode is a multi-container setup orchestrated by a script.

### Start the Testnode

Clone and initialize the Nitro testnode:

```bash
git clone -b release --recurse-submodules https://github.com/OffchainLabs/nitro-testnode.git
cd nitro-testnode
./test-node.bash --init
```

This starts multiple containers via Docker Compose:
- **L1 geth** (dev chain) on `localhost:8545`
- **L2 sequencer** (Nitro/Stylus chain) on `localhost:8547` (HTTP) and `localhost:8548` (WS)
- Plus validators, batch posters, and other infrastructure

The L2 RPC endpoint you'll use is `http://localhost:8547`.

### Verify the Testnode is Running

```bash
cast chain-id --rpc-url http://localhost:8547
```

Expected output: `412346` (the default Nitro testnode L2 chain ID).

### Pre-funded Development Account

The testnode comes with a pre-funded account for testing:

- **Private Key:** `0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659`
- **Address:** `0x3f1Eae7D46d88F08fc2F8ed27FCb2AB183EB2d0E`

Check the balance:

```bash
cast balance 0x3f1Eae7D46d88F08fc2F8ed27FCb2AB183EB2d0E --rpc-url http://localhost:8547
```

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

Expected output includes:

```
contract size: 5.2 KB (5156 bytes)
wasm data fee: 0.000069 ETH
```

### Step 2: Deploy and Activate

```bash
cargo stylus deploy \
  --endpoint http://localhost:8547 \
  --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
```

This will:
1. Compile the contract to WASM
2. Check for constructors (via the `export-abi` feature in `main.rs`)
3. Post the WASM bytecode to the local chain
4. Automatically activate the contract (compile WASM to native machine code on-chain)
5. Output the **contract address**, **deployment tx hash**, and **activation tx hash**

**Save the contract address** — you'll need it for the next step.

Example output:

```
deployed code at address: 0xa6e41ffd769491a42a6e5ce453259b93983a22ef
deployment tx hash: 0x5432140cd5ab1e413adefc24b50011c2fc90c7eb...
successfully activated contract 0xa6e41ffd769491a42a6e5ce453259b93983a22ef
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
| Docker testnode won't start | Ensure Docker daemon is running: `docker info` |
| Dependency conflict (`ruint` version) | Don't add `alloy-primitives` or `alloy-sol-types` directly — let `stylus-sdk` resolve them as transitive dependencies |
| `failed to run contract` during deploy | You're missing `src/main.rs` or it doesn't have the `export-abi` conditional main function |
| `a bin target must be available for cargo run` | Create `src/main.rs` with the ABI export entrypoint (see Section 7) |
| Deployment fails with gas error | Make sure you're using the pre-funded private key |
| Contract calls return errors | Verify the contract was activated (check deploy output) |
| `cast` not found | Run `foundryup` to install/update Foundry tools |
| Expired contract (after 365 days) | Reactivate with `cargo stylus activate` |
| Rust version too old | stylus-sdk 0.10.2 requires Rust 1.91.0 — update `rust-toolchain.toml` |

### Useful Commands

```bash
# Check contract compiles correctly
cargo stylus check --endpoint http://localhost:8547

# Export the ABI (for frontend integration or Solidity interop)
cargo stylus export-abi

# Reactivate an expired contract
cargo stylus activate --endpoint http://localhost:8547 \
  --private-key <PRIVATE_KEY>

# Check testnode chain ID
cast chain-id --rpc-url http://localhost:8547

# Check account balance
cast balance <ADDRESS> --rpc-url http://localhost:8547
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
src/main.rs  check           deploy                          cast send
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
- [Nitro Testnode](https://github.com/OffchainLabs/nitro-testnode)
- [Foundry / Cast](https://book.getfoundry.sh/)
