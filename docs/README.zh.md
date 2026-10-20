[English](./README.md) | 中文

# Flip 合约文档

这份文档覆盖 `src/` 下的自研代码，不展开 `lib/` 依赖实现。

建议阅读顺序：

1. [architecture.zh.md](./architecture.zh.md) — 30 秒定位：解决什么问题、分层、部署拓扑
2. [modules.zh.md](./modules.zh.md) — 每个合约干什么、依赖谁、权限是谁
3. [flows.zh.md](./flows.zh.md) — 创建 / mint / buy / sell 的逐步路径
4. [faq.zh.md](./faq.zh.md) — 常见问题与边界条件
5. [upgrade-guide.zh.md](./upgrade-guide.zh.md) — UUPS 升级注意事项
6. [deployment.zh.md](./deployment.zh.md) — 系统合约部署
7. [security.zh.md](./security.zh.md) — 信任模型、角色与已知限制

## 30 秒电梯稿

Flip 是一套 **Bonding Curve NFT AMM**：

- 创作者通过 Factory 发集合，**没有预留 mint 权**，和用户同价购买
- 价格由独立的 `Price` 合约按 `currentSupply` 实时计算，买卖都能立刻成交
- 卖出的 NFT 进入合约自身持仓（交易池），买入时从池中取出
- 手续费拆成创作者费 + 协议费（FeeVault）

一句话：**NFT 版 Uniswap，曲线定价 + 合约即流动性池。**

## 源码地图

```
src/
├── Factory.sol                  # 创建入口（CREATE2 + ERC1967Proxy）
├── Flip.sol                     # 核心交易逻辑（mint/buy/sell）
├── Registry.sol                 # 创作者 ↔ 集合 索引
├── core/                        # NFT 基类、存储、定价、金库
├── periphery/Trade.sol          # 批量/快捷交易路由
├── extensions/
│   └── bodingcurve/             # 可插拔定价曲线
├── interfaces/                  # IFlip / IPrice / ITrade ...
├── libs/                        # 参数校验与常量
└── examples/                    # 链上 SVG 示例 NFT
```

## 核心概念

| 主题 | 一句话 |
|------|--------|
| 流动性从哪来 | 合约自己持有卖出的 NFT，ETH 储备留在合约里，买卖对手方是曲线本身 |
| `currentSupply` ≠ `totalSupply` | `totalSupply` 是历史铸造量；`currentSupply` 是仍在用户手中、参与定价的流通量 |
| 定价为何可插拔 | `Price` 是无状态单例，只读集合的 `Storage`；换曲线只换 `priceContract` |
| 升级与权限分离 | Factory 是 UUPS `owner`；`creator` 是业务角色，管 URI / 转让 |
| 费用怎么分 | `fee = price * creatorFeePercent`，再按 FeeVault 的 `protocolFeePercent`（默认 20%）切给协议 |

英文版：[README.md](./README.md)。
