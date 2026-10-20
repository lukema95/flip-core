English | [中文](./README.zh.md)

# Flip

Flip is a **bonding-curve NFT AMM** written in Solidity. Every collection contract *is* the market and the market maker: price is a function of circulating supply, buys and sells settle instantly, and creators get no reserved mint.

This repository contains the contracts layer only — Solidity sources, Foundry tests and deployment scripts.

[![contracts](https://github.com/lukema95/flip-core/actions/workflows/test.yml/badge.svg)](https://github.com/lukema95/flip-core/actions/workflows/test.yml)
[![license](https://img.shields.io/badge/license-BUSL--1.1%20%2B%20MIT-blue)](./licenses/README.md)
[![foundry](https://img.shields.io/badge/foundry-v1.8.5-informational)](https://book.getfoundry.sh/)

> **Status:** source-available (BUSL-1.1 core, MIT elsewhere), not audited, testnet deployments only.


## Core design

- **The contract is the market** — NFTs sold back go into the collection's own `availableTokens` pool, and the ETH reserve stays inside the same contract
- **Curve pricing** — `Price` is a stateless singleton that derives buy/sell prices from `currentSupply`; curves are swappable through `IPrice`
- **No reserved mint** — `Factory` gives creators no free mint; they pay the same curve price as everyone else
- **Enforced royalties** — `creatorFeePercent` is charged on mint/buy/sell, then `FeeVault.protocolFeePercent` goes to the protocol
- **UUPS upgradeable** — each collection is an `ERC1967Proxy`; implementations are deployed and upgraded by `Factory`
- **ERC-7201 storage** — business state lives in the `flip.storage.Storage` namespace, decoupled from OZ's linear layout

## Contracts

| Contract | Responsibility |
|------|------|
| `Factory` | Parameter validation, `CREATE2` deployment of collection proxies, registration in `Registry` |
| `Flip` | Core trading logic of a collection: `mint` / `buy` / `sell` |
| `core/BaseNFT` | ERC721 + Enumerable + Holder + Ownable + UUPS + Storage |
| `core/Storage` | ERC-7201 collection state (curve parameters, pool, creator) |
| `core/Price` | Default curve pricing (stateless, replaceable) |
| `core/FeeVault` | Protocol vault and fee split |
| `Registry` | creator ↔ collection index |
| `periphery/Trade` | Batched / quick trading router |
| `extensions/bodingcurve` | Alternative curves: `LinearPrice`, `FixedIncrementPrice` |
| `examples/FlipNFT` | Example collection with on-chain SVG art |

## Getting started

Prerequisites:

- [Foundry](https://book.getfoundry.sh/getting-started/installation) **v1.8.5**, the version CI pins
- Node.js 20+ only if you run the deployment scripts
- `solc 0.8.26` (pinned in `foundry.toml`); the pragma is `^0.8.20` and OpenZeppelin 5.2 needs at least `0.8.22`

```bash
git clone git@github.com:lukema95/flip-core.git
cd flip-core
git submodule update --init lib/forge-std lib/openzeppelin-contracts lib/openzeppelin-contracts-upgradeable

forge build
forge test                     # 154 tests
forge coverage --ir-minimum    # coverage report
```

`lib/` holds three submodules pinned to upstream releases. Only these top-level
submodules are needed — do not clone recursively, the nested test submodules
inside OpenZeppelin break Hardhat's remapping parser:

- `forge-std` v1.9.1
- `openzeppelin-contracts` v5.2.0
- `openzeppelin-contracts-upgradeable` v5.2.0

## Deployment

Deploy with Foundry (`script/Deploy.s.sol`) or Hardhat (`scripts/*.ts`). The full guide — network list, verification and a post-deployment checklist — is [docs/deployment.md](./docs/deployment.md).

```bash
cp .env.example .env   # PRIVATE_KEY + RPC_URL for Foundry, WALLET_PRIVATE_KEY for Hardhat

PRIVATE_KEY=0x... RPC_URL=https://sepolia.base.org \
  forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast

# or
npx hardhat run scripts/deployFactoryComplete.ts --network base-sepolia
```

## Documentation

The documentation index is [docs/README.md](./docs/README.md).

- [docs/architecture.md](./docs/architecture.md) — layers, inheritance, deployment topology, storage model
- [docs/modules.md](./docs/modules.md) — per-contract responsibilities and permissions
- [docs/flows.md](./docs/flows.md) — creation / mint / buy / sell / fee flows
- [docs/faq.md](./docs/faq.md) — common questions and edge cases
- [docs/upgrade-guide.md](./docs/upgrade-guide.md) — UUPS upgrades and storage layout
- [docs/deployment.md](./docs/deployment.md) — deploying to a new chain
- [docs/security.md](./docs/security.md) — trust model, roles and known limitations
- [CHANGELOG.md](./CHANGELOG.md) — release history

Chinese versions are available next to each document as `*.zh.md`, starting with [README.zh.md](./README.zh.md).

## Security

- No audit report is included; audit the code before production use
- Upgrade rights over collections live with `Factory` (the collection `owner`); prefer a multisig or Timelock
- Do not open a public issue for a vulnerability; follow [SECURITY.md](./SECURITY.md) instead

## Contributing

Setup, local checks, commit conventions and the pull request checklist are in [CONTRIBUTING.md](./CONTRIBUTING.md). Security reports go through [SECURITY.md](./SECURITY.md).

## License

Flip is split-licensed:

- **Core** — `Factory`, `Flip`, `Registry`, `core/*`, `libs/*` and `extensions/bodingcurve/*` use the [Business Source License 1.1](./licenses/BUSL_LICENSE). It is source-available, not open source: reading, auditing, testing and research are free, while production use — including deploying it or a derivative as a competing AMM — needs a commercial license. Each version converts to the MIT License on the earlier of 2029-06-15 or four years after its first public distribution.
- **Interfaces, periphery, examples and tests** — [MIT](./licenses/MIT_LICENSE).

See [licenses/README.md](./licenses/README.md) for the file-by-file mapping. "Flip" is a trademark of Flip Contributors; neither license grants trademark rights.
