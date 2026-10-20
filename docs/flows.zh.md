[English](./flows.md) | 中文

# 核心流程

下面按真实调用顺序写，编号对应实际执行步骤。

## 0. 系统部署（一次）

```
deployer
  ├─ FeeVault            admin = deployer, protocolFee = 20%
  ├─ Registry
  ├─ Price               无构造参数
  ├─ Flip                implementation，不 initialize
  └─ Factory(registry, feeVault, price, flipImpl)
```

之后所有集合共享这些单例。**ETH 流动性不在 Factory，而在每个集合 Proxy 自己的余额里。**

---

## 1. 创建集合

```
Creator ──createFlip(name, symbol, initialPrice, maxSupply, maxPrice, fee, uri)──► Factory
                                                                                      │
                         Validator.validateFlipParams                               │
                         salt = keccak(name, symbol, initialPrice, maxSupply, maxPrice)
                         initData = Flip.initialize(..., feeVault, price, creator, uri)
                                                                                      │
                         new ERC1967Proxy{salt}(Flip_IMPLEMENTATION, initData)        │
                                                                                      │
                         Proxy delegatecall initialize                                │
                           ├─ ERC721/Ownable/UUPS init   owner = Factory
                           └─ Storage init               creator = 用户
                                                                                      │
                         Registry.register(creator, proxy)                            │
                         emit FlipCreated
```

**CREATE2 预计算**：前端可先 `calculateFlipAddress` 再发交易，用于展示「即将部署的地址」。

---

## 2. Mint（新铸）

参与定价的是 **currentSupply**，不是 tokenId 本身。

```
User ── mint{value} ──► Flip
  1. totalSupply < maxSupply
  2. (price, fee) = Price.getBuyPriceAndFee(this)     // supply = currentSupply
  3. require msg.value >= price + fee
  4. tokenId = totalSupply + 1
  5. _safeMint(user, tokenId)
  6. currentSupply++
  7. emit TokenMinted
  8. distributeFee(fee)     // 切给 creator + FeeVault
  9. refund msg.value - (price+fee)
     合约余额 += price      // 曲线储备，将来用于回购
```

第一件：`currentSupply = 0` → 价 = `initialPrice`。铸完 `currentSupply = 1`，下一件更贵。

经 `Trade.mint`：Trade 作为铸造接收者（`_safeMint` 到 `msg.sender` = Trade），再 `safeTransferFrom` 给用户。用户需要先给 Trade 足够 ETH。

---

## 3. Sell（卖回池）

```
Owner ── sell(tokenId) ──► Flip
  1. ownerOf(tokenId) == msg.sender
  2. (price, fee) = Price.getSellPriceAndFee(this)    // supply-1 那一档
  3. _transfer(user → this)
  4. _addAvailableToken(tokenId)                      // 进入交易池
  5. currentSupply--                                  // 曲线回退一档
  6. emit TokenSold
  7. user.call{value: price - fee}
  8. distributeFee(fee)
```

之后 `ownerOf(tokenId) == address(this)`，`isOnSale = true`。NFT 没有 burn，ID 保留，只是归属变成池子。

**储备守恒直觉**（同一档）：

- 在 supply=n 时 mint，合约收入 `buyPrice(n)`
- 再 sell，此时 currentSupply=n+1，sellPrice 用 n，约等于刚付的那档
- 合约支出 `sellPrice(n)`，储备回到卖出前

有 fee 时，买卖都会抽走一部分 ETH，池子相对变薄——这是刻意的协议/创作者抽成，不是无损耗 AMM。

---

## 4. Buy（从池中买）

```
Buyer ── buy{value}(tokenId) ──► Flip
  1. ownerOf(tokenId) == address(this)                // 必须在池里
  2. (price, fee) = Price.getBuyPriceAndFee(this)     // 当前流通量的买价
  3. _transfer(this → buyer)
  4. _removeAvailableToken(tokenId)                   // O(1) swap-and-pop
  5. currentSupply++
  6. distributeFee + refund
```

注意：**买哪一个 tokenId 不改变价格**。价格只看 `currentSupply`。`quickBuy` 取 `availableTokens` 最后一个，只是省掉选 ID。

池空时只能 `mint` 新号，不能 `buy`。`mint` 还受 `maxSupply`（历史铸造上限）约束：若所有号都铸完且都在用户手里，只能等有人 sell 回来。

```
totalSupply     单调不减，历史铸造量
currentSupply   用户持有量 = totalSupply - 池内数量
availableTokens 池内 tokenId 列表
```

---

## 5. 费用流

以 mint/buy 为例，用户支付 `P + F`，`F = P * creatorFeePercent`：

```
用户 ETH
  ├─ P     留在 Flip 合约          ← 曲线储备
  └─ F
       ├─ F * 20%    → FeeVault      ← 协议
       └─ F * 80%    → creator()     ← 创作者（立刻转账，不是累计领取）
```

sell 时从储备拿出 `P`：

```
Flip 储备
  ├─ P - F  → 卖家
  └─ F
       ├─ 20% → FeeVault
       └─ 80% → creator
```

创作者费率在创建时锁定。协议分成比例在 FeeVault 构造时锁定。两边都是即时 `call{value}`，创作者若是不能收款的合约，整笔交易 revert（`TransferFailed`）。

---

## 6. 批量与快捷（Trade）

```
bulkMint(n)     循环 n 次 mint，每次现价，累加校验 msg.value
bulkBuy(ids)    按指定 ID 依次 buy
quickBuy        买 availableTokens[last]
bulkQuickBuy(n) 连续买 n 个 last
bulkSell(ids)   用户先授权 Trade，逐个转入再 sell，最后一次性打款
```

循环中每次都会让 `currentSupply` 变化，所以第 i+1 件比第 i 件贵（曲线上移）。批量铸造因此无法按单一单价结算。

---

## 状态机（单 tokenId）

```
                    mint
         [不存在] ──────────► [用户持有]
                                  │
                     sell         │         buy
              ┌───────────────────┴───────────────────┐
              ▼                                       ▲
         [池内待售] ────────────────────────────────┘
```

池内待售的判据是 `ownerOf(tokenId) == address(this)` 且 tokenId 在 `availableTokens` 里。

英文版：[flows.md](./flows.md)。
