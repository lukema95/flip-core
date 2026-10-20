[English](./faq.md) | 中文

# 常见问题

按「问题 → 结论 → 依据」组织。数字和公式以当前 `src` 为准。

---

## A. 产品与机制

### 1. Flip 和 OpenSea / Sudoswap / 普通 ERC721 有什么区别？

- 普通 ERC721：只记账，交易在外部市场，流动性靠订单簿。
- OpenSea 类：链下订单 + 链上结算，royalty 不一定强制。
- Sudoswap：NFT AMM，但池子是独立 Pair，定价多是线性/指数自定义池。
- Flip：每个集合合约 **自己就是池**，强制 Bonding Curve，创作者无预留，fee 在 mint/buy/sell 三条路径都执行。

一句话：资产、曲线、储备、池子四合一。

### 2. 为什么用 Bonding Curve 给 NFT 定价？

NFT 单件差异大、订单簿深度差。曲线把「下一件买价 / 上一件卖价」变成 `f(supply)`，保证：

- 永远有报价（只要池里有 NFT 或还能 mint）
- 供给增加价格上升，卖回供给下降价格回落
- 不需要做市商手动挂单

代价：同系列不同 tokenId **同价**（价格不看稀有度）；费用会抽取储备。

### 3. 创作者「无预留」具体怎么保证？

Factory 没有 `mintToCreator`。`creator` 只出现在 Storage 和分费地址里。创作者要 NFT 必须自己 `mint` 并付当前曲线价。`Ownable owner` 是 Factory，创作者连升级权都没有。

---

## B. 定价与供给

### 4. `currentSupply` 和 `totalSupply` 为什么要拆开？

| | 谁改 | 含义 |
|--|------|------|
| `ERC721.totalSupply` | mint 时 +1，永不因 sell 减少 | 已经存在的 token 数量（含池里的） |
| `Storage.currentSupply` | mint/buy +1，sell -1 | 在用户手里的数量，**进曲线的 x** |

如果用 `totalSupply` 定价，卖回池价格不会下降，回购无法闭环。

### 5. 买价和卖价怎么算？有没有 spread？

```
buyPrice  = calculatePrice(currentSupply)
sellPrice = calculatePrice(currentSupply == 0 ? 0 : currentSupply - 1)
```

没有额外 bid-ask spread。用户感知的价差来自：

1. 买卖用相邻两档 supply
2. `creatorFeePercent`：买付 `P+F`，卖收 `P-F`

默认 `calculatePrice` 是带 `sqrt` 的多项式，`supply=0` 退回 `initialPrice`，`maxPrice>0` 时封顶。

### 6. 曲线公式怎么用白话讲？

不必背展开式。要点：

- 单调递增（supply 越大越贵）
- 用 `Math.sqrt` 防溢出
- 含 `maxSupply`，供给上限会压增长速度
- `maxPrice` 是硬顶，防止后期无限涨

可插拔：`IPrice` 还有线性乘数（`LinearPrice`）和固定加价（`FixedIncrementPrice`）。Factory 当前统一注入默认 `Price`。

### 7. 批量 mint 为什么后面比前面贵？

`Trade.bulkMint` 循环里每次 `mint` 都会 `currentSupply++`，下一次 `getBuyPriceAfterFee` 读到的已经是新供给。必须按「路径上每一点的瞬时价」累加，不能 `单价 * n`（除非曲线已触及 `maxPrice` 平台）。

---

## C. 架构与升级

### 8. 为什么是 Proxy + 共享 Implementation，而不是每个集合 clone 全量代码？

- 部署 gas：Proxy 很小，逻辑部署一次
- 升级：UUPS `_authorizeUpgrade`，所有集合可指向新实现（由 Factory owner 执行）
- 地址稳定：用户始终和 Proxy 交互

用 ERC1967 而不是最小 Beacon：每个集合仍可独立升级；当前 owner 统一是 Factory，实际上是「工厂控升级」。

### 9. 为什么存储用 ERC-7201？

OZ ERC721/Ownable/UUPS 自己占 slot 0 起的布局。如果 Flip 再往实现合约普通变量里塞 `currentSupply`，升级加父类字段就容易错槽。

Namespaced storage 把业务状态放到哈希 slot（`flip.storage.Storage` → `0xeb5d…b000`），和 OZ 布局解耦。`StorageSlotTest` 断言常量与计算值一致，防止改 namespace 忘改常量。

### 10. owner 和 creator 为什么不是同一个人？

| | 地址 | 能力 |
|--|------|------|
| `owner` | Factory | UUPS 升级 |
| `creator` | 发集合的用户 | 收 80% 手续费；改 URI；转让 creator |

创作者不能升级逻辑（防恶意实现调走池子 ETH），协议方也不能冒充 creator 收主费。

