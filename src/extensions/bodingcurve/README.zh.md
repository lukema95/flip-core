[English](./README.md) | 中文

# Bonding Curve 定价合约

本目录包含 Flip 协议的备选定价实现，在基础 `Price.sol` 之外提供不同的 bonding curve 公式。

## 合约

### 1. LinearPrice.sol
实现线性乘数定价模型：`Price = min(initialPrice + a * lastPrice, maxPrice)`

**公式**：每个新 token 的价格 = 初始价 + 上一件价格 × 乘数，并以 `maxPrice` 封顶。

**参数**：
- `priceMultiplier`：乘数系数（基点，默认 1100 = 1.1x）
- `maxPrice`：上限价格，存放在 Storage 合约中（0 = 不封顶）
- `initialPrice`：第一件 token 的起始价格

**示例**：
- 初始价：1 ETH
- 乘数：1.1x（1100 基点）
- 上限价：3 ETH
- 第 1 件：1 ETH + 1.1 × 1 ETH = 2.1 ETH
- 第 2 件：min(1 ETH + 1.1 × 2.1 ETH, 3 ETH) = min(3.31 ETH, 3 ETH) = 3 ETH
- 第 3 件：min(1 ETH + 1.1 × 3 ETH, 3 ETH) = 3 ETH

### 2. FixedIncrementPrice.sol
实现固定加价定价模型：`Price = min(initialPrice + x * a, maxPrice)`

**公式**：每个新 token 的价格 = 初始价 + 固定增量，并以 `maxPrice` 封顶。

**参数**：
- `priceIncrement`：每件 token 的固定加价（默认 0.1 ETH）
- `maxPrice`：上限价格，存放在 Storage 合约中（0 = 不封顶）
- `initialPrice`：第一件 token 的起始价格

**示例**：
- 初始价：1 ETH
- 增量：0.1 ETH
- 上限价：1.5 ETH
- 第 1 件：1 ETH + 1 × 0.1 ETH = 1.1 ETH
- 第 2 件：1 ETH + 2 × 0.1 ETH = 1.2 ETH
- 第 5 件：1 ETH + 5 × 0.1 ETH = 1.5 ETH
- 第 6 件：min(1 ETH + 6 × 0.1 ETH, 1.5 ETH) = min(1.6 ETH, 1.5 ETH) = 1.5 ETH

## 架构

每个定价合约管理自己的不可变参数：

- `LinearPrice`：管理 `priceMultiplier`（immutable）
- `FixedIncrementPrice`：管理 `priceIncrement`（immutable）
- `maxPrice` 存放在 Storage 合约中，可由 creator 更新
- 两个合约都实现 `IPrice` 接口，并与基础 `Storage` 合约配合工作
- 乘数 / 增量参数在部署时设定，之后不可更改
- `maxPrice` 提供安全上限，防止价格过度增长（0 = 不封顶）

## 用法

### 部署

部署定价合约时传入参数（部署后不可变）：

```solidity
// 部署乘数 1.1x 的 LinearPrice
LinearPrice linearPrice = new LinearPrice(1100); // 1100 = 1.1x

// 部署增量 0.1 ETH 的 FixedIncrementPrice
FixedIncrementPrice fixedPrice = new FixedIncrementPrice(0.1 ether);

// 在 Storage 合约中设置 maxPrice（之后可以更新）
storageContract.setMaxPrice(10 ether); // 上限 10 ETH
```

**注意**：乘数 / 增量参数不可变，部署后无法修改。`maxPrice` 可在 Storage 合约中更新。

### 计算价格

```solidity
// 当前买入价
uint256 buyPrice = linearPrice.getBuyPrice(storageContract);

// 当前卖出价
uint256 sellPrice = linearPrice.getSellPrice(storageContract);

// 含手续费的价格
uint256 buyPriceWithFee = linearPrice.getBuyPriceAfterFee(storageContract);
uint256 sellPriceWithFee = linearPrice.getSellPriceAfterFee(storageContract);

// 计算指定 supply 下的价格
uint256 price = linearPrice.calculatePrice(storageContract, 5);
```

### 自定义计算

```solidity
// 指定乘数计算线性价格
uint256 price = linearPrice.calculatePriceWithMultiplier(
    storageContract,
    5, // supply
    1500 // 1.5x 乘数
);

// 指定增量计算固定加价
uint256 price = fixedIncrementPrice.calculatePriceWithIncrement(
    storageContract,
    10, // supply
    0.3 ether // 增量
);

// 计算多件的总成本
uint256 totalCost = fixedIncrementPrice.calculateTotalCost(
    storageContract,
    0, // 当前 supply
    3  // 要 mint 的数量
);
```

## 对比

| 模型 | 公式 | 价格增长 | 适用场景 |
|-------|---------|--------------|----------|
| 线性乘数 | `initialPrice + a * lastPrice` | 指数型 | 高价值集合 |
| 固定增量 | `initialPrice + x * a` | 线性 | 价格可预测 |
| 默认（平方根） | 复合公式 | 中等 | 平衡增长 |

## 测试

运行测试以验证定价计算：

```bash
forge test --match-contract BondingCurveTest -vv
```

## 集成

在 Flip 集合中使用这些定价合约：

1. 部署目标定价合约（`LinearPrice` 或 `FixedIncrementPrice`）并传入初始参数
2. 把 `Storage` 合约里的 `priceContract` 指向新的定价合约
3. 如需封顶，在 Storage 合约中设置 `maxPrice`
4. Flip 协议会自动使用新的定价模型

### 参数管理

- 乘数 / 增量参数不可变，部署后无法更改
- `maxPrice` 可由 creator 在 Storage 合约中更新
- 参数会经过校验，确保取值合理
- 所有参数变更都会发事件，保证透明
- creator 可以把所有权转给另一个地址

## 安全考量

- 乘数 / 增量参数不可变，部署后无法更改
- `maxPrice` 存放在 Storage 合约中，可由 creator 更新
- 参数会经过校验，拒绝非法值
- `maxPrice` 可防止价格过度增长
- 所有计算都使用 Math 库以保证安全
- 所有计算都是 view 函数，节省 gas
- 手续费计算与价格计算分离

英文版：[README.md](./README.md)。
