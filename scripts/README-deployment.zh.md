[English](./README-deployment.md) | 中文

# 部署脚本

完整指南（前置条件、环境变量、网络清单、合约验证与部署后检查清单）见
[docs/deployment.zh.md](../docs/deployment.zh.md)。本文件只列出 `scripts/` 下的脚本。

| 脚本 | 用途 |
|---|---|
| `deployFactoryComplete.ts` | 按顺序部署 `FeeVault`、`Registry`、`Price`、`Flip` 实现与 `Factory` |
| `deployFactoryOnly.ts` | 只部署 `Factory`，用于其余四个合约已存在的情况 |
| `deployFeeVault.ts` | 单独部署 `FeeVault` |
| `deployTrade.ts` | 部署 `Trade` 外围路由 |
| `examples/createNFT.ts` | 通过已有 Factory 创建集合（需要 `FACTORY_ADDRESS`） |
| `examples/mintNFT.ts` | 通过 `Trade` 为已有集合 mint（需要 `FLIP_ADDRESS`、`TRADE_ADDRESS`） |
| `../script/Deploy.s.sol` | 与完整部署等价的 Foundry 脚本 |

```bash
cp .env.example .env    # Hardhat 用 WALLET_PRIVATE_KEY，Foundry 用 PRIVATE_KEY
npx hardhat run scripts/deployFactoryComplete.ts --network base-sepolia
```

`deployFactoryOnly.ts` 需要先填好文件顶部的四个依赖地址。示例脚本从环境变量读取地址，变量缺失时会给出明确报错。
