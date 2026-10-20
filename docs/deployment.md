English | [中文](./deployment.zh.md)

# Deployment Guide

This guide covers deploying the Flip system contracts to a new chain.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) v1.8.5 (the version CI uses)
- Node.js 20+ and npm only if you prefer the Hardhat scripts
- A funded deployer account and an RPC endpoint for the target chain

## What gets deployed

| Order | Contract | Constructor arguments |
|---|---|---|
| 1 | `FeeVault` | none; `admin = msg.sender`, `protocolFeePercent = 20%` |
| 2 | `Registry` | none |
| 3 | `Price` | none |
| 4 | `Flip` | none; this is the shared implementation behind every collection proxy |
| 5 | `Factory` | `(registry, feeVault, price, flipImplementation)` |

`Factory` must be deployed last because it takes the four addresses above. Every
collection is then created as an `ERC1967Proxy` through `Factory.createFlip`.

```
FeeVault ─┐
Registry ─┼─► Factory ──CREATE2──► ERC1967Proxy (per collection) ──► Flip
Price    ─┤
Flip implementation ─┘
```

## Configure the environment

```bash
cp .env.example .env
```

| Variable | Used by | Purpose |
|---|---|---|
| `PRIVATE_KEY` | Foundry | deployer key read by `script/Deploy.s.sol` |
| `RPC_URL` | Foundry | RPC endpoint passed to `forge script --rpc-url` |
| `WALLET_PRIVATE_KEY` | Hardhat | deployer key for the `scripts/*.ts` accounts |
| `<NETWORK>_RPC_URL` | Hardhat | optional override for the built-in public RPC |
| `ETHERSCAN_API_KEY` | Hardhat | only needed once verification is enabled |

Never commit `.env`; it is covered by `.gitignore`.

## Deploy with Foundry (recommended)

```bash
PRIVATE_KEY=0x... RPC_URL=https://sepolia.base.org \
  forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
```

Add `--verify` once the target chain has an explorer entry configured in
`foundry.toml`, or verify separately with `forge verify-contract`.

The script prints all five addresses at the end. Keep them: `Factory` is the only
address your front end and subgraph need.

## Deploy with Hardhat

```bash
npx hardhat run scripts/deployFactoryComplete.ts --network base-sepolia
```

Available networks (all testnets; see `hardhat.config.ts`):

| Network | Chain ID |
|---|---|
| `bsc-testnet` | 97 |
| `base-sepolia` | 84532 |
| `megaeth-testnet` | 6342 |
| `pharos-testnet` | 688688 |
| `pharos-devnet` | 50002 |
| `optimism-sepolia` | 11155420 |
| `monad-testnet` | 10143 |
| `ethereum-sepolia` | 11155111 |
| `scroll-sepolia` | 534351 |
| `mantle-sepolia` | 5003 |

Each network falls back to a public RPC; set `<NETWORK>_RPC_URL` to override it.
`deployFactoryOnly.ts` re-deploys only `Factory` when the other four contracts
already exist — fill in the four address constants at the top of the file.

## Verification

`etherscan` is disabled by default so a missing key never blocks a deployment.
To enable it, set `ETHERSCAN_API_KEY` and uncomment an `etherscan` block in
`hardhat.config.ts`:

```ts
etherscan: {
  enabled: true,
  apiKey: { "base-sepolia": process.env.ETHERSCAN_API_KEY ?? "" },
  customChains: [
    {
      network: "base-sepolia",
      chainId: 84532,
      urls: {
        apiURL: "https://api-sepolia.basescan.org/api",
        browserURL: "https://sepolia.basescan.org",
      },
    },
  ],
},
```

Then verify with the constructor arguments:

```bash
npx hardhat verify --network base-sepolia <factory> <registry> <feeVault> <price> <implementation>
```

`FeeVault`, `Registry`, `Price` and `Flip` take no constructor arguments:

```bash
npx hardhat verify --network base-sepolia <address>
```

## Post-deployment checklist

- [ ] `factory.registry()`, `factory.feeVault()`, `factory.priceContract()` and
      `factory.Flip_IMPLEMENTATION()` return the addresses you just deployed
- [ ] create a throwaway collection and mint/buy/sell one token to confirm the curve works
- [ ] confirm `FeeVault.admin()` is the account you expect (or transfer it to a multisig)
- [ ] record the addresses in your front end and subgraph configuration
- [ ] announce the deployment, including the source commit and the audit status

## Upgrades

Collections are UUPS proxies owned by `Factory`. The current code has no entry
point on `Factory` to trigger an upgrade, so upgrading a collection means
adding one (or calling through the owner) — see
[upgrade-guide.md](./upgrade-guide.md) before planning an upgrade.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `insufficient funds for gas` | deployer balance too low on the target chain |
| `nonce too low` / repeated nonce | a previous broadcast is still pending; pass `--resume` or `--slow` to `forge script` |
| `Factory` constructor reverts with `ZeroAddress` | one of the four addresses was empty or wrong |
| verification fails | missing API key, wrong chain, or constructor arguments in the wrong order |
