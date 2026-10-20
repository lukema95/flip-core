[English](./modules.md) | 中文

# 模块设计

按「职责 / 关键接口 / 权限 / 注意事项」组织。源码均在 `src/`。

## 1. Factory — 集合工厂

文件：`Factory.sol`

**职责**

- 参数校验（`Validator` + `Constants`）
- `CREATE2 + ERC1967Proxy` 部署集合
- 初始化时注入全局 `feeVault`、`priceContract`、`creator`
- 向 `Registry` 登记
- 预计算地址（`calculateFlipAddress`）
- 作为代理的 UUPS `owner`（集合真正的 `onlyOwner` 是 Factory）

**创建路径**

| 方法 | Implementation | 参数 |
|------|----------------|------|
| `createFlip` | `Flip` | `name, symbol, initialPrice, maxSupply, maxPrice, creatorFeePercent, baseUri` |

Salt：`keccak256(abi.encode(name, symbol, initialPrice, maxSupply, maxPrice))`。最终地址还取决于 `initialize` calldata（含 `creator`、fee、URI），所以不同创作者不会撞地址；同一人用完全相同的五项参数会因 CREATE2 重复而失败。

**权限**

- 任意地址可创建（无白名单）
- 无常驻管理函数；Factory 不提供改集合参数的入口

**小结**：Factory 是「无许可发行 + 确定性地址 + 共享逻辑」三件事的交汇点；升级权留在 Factory，避免每个创作者乱升级实现。

## 2. Registry — 项目索引

文件：`Registry.sol`

- `creator => address[]`、`contract => creator`
- `register` 会 `supportsInterface(IFlip)`，防登记任意合约
- **没有 onlyFactory**：任何满足接口的合约都能自注册

注意：这是发现层，不是权限层；若要加强，应加 `onlyFactory` 或 EIP-712 签名。

## 3. Flip — 核心交易

文件：`Flip.sol`，接口 `IFlip`

三个写方法：

| 方法 | 前提 | 状态变化 | ETH |
|------|------|----------|-----|
| `mint()` | `totalSupply < maxSupply` | 新铸 tokenId = totalSupply+1，`currentSupply++` | 用户付 `price+fee`，合约留 `price`，分 `fee` |
| `buy(tokenId)` | `ownerOf == address(this)` | 从池转给买家，移出 `availableTokens`，`currentSupply++` | 同 mint |
| `sell(tokenId)` | 调用者是 owner | 转给合约，加入池，`currentSupply--` | 合约付 `price-fee` 给卖家，再分 `fee` |

`isOnSale`：owner 是否为合约自己。

`distributeFee`：

```
protocolFee = fee * FeeVault.protocolFeePercent / 1e18
creatorFee  = fee - protocolFee
creator.call{value: creatorFee}
feeVault.call{value: protocolFee}
```

多付部分 `_refundExcess`。

## 4. BaseNFT — NFT 基类

文件：`core/BaseNFT.sol`

拼装：

- OZ ERC721 + Enumerable + Holder（合约能收自己的 NFT，才能当池）
- Ownable + UUPS（`_authorizeUpgrade` = `onlyOwner`）
- `Storage`

元数据：

- `tokenURI` = `baseURI/tokenId.json`
- `contractURI` = `baseURI/collection.json`（ERC-7572）

`tokensOfOwner` / `tokensOfOwnerInRange`：链上枚举，gas 随持仓线性增长，代码里标了 TODO，这类查询更适合交给 Subgraph。

初始化里 `__Ownable_init(msg.sender)`：Proxy 由 Factory 部署并 `delegatecall initialize`，所以 **owner = Factory**。

## 5. Storage — 集合状态

文件：`core/Storage.sol`

ERC-7201 结构体见 architecture。业务上最重要的是交易池：

```
_addAvailableToken    // sell：push + 记 index
_removeAvailableToken // buy：swap-with-last + pop，O(1)
```

`currentSupply` 只通过 `_increment / _decrement` 改，保证和 mint/buy/sell 对齐。

Creator 可改：`setCreator`、`setBaseURI`。不能改 `priceContract` / `initialPrice` / `maxSupply`（部署后锁定）。

