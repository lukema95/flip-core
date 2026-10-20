English | [中文](./README.zh.md)

# Flip Contracts Documentation

This documentation covers the in-house code under `src/` and does not dig into the `lib/` dependencies.

Suggested reading order:

1. [architecture.md](./architecture.md) — the 30-second orientation: what problem it solves, the layers, deployment topology
2. [modules.md](./modules.md) — what each contract does, what it depends on, who may call it
3. [flows.md](./flows.md) — step-by-step creation / mint / buy / sell paths
4. [faq.md](./faq.md) — common questions and edge cases
5. [upgrade-guide.md](./upgrade-guide.md) — UUPS upgrade notes
6. [deployment.md](./deployment.md) — deploying the system contracts
7. [security.md](./security.md) — trust model, roles and known limitations
6. [deployment.md](./deployment.md) — deploying the system contracts
7. [security.md](./security.md) — trust model, roles and known limitations

## 30-second pitch

Flip is a **bonding-curve NFT AMM**:

- Creators launch a collection through `Factory`, with **no reserved mint** — they pay the same price as everyone else
- Price is computed in real time by a separate `Price` contract from `currentSupply`, so buys and sells fill immediately
- NFTs sold back go into the collection contract itself (the trading pool); buys take them out again
- Fees split into a creator fee and a protocol fee (`FeeVault`)

In one line: **Uniswap for NFTs — curve pricing with the contract as the liquidity pool.**

## Source map

```
src/
├── Factory.sol                  # creation entry point (CREATE2 + ERC1967Proxy)
├── Flip.sol                     # core trading logic (mint/buy/sell)
├── Registry.sol                 # creator ↔ collection index
├── core/                        # NFT base, storage, pricing, vault
├── periphery/Trade.sol          # batched / quick trading router
├── extensions/
│   └── bodingcurve/             # pluggable pricing curves
├── interfaces/                  # IFlip / IPrice / ITrade ...
├── libs/                        # parameter validation and constants
└── examples/                    # on-chain SVG example collection
```

## Core concepts

| Topic | Summary |
|------|--------|
| Where liquidity comes from | The contract holds the NFTs sold back to it and keeps the ETH reserve itself; the counterparty of every trade is the curve |
| `currentSupply` ≠ `totalSupply` | `totalSupply` is the lifetime mint count; `currentSupply` is the amount still held by users, which drives pricing |
| Why pricing is pluggable | `Price` is a stateless singleton that only reads a collection's `Storage`; changing the curve means pointing `priceContract` elsewhere |
| Upgrade vs. business authority | `Factory` is the UUPS `owner`; `creator` is a business role that manages the URI and creator transfer |
| How fees split | `fee = price * creatorFeePercent`, then FeeVault's `protocolFeePercent` (20% by default) goes to the protocol |

Chinese version: [README.zh.md](./README.zh.md).
