[English](./deployment.md) | 中文

# 部署指南

本文说明如何把 Flip 系统合约部署到一条新链。

## 前置条件

- [Foundry](https://book.getfoundry.sh/getting-started/installation) v1.8.5（与 CI 一致）
- 只有用 Hardhat 脚本时才需要 Node.js 20+ 与 npm
- 一个有余额的部署账户，以及目标链的 RPC 端点

## 部署内容

| 顺序 | 合约 | 构造参数 |
|---|---|---|
| 1 | `FeeVault` | 无；`admin = msg.sender`，`protocolFeePercent = 20%` |
| 2 | `Registry` | 无 |
| 3 | `Price` | 无 |
| 4 | `Flip` | 无；这是所有集合代理共享的实现合约 |
| 5 | `Factory` | `(registry, feeVault, price, flipImplementation)` |

`Factory` 必须最后部署，因为它要接收上面四个地址。之后所有集合都通过
`Factory.createFlip` 以 `ERC1967Proxy` 形式创建。

```
FeeVault ─┐
Registry ─┼─► Factory ──CREATE2──► ERC1967Proxy（每个集合）──► Flip
Price    ─┤
Flip implementation ─┘
```

## 配置环境变量

```bash
cp .env.example .env
```

| 变量 | 使用方 | 用途 |
|---|---|---|
| `PRIVATE_KEY` | Foundry | `script/Deploy.s.sol` 读取的部署私钥 |
| `RPC_URL` | Foundry | 传给 `forge script --rpc-url` 的端点 |
| `WALLET_PRIVATE_KEY` | Hardhat | `scripts/*.ts` 使用的部署私钥 |
| `<NETWORK>_RPC_URL` | Hardhat | 可选，覆盖内置公共 RPC |
| `ETHERSCAN_API_KEY` | Hardhat | 仅在启用验证后需要 |

不要把 `.env` 提交到仓库，`.gitignore` 已覆盖。

## 用 Foundry 部署（推荐）

```bash
PRIVATE_KEY=0x... RPC_URL=https://sepolia.base.org \
  forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
```

在 `foundry.toml` 里配置好目标链的 explorer 后可以加 `--verify`，也可以之后用
`forge verify-contract` 单独验证。

脚本最后会打印五个地址，请记录下来：前端与 subgraph 只需要 `Factory` 地址。

## 用 Hardhat 部署

```bash
npx hardhat run scripts/deployFactoryComplete.ts --network base-sepolia
```

可用网络（均为测试网，见 `hardhat.config.ts`）：

| 网络 | Chain ID |
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

每个网络都有公共 RPC 兜底；设置 `<NETWORK>_RPC_URL` 可覆盖。
当其余四个合约已部署、只想重发 `Factory` 时用 `deployFactoryOnly.ts`，先填好文件顶部的四个地址常量。

## 合约验证

`etherscan` 默认关闭，避免缺少 API key 阻塞部署。需要验证时，设置
`ETHERSCAN_API_KEY`，并在 `hardhat.config.ts` 中启用：

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

然后带构造参数验证：

```bash
npx hardhat verify --network base-sepolia <factory> <registry> <feeVault> <price> <implementation>
```

`FeeVault`、`Registry`、`Price`、`Flip` 没有构造参数：

```bash
npx hardhat verify --network base-sepolia <address>
```

## 部署后检查清单

- [ ] `factory.registry()`、`factory.feeVault()`、`factory.priceContract()`、
      `factory.Flip_IMPLEMENTATION()` 返回的正是刚部署的地址
- [ ] 创建一个测试集合，mint/buy/sell 各一次，确认曲线可用
- [ ] 确认 `FeeVault.admin()` 是预期的账户（或转交给多签）
- [ ] 把地址写入前端与 subgraph 配置
- [ ] 对外公告部署，注明源码 commit 与审计状态

## 升级

集合是 UUPS 代理，owner 为 `Factory`。当前代码中 `Factory` 没有触发升级的入口，
因此升级集合需要先补一个入口（或由 owner 直接调用）——规划升级前请先阅读
[upgrade-guide.zh.md](./upgrade-guide.zh.md)。

## 常见问题

| 现象 | 可能原因 |
|---|---|
| `insufficient funds for gas` | 部署账户在目标链余额不足 |
| `nonce too low` / nonce 重复 | 上一次广播仍在 pending；给 `forge script` 加 `--resume` 或 `--slow` |
| `Factory` 构造回滚 `ZeroAddress` | 四个地址中有一个为空或错误 |
| 验证失败 | 缺少 API key、链不匹配，或构造参数顺序错误 |