## 6. Price — 定价引擎

文件：`core/Price.sol`，接口 `IPrice`

**单例、无状态**。所有集合共用一个 Price；计算时传入 `storageContract`（即集合地址），从 `IStorage` 读参数。

默认曲线（`calculatePrice`）：

- `supply == 0` → `initialPrice`
- 否则：

```
price = initialPrice
      + initialPrice * 2
        * sqrt(100 * supply * maxSupply)
        * sqrt(10000 * supply²)
        / maxSupply²
```

- `maxPrice > 0` 时 `min(price, maxPrice)` 封顶

买卖价差来自 supply 取值，不是额外 spread：

| | 用的 supply |
|--|-------------|
| buy / mint | `currentSupply`（下一件的价） |
| sell | `currentSupply == 0 ? 0 : currentSupply - 1`（刚买进那档的价） |

费用：`fee = price * creatorFeePercent / 1 ether`

- `getBuyPriceAfterFee` = price + fee（用户实付）
- `getSellPriceAfterFee` = price - fee（卖家实收）

可插拔实现（`extensions/bodingcurve/`，目录名是拼写错误 bonding）：

| 合约 | 增长形态 | 参数 |
|------|----------|------|
| `Price`（默认） | 中等、偏 sqrt | 无额外不可变量 |
| `LinearPrice` | 近似几何级数 | `PRICE_MULTIPLIER`（1000–2000 bps） |
| `FixedIncrementPrice` | 线性 | `PRICE_INCREMENT` |

换曲线 = 部署新 Price，并把集合的 `priceContract` 指过去（当前 Storage **没有 setter**，实际要在创建时选定，或靠升级）。接口上可插拔，但当前 Factory 把同一个 Price 写死进 initialize。

## 7. FeeVault — 协议金库

文件：`core/FeeVault.sol`

- `admin` = 部署者，可换 admin、提现
- `protocolFeePercent = 0.2 ether`（占 **creatorFee** 的 20%，不是占成交价的 20%）
- **没有 `setProtocolFeePercent`**，部署后费率锁死
- `receive()` 收款

例：成交价 1 ETH，`creatorFeePercent = 5%` → fee = 0.05 ETH → 协议 0.01 ETH，创作者 0.04 ETH。

## 8. Trade — 外围路由

文件：`periphery/Trade.sol`

自己是 `ERC721Holder`，流程永远是：

1. 以 Trade 为 `msg.sender` 调集合的 mint/buy/sell
2. 再 `safeTransferFrom` 把 NFT 转到真实用户
3. 或反向：用户先把 NFT 转给 Trade，再 `sell`

能力：`mint/buy/sell`、`quickBuy`（池子最后一个 tokenId）、`bulk*`。

`quickBuy` 只转 `price` 给 `buy()`，多余 ETH 不会从这条路径退（和直接调 `Flip.buy` 的 refund 行为不同）。外围合约自己决定付款精度。

文件顶部 `ReentrancyGuard` 被注释掉了，批量循环里有外部调用，是可改进点。

## 9. Libs / Examples / Interfaces

| 模块 | 作用 |
|------|------|
| `libs/Constants` | 初始价 0.0001–1 ETH；供给 100–1e6；创作者费率 1%–100%（不含 100%） |
| `libs/Validator` | Factory 创建前校验 |
| `examples/FlipNFT` + `Trait` | 铸造时写 `tokenSeed`，`tokenURI` 返回链上随机 SVG |
| `IFlip` | 协议指纹，Registry 和外围都认这个接口 |

## 权限一览

| 动作 | 谁能调 |
|------|--------|
| 创建集合 | 任何人 |
| mint / buy / sell | 任何人 |
| 升级集合实现 | Factory（UUPS owner） |
| 改 baseURI / 转让 creator | creator |
| 抽协议费 | FeeVault.admin |
| 登记 Registry | 任何人（接口检查） |

没有 AccessControl 多角色、没有 Pausable、没有 Timelock。升级路径存在，但治理是「Factory owner + FeeVault admin」两把钥匙。

英文版：[modules.md](./modules.md)。
