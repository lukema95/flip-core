[English](./README.md) | 中文

# Flip

Flip 是一套 **Bonding Curve NFT AMM** 的智能合约实现：每个 NFT 集合合约自己就是交易池与做市商，价格由流通量实时决定，买卖即时成交，创作者没有预留铸造权。

本仓库只包含合约层（Solidity 源码、Foundry 测试、部署脚本）。

[![contracts](https://github.com/lukema95/flip-core/actions/workflows/test.yml/badge.svg)](https://github.com/lukema95/flip-core/actions/workflows/test.yml)
[![license](https://img.shields.io/badge/license-BUSL--1.1%20%2B%20MIT-blue)](./licenses/README.md)
[![foundry](https://img.shields.io/badge/foundry-v1.8.5-informational)](https://book.getfoundry.sh/)

> **状态：** source-available（核心 BUSL-1.1，其余 MIT），未审计，目前只部署在测试网。


## 核心设计

- **合约即市场**：卖出的 NFT 进入集合合约自身的 `availableTokens` 池，ETH 储备也留在同一合约
- **曲线定价**：`Price` 是无状态单例，按 `currentSupply` 计算买卖价，可通过 `IPrice` 替换曲线
- **无预留发行**：`Factory` 不提供给 creator 的免费 mint，创作者和用户同价
- **强制版税**：mint / buy / sell 三条路径都抽 `creatorFeePercent`，再按 `FeeVault.protocolFeePercent` 分给协议
- **UUPS 可升级**：集合是 `ERC1967Proxy`，实现由 `Factory` 统一部署与升级
- **ERC-7201 存储**：业务状态放在 `flip.storage.Storage` 命名空间，与 OZ 线性布局解耦

## 合约一览

| 合约 | 作用 |
|------|------|
| `Factory` | 参数校验 + `CREATE2` 部署集合 Proxy + 注册到 Registry |
| `Flip` | 集合实例的核心交易逻辑：`mint` / `buy` / `sell` |
| `core/BaseNFT` | ERC721 + Enumerable + Holder + Ownable + UUPS + Storage |
| `core/Storage` | ERC-7201 集合状态（曲线参数、池子、creator） |
| `core/Price` | 默认曲线定价（无状态、可替换） |
| `core/FeeVault` | 协议金库与手续费分成 |
| `Registry` | creator ↔ 集合 索引 |
| `periphery/Trade` | 批量 / 快捷交易路由 |
| `extensions/bodingcurve` | 备选曲线：`LinearPrice`、`FixedIncrementPrice` |
| `examples/FlipNFT` | 链上 SVG 的示例集合 |

## 快速开始

前置条件：

- [Foundry](https://book.getfoundry.sh/getting-started/installation) **v1.8.5**（与 CI 一致）
- 只有运行部署脚本时才需要 Node.js 20+
- `solc 0.8.26`（固定在 `foundry.toml`）；pragma 为 `^0.8.20`，而 OpenZeppelin 5.2 要求至少 `0.8.22`

```bash
`lib/` holds three submodules pinned to upstream releases. Only these top-level
submodules are needed — do not clone recursively, the nested test submodules
inside OpenZeppelin break Hardhat's remapping parser:
forge build
forge test                     # 154 个测试
forge coverage --ir-minimum    # 覆盖率报告
```

`lib/` 是三个 submodule，锁在以下上游版本。只需要这三个顶层 submodule——
不要用递归克隆，OpenZeppelin 内部的嵌套测试 submodule 会让 Hardhat 的 remapping 解析失败：

- `forge-std` v1.9.1
- `openzeppelin-contracts` v5.2.0
- `openzeppelin-contracts-upgradeable` v5.2.0

## 部署

可用 Foundry（`script/Deploy.s.sol`）或 Hardhat（`scripts/*.ts`）。完整指南（网络清单、合约验证、部署后检查）见 [docs/deployment.zh.md](./docs/deployment.zh.md)。

```bash
cp .env.example .env   # Foundry 用 PRIVATE_KEY + RPC_URL，Hardhat 用 WALLET_PRIVATE_KEY

PRIVATE_KEY=0x... RPC_URL=https://sepolia.base.org \
  forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast

# 或
npx hardhat run scripts/deployFactoryComplete.ts --network base-sepolia
```

## 文档

文档索引见 [docs/README.zh.md](./docs/README.zh.md)。

- [docs/architecture.zh.md](./docs/architecture.zh.md) — 分层、继承、部署拓扑、存储模型
- [docs/modules.zh.md](./docs/modules.zh.md) — 逐个合约的职责与权限
- [docs/flows.zh.md](./docs/flows.zh.md) — 创建 / mint / buy / sell / 费用的完整路径
- [docs/faq.zh.md](./docs/faq.zh.md) — 常见问题与边界条件
- [docs/upgrade-guide.zh.md](./docs/upgrade-guide.zh.md) — UUPS 升级与存储布局注意事项
- [docs/deployment.zh.md](./docs/deployment.zh.md) — 部署到新链
- [docs/security.zh.md](./docs/security.zh.md) — 信任模型、角色与已知限制
- [CHANGELOG.zh.md](./CHANGELOG.zh.md) — 版本变更记录

## 安全

- 未附审计报告，生产使用前请自行审计
- 合约升级权限在 `Factory`（集合的 `owner`），建议交由多签 / Timelock 管理
- 发现漏洞请勿公开开 issue，请按 [SECURITY.zh.md](./SECURITY.zh.md) 私下报告

## 贡献

环境搭建、本地检查、提交规范与 PR 清单见 [CONTRIBUTING.zh.md](./CONTRIBUTING.zh.md)；安全问题按 [SECURITY.zh.md](./SECURITY.zh.md) 处理。

## 许可证

Flip 采用分层授权：

- **核心合约**：`Factory`、`Flip`、`Registry`、`core/*`、`libs/*`、`extensions/bodingcurve/*` 使用 [Business Source License 1.1](./licenses/BUSL_LICENSE)。这是 source-available 而非开源：阅读、审计、测试、研究均免费，但生产使用（包括把它或衍生版本部署为竞品 AMM）需要商业授权。每个版本在「2029-06-15」与该版本首次公开发布后 4 年两者中较早的日期自动转为 MIT。
- **接口、外围、示例与测试**：使用 [MIT](./licenses/MIT_LICENSE)。

逐文件对照见 [licenses/README.md](./licenses/README.md)。“Flip” 是 Flip Contributors 的商标，以上许可均不授予商标权。

英文版：[README.md](./README.md)。
