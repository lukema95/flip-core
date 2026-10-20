English | [中文](./README-deployment.zh.md)

# Deployment scripts

The full guide — prerequisites, environment, network list, verification and a post-deployment checklist — is in [docs/deployment.md](../docs/deployment.md). This file only lists what ships in `scripts/`.

| Script | Purpose |
|---|---|
| `deployFactoryComplete.ts` | deploy `FeeVault`, `Registry`, `Price`, the `Flip` implementation and `Factory`, in that order |
| `deployFactoryOnly.ts` | deploy only `Factory`, for when the other four contracts already exist |
| `deployFeeVault.ts` | deploy `FeeVault` on its own |
| `deployTrade.ts` | deploy the `Trade` periphery router |
| `examples/createNFT.ts` | create a collection through an existing Factory (`FACTORY_ADDRESS`) |
| `examples/mintNFT.ts` | mint through `Trade` for an existing collection (`FLIP_ADDRESS`, `TRADE_ADDRESS`) |
| `../script/Deploy.s.sol` | Foundry equivalent of the full deployment |

```bash
cp .env.example .env    # WALLET_PRIVATE_KEY for Hardhat, PRIVATE_KEY for Foundry
npx hardhat run scripts/deployFactoryComplete.ts --network base-sepolia
```

`deployFactoryOnly.ts` expects the four dependency addresses to be filled in at the top of the file. Example scripts read their addresses from the environment and fail with a clear message when a variable is missing.
