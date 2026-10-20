[English](./architecture.md) | 中文

# 合约架构

## 产品问题

| 市场痛点 | Flip 机制 | 落在哪个模块 |
|----------|-------------|--------------|
| NFT 挂单难成交 | 合约即交易池，随时按曲线买卖 | `Flip.mint/buy/sell` + `Storage.availableTokens` |
| 定价靠拍脑袋 | Bonding Curve，价格是 supply 的函数 | `core/Price.sol` + `IPrice` 可插拔实现 |
| 创作者预留砸盘 | 无 reserved mint，创作者也走同一条 `mint` | `Factory` 不给 creator 特权 mint |
| 版税难执行 | 每笔成交强制抽 `creatorFeePercent` | `Flip.distributeFee` + `FeeVault` |

## 分层

```
┌─────────────────────────────────────────────────────────┐
│  Periphery（用户友好入口，无核心状态）                    │
│  Trade.sol：bulkMint / quickBuy / bulkSell              │
└──────────────────────────┬──────────────────────────────┘
                           │ 调 IFlip
┌──────────────────────────▼──────────────────────────────┐
│  Collection 实例（每个项目一个 ERC1967Proxy）            │
│  Flip                                                   │
│  继承 BaseNFT = ERC721 + Enumerable + UUPS + Storage     │
└──────────┬───────────────────────────────┬──────────────┘
           │ 读曲线                        │ 付费
┌──────────▼──────────┐           ┌────────▼────────┐
│  Price（单例、无状态）│           │  FeeVault（协议金库）│
│  读 Storage 算价     │           │  默认抽手续费的 20%  │
└─────────────────────┘           └─────────────────┘
           ▲
┌──────────┴──────────────────────────────────────────────┐
│  System（全局、部署一次）                                 │
│  Factory → CREATE2 部署 Proxy                           │
│  Registry → creator ↔ collection 双向索引                │
└─────────────────────────────────────────────────────────┘
```

设计原则：

1. **逻辑与实例分离**：`Flip` implementation 全链共享；每个集合只是 Proxy + 自己的 ERC-7201 存储。
2. **定价与资产分离**：`Price` 不持币、不持 NFT，只 `view` 计算；集合自己持 ETH 储备和池内 NFT。
3. **核心与外围分离**：单笔 mint/buy/sell 在集合合约；批量、快捷买在 `Trade`。
4. **创建入口唯一**：所有集合都由同一个 `Factory` 部署，保证实现版本与初始化参数一致。

## 继承关系

```
Initializable
    └── Storage（ERC-7201：价格参数、池子、creator）
            └── BaseNFT
                  ERC721Upgradeable
                  ERC721EnumerableUpgradeable
                  ERC721HolderUpgradeable
                  OwnableUpgradeable
                  UUPSUpgradeable
                    └── Flip  ──implements──► IFlip
                              └── examples/FlipNFT（+ Trait，链上 SVG）
```

## 部署拓扑

系统合约部署一次，集合合约按需克隆：

```
部署顺序（见 scripts/README-deployment.md）

FeeVault ─┐
Registry ─┼─► Factory(registry, feeVault, price, flipImpl)
Price    ─┤
Flip implementation ─┘

用户 createFlip()
    └── new ERC1967Proxy{salt}(implementation, initialize calldata)
            └── Registry.register(creator, proxy)
```

## 存储模型

集合状态不放在普通状态变量里，而用 **ERC-7201 namespaced storage**：

- namespace：`flip.storage.Storage`
- slot：`keccak256(abi.encode(uint256(keccak256(namespace)) - 1)) & ~bytes32(uint256(0xff))`
- 当前值：`0xeb5d050250a195793d5c215e55811a7e5bc03a3f511fa4bdb2cdf5696dd5b000`
- `StorageSlotTest` 里有一条断言把常量与按 namespace 计算的结果对齐，改 namespace 必须同步改常量

好处：UUPS 升级换 implementation 时，只要新合约继续读同一 namespace，就不会和 OZ 的 ERC721/Ownable 存储布局打架。

关键字段：

| 字段 | 含义 |
|------|------|
| `initialPrice / maxSupply / maxPrice` | 曲线参数；`maxPrice = 0` 表示不封顶 |
| `creatorFeePercent` | 相对价格的费率，`1 ether = 100%` |
| `currentSupply` | **流通量**，决定当前买卖价 |
| `availableTokens[]` + `tokenIndex` | 池内待售 tokenId，O(1) 增删 |
| `creator` | 业务管理员（不是 Ownable owner） |
| `feeVault / priceContract` | 指向全局单例 |

## 和传统 NFT 市场的架构差

传统：NFT 合约（资产） + Marketplace（挂单/撮合）+ Royalty Registry。

Flip：NFT 合约 **自己就是市场**。`address(this)` 持有待售 NFT，ETH 曲线储备也在同一合约。Marketplace（`Trade`）只是可选路由器，不是流动性所在地。

英文版：[architecture.md](./architecture.md)。
