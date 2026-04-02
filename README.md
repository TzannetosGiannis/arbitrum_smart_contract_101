# Arbitrum Stylus Smart Contract 101

Hands-on examples of writing, deploying, and interacting with smart contracts on Arbitrum using **Stylus** (Rust) — no Solidity required.

Built as companion material for the **NTUA ECE Web3 Development** workshop on Stylus & Arbitrum.

---

## What's Inside

### Contracts

| Project | Description | Key Concepts |
|---------|-------------|--------------|
| [`my_counter/`](my_counter/) | Simple counter contract | Storage, public functions, view calls, state mutations |
| [`crowdfunding/`](crowdfunding/) | Crowdfunding campaign with ETH handling | Payable functions, ETH transfers, access control, deadlines, refunds, events, custom errors |

### Demo Scripts

| Folder | Description |
|--------|-------------|
| [`demo_my_counter/`](demo_my_counter/) | Deploy and interact with the Counter contract |
| [`demo_crowdfunding/`](demo_crowdfunding/) | Deploy and run a full crowdfunding simulation with 3 contributors |

### Guide

[`GUIDE.md`](GUIDE.md) — Step-by-step walkthrough covering everything from installing Rust to deploying on mainnet.

---

## Quick Start

### Prerequisites

- [Rust](https://rustup.rs/) 1.91.0+
- [Docker](https://docs.docker.com/get-docker/)
- [cargo-stylus](https://github.com/OffchainLabs/cargo-stylus) 0.10.2
- [Foundry](https://book.getfoundry.sh/) (cast)

### Install Tools

```bash
# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32-unknown-unknown

# cargo-stylus
cargo install --force cargo-stylus

# Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

### Run the Counter Demo

```bash
cd demo_my_counter
./start.sh          # Start local Arbitrum testnode (requires Docker)
./compile.sh        # Build and validate WASM
./deploy.sh         # Deploy and activate on local chain
./interact.sh       # Read, set, and increment the counter
./stop.sh           # Shut down testnode
```

### Run the Crowdfunding Demo

```bash
cd demo_crowdfunding
./start.sh           # Start local Arbitrum testnode
./deploy.sh          # Deploy crowdfunding contract
./simulate.sh        # Run full simulation:
                     #   - Fund 3 wallets (Alice, Bob, Charlie)
                     #   - Initialize campaign (goal: 1 ETH)
                     #   - 3 contributions (0.3 + 0.4 + 0.5 = 1.2 ETH)
                     #   - Owner claims funds
                     #   - Balance snapshots before/after
./stop.sh            # Shut down testnode
```

---

## Project Structure

```
.
├── README.md
├── GUIDE.md                  # Detailed setup and deployment guide
├── my_counter/               # Counter contract (Rust/Stylus)
│   ├── Cargo.toml
│   ├── Stylus.toml
│   ├── rust-toolchain.toml
│   └── src/
│       ├── lib.rs            # Contract: number(), setNumber(), increment()
│       └── main.rs           # ABI export entrypoint
├── crowdfunding/             # Crowdfunding contract (Rust/Stylus)
│   ├── Cargo.toml
│   ├── Stylus.toml
│   ├── rust-toolchain.toml
│   └── src/
│       ├── lib.rs            # Contract: initialize(), contribute(), claim(), refund()
│       └── main.rs           # ABI export entrypoint
├── demo_my_counter/          # Demo scripts for counter
│   ├── start.sh
│   ├── stop.sh
│   ├── compile.sh
│   ├── deploy.sh
│   └── interact.sh
└── demo_crowdfunding/        # Demo scripts for crowdfunding
    ├── start.sh
    ├── stop.sh
    ├── deploy.sh
    └── simulate.sh
```

---

## What is Stylus?

Stylus is an upgrade to Arbitrum Nitro that adds a **WASM virtual machine** alongside the EVM. It lets you write smart contracts in **Rust, C, or C++** that:

- Run **10-70x faster** than equivalent Solidity for compute-heavy operations
- Are **100-500x more memory-efficient**
- **Fully interoperate** with Solidity contracts (shared state, cross-VM calls)
- Use the **ink** metering system (1 gas = 10,000 ink) for fine-grained cost tracking

See [`GUIDE.md`](GUIDE.md) for the full technical breakdown.

---

## Resources

- [Arbitrum Stylus Documentation](https://docs.arbitrum.io/stylus/stylus-gentle-introduction)
- [Stylus SDK (Rust)](https://github.com/OffchainLabs/stylus-sdk-rs)
- [cargo-stylus CLI](https://github.com/OffchainLabs/cargo-stylus)
- [Nitro Testnode](https://github.com/OffchainLabs/nitro-testnode)
- [Foundry / Cast](https://book.getfoundry.sh/)

---

## License

MIT
