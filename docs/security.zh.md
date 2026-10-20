[English](./security.md) | 中文

# 安全模型

本文说明谁能做什么、资金放在哪里、代码依赖哪些假设，以及已知的限制。漏洞报告流程见
[SECURITY.zh.md](../SECURITY.zh.md)。

## 状态

- **未审计。** 截至撰写时没有任何第三方审计。
- 合约以 **source-available** 方式提供：核心为 BUSL-1.1，接口/外围/示例/测试为 MIT。
  能读代码不等于经过审计。

## 角色与权限

| 角色 | 是谁 | 能做什么 |
|---|---|---|
| 集合 `owner` | `Factory` 合约 | 升级集合实现（UUPS `_authorizeUpgrade`） |
| `creator` | 调用 `Factory.createFlip` 的账户 | 收取 80% 手续费、修改 `baseURI`、转让 creator |
| `FeeVault.admin` | FeeVault 部署者或其继任者 | 提取协议费、更换 admin |
| 任何人 | 任意账户 | 创建集合、`mint` / `buy` / `sell`、在 `Registry` 注册 |

没有暂停开关、没有白名单、也没有角色层级。`creator` 是 `Storage` 里的业务角色，
**不是** Ownable 的 owner。

## 升级权限

集合是 `ERC1967Proxy`，owner 为 `Factory`。由于 `Factory` 本身没有调用
`upgradeToAndCall` 的函数，当前不扩展 `Factory` 就无法升级集合。在明确增加入口之前，
应把已部署集合视为**事实上不可变**。

如果增加升级入口，需要注意：所有集合的 owner 都是同一个 `Factory` 合约，
一旦 `Factory` 的 ownership 被攻破，所有集合同时失守。在此之前请先把 `Factory`
的 ownership 交给多签或 Timelock。

## 资金在哪里

每个集合持有自己的 ETH 储备，`FeeVault` 持有协议费。集合之间没有共享资金池，
`Factory` 从不持有资金。

成交价 `P`、手续费 `F = P * creatorFeePercent` 时，`mint` / `buy` 的资金流：

```
用户支付 P + F
  P      留在集合（曲线储备）
  F      80% -> creator()，20% -> FeeVault
```

`sell` 反向：集合从储备中付给卖家 `P - F`，并按同样的 80/20 拆分 `F`。

## 不变式

- `totalSupply() == currentSupply() + 池内 token 数`
- ETH 储备只通过 `mint` / `buy` 增加，只通过 `sell` 减少
- `currentSupply` 在每次操作中只朝一个方向变化
- 池内 token 满足 `ownerOf(tokenId) == address(collection)`

`test/FlipInvariants.t.sol` 用 fuzz 验证了第一条不变式与价格单调性。

## 已知限制

以下是明确接受的限制，不是未披露的漏洞。由于对已部署集合而言修复属于共识级变更，
这里把它们写清楚以便权衡。

1. **池成员资格由 owner 推断。** `buy` 只检查 `ownerOf(tokenId) == address(this)`，
   随后用 `tokenIndex[tokenId]` 移除 token，并不校验其是否真在池中。如果有人把 NFT
   直接 `safeTransferFrom` 给集合，池与索引可能不一致，之后对它的 `buy` 可能回滚或
   破坏 `availableTokens`。除 `sell` 之外不要往集合转 NFT。
   建议修复：增加显式 `isPooled[tokenId]` 标记，或在 `buy` 中要求
   `availableTokens[tokenIndex[tokenId]] == tokenId`。
2. **手续费即时支付。** 无法接收 ETH 的 `creator`（没有 `receive` 的合约或会回滚的
   fallback）会让该集合的 `mint` / `buy` / `sell` 全部回滚，没有挂账（pending）兜底。
3. **没有重入锁。** 代码在外部调用前更新状态，能挡住经典重入，但没有
   `ReentrancyGuard`，也没有暂停开关；`Trade` 的批量函数会多次外部调用。
4. **`Registry` 无准入。** 任何实现 `IFlip` 的合约都能注册，发现集合请以 Factory 的
   `FlipCreated` 事件为准。
5. **定价不考虑稀有度。** 同一集合内所有 token 按同一条曲线定价。
6. **曲线在创建时固定。** `Storage` 没有 `priceContract` / `initialPrice` / `maxSupply`
   的 setter，创建后不改升级就无法修改。

## 运维假设

- 部署私钥与 `FeeVault.admin` 应由多签持有
- 在增加任何升级入口前，`Factory` 的 ownership 应为多签或 Timelock
- 前端应从 `Factory` 事件而非仅凭 `Registry` 读取集合地址
- 监控 `FeeVault` 余额与高交易量集合的储备

## 不在范围内

- 前端、subgraph、部署基础设施
- `lib/` 下的第三方依赖（OpenZeppelin、forge-std）
- 并非源自本代码的经济/oracle 风险

## 报告

按 [SECURITY.zh.md](../SECURITY.zh.md) 处理，请勿开公开 issue。

## 静态分析

CI 使用 [Slither](https://github.com/crytic/slither) 配合 `slither.config.json` 与
`--fail-medium` 运行：新增的高危/中危发现会直接让构建失败。基线中排除了五个已评审并接受的检测项：

| 检测项 | 接受原因 |
|---|---|
| `arbitrary-send-eth` | `Flip.sell` 向卖家付款，`Trade` 把调用者的 ETH 转发给调用者指定的集合——这正是市场与路由器的预期行为 |
| `weak-prng` | 仅用于 `Trait` 挑选图案形状，不涉及资金与权限 |
| `reentrancy-eth` | `Flip` 遵循 checks-effects-interactions（先更新状态再付款），重入只能操作调用者自己已持有的 token；当前未加 `ReentrancyGuard`，已列为加固项 |
| `incorrect-equality` | 图案生成器里对 `seed % 5` 的严格相等是一个分支选择，不是余额判断 |
| `uninitialized-local` | Solidity 会把内存变量零初始化，被标记的结构体与字符串随后立即逐字段赋值 |

基线之外的新发现一律视为回归。