### 11. CREATE2 的 salt 为什么不含 creator？

`salt = keccak(name, symbol, initialPrice, maxSupply, maxPrice)`。地址仍因 `initialize` calldata（含 creator、fee、uri）进入 creation bytecode 哈希而不同。

含义：salt 碰撞不等于地址碰撞。两人发同名同参数时 initData 不同 → 地址不同；同一人完全重复参数会 CREATE2 失败（同 salt 同 bytecode）。

---

## D. 资金与安全

### 12. 池子里的 ETH 从哪来、到哪去？

来源：每次 mint/buy 留下的 `price`。  
去向：sell 时按卖价付出 `price`（其中一部分立刻变成 fee 打给 creator 和 FeeVault）。

合约必须能 `receive`/`call` 到 ETH。`Flip` 本身没有 `receive`，靠 payable `mint/buy` 入金；`Trade` 有 `receive`。卖出依赖合约余额 ≥ 应付金额，否则 `TransferFailed`。

### 13. 重入怎么防护？

mint/buy 顺序：改 supply 和 NFT → 再 `distributeFee` / `refund`（外部 call）。  
sell：先转 NFT、改池、减 supply，再给卖家打款，再分费。

状态已在外部调用前更新，简单重入 mint 会买到 **更高** 的下一档，而不是同一档双花。但当前实现仍存在改进空间：

- 没有 `ReentrancyGuard`（Trade 里被注释掉）
- 恶意 creator 合约可在收 fee 时回调
- 批量函数多次外部调用

遵循了「先改内部状态再转 ETH」的模式，但缺少显式防重入和 pause。

### 14. Registry 没有 onlyFactory，有什么风险？

垃圾合约只要 `supportsInterface(IFlip)` 就能登记，污染 `getCreatorContracts`。不直接丢用户资金，但会污染索引。前端/Subgraph 应以 Factory 的 `FlipCreated` 事件为准。

### 15. 协议费 20% 是 20% 的成交额吗？

不是。是 **creatorFee 的 20%**。成交价 1 ETH、创作者费率 5% 时，协议只拿 0.01 ETH。`protocolFeePercent` 没有 setter，要改只能重新部署 FeeVault 并升级集合的 `feeVault` 指针（而 Storage 同样没有 `setFeeVault`）——实际上协议费率几乎不可治理变更。

### 16. sell 时创作者是合约且 `receive` revert，会怎样？

整笔 sell revert，用户卖不出去。即时结算换来了「创作者地址必须能收款」的约束。对比「累加 pending 再 withdraw」模式，当前实现更简单，对恶意/错误 creator 更脆。

---

## E. 工程与风险

### 17. 为什么 Price 做成外部合约而不是 library？

Library 会把曲线打进每个 implementation。外部 `IPrice`：

- 全集合共享一份曲线代码
- 理论上可换曲线（接口已预留 `storageContract` 参数）
- `view` 调用多一次 external，换来可升级定价

Trade 每次循环都 `getBuyPriceAfterFee`，批量时这是额外 gas。

### 18. Trade 存在的意义？集合上不是已经有 mint/buy/sell 了吗？

- 单笔：用户可直调 Flip
- 批量、快捷买、统一事件：放外围，避免核心合约超体积
- Trade 持有 NFT 的窗口期很短（同一笔 tx）

这是 Uniswap 式 Core / Periphery。

### 19. 当前主要的技术风险是什么？

按优先级列 3 条：

1. **池子 ETH 与 NFT 同合约**，UUPS owner（Factory）若被盗，可升级抽储备
2. **buy 只看 owner==this**，不校验 `availableTokens` 数组，条件重叠不足
3. **无 pause / 无 ReentrancyGuard / Registry 无准入**，应急能力弱

对应改进：Timelock 管 Factory owner、`buy` 校验 `tokenIndex`、加 Pausable、Registry `onlyFactory`。

### 20. 测试覆盖了哪些路径？

`test/`：

- `Factory.t.sol`：创建、CREATE2 地址、事件、参数校验
- `periphery/Trade.t.sol`：批量路径
- `extensions/BondingCurveTest.t.sol`：备选曲线
- `Registry.t.sol` / `StorageSlotTest.t.sol`：登记与 ERC-7201 slot（含常量断言）

尚未覆盖：曲线在 `maxPrice` 附近的行为、supply=0 时卖出、fee 使储备变薄后无法全额回购等不变式场景。

---

## 一页速览

1. 系统层：Factory / Registry / Price / FeeVault → 集合 Proxy(Flip) → Trade
2. mint：ETH 进合约、NFT 给用户、supply+1、价上涨
3. sell：NFT 进合约数组、supply-1、ETH 出、价回落
4. 升级权在 Factory；创作者只收费、改元数据

英文版：[faq.md](./faq.md)。
