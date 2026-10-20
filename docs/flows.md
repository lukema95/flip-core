English | [中文](./flows.zh.md)

# Core Flows

Flows are written in real call order; the numbers match the actual execution steps.

## 0. System deployment (once)

```
deployer
  ├─ FeeVault            admin = deployer, protocolFee = 20%
  ├─ Registry
  ├─ Price               no constructor arguments
  ├─ Flip                implementation, not initialized
  └─ Factory(registry, feeVault, price, flipImpl)
```

Every collection shares these singletons afterwards. **ETH liquidity is not in Factory; it sits in each collection proxy's own balance.**

---

## 1. Creating a collection

```
Creator ──createFlip(name, symbol, initialPrice, maxSupply, maxPrice, fee, uri)──► Factory
                                                                                      │
                         Validator.validateFlipParams                               │
                         salt = keccak(name, symbol, initialPrice, maxSupply, maxPrice)
                         initData = Flip.initialize(..., feeVault, price, creator, uri)
                                                                                      │
                         new ERC1967Proxy{salt}(Flip_IMPLEMENTATION, initData)        │
                                                                                      │
                         proxy delegatecalls initialize                               │
                           ├─ ERC721/Ownable/UUPS init   owner = Factory
                           └─ Storage init               creator = user
                                                                                      │
                         Registry.register(creator, proxy)                            │
                         emit FlipCreated
```

**CREATE2 precomputation**: the front end can call `calculateFlipAddress` before sending the transaction, e.g. to display the address that is about to be deployed.

---

## 2. Mint (new token)

What drives pricing is **currentSupply**, not the token id itself.

```
User ── mint{value} ──► Flip
  1. totalSupply < maxSupply
  2. (price, fee) = Price.getBuyPriceAndFee(this)     // supply = currentSupply
  3. require msg.value >= price + fee
  4. tokenId = totalSupply + 1
  5. _safeMint(user, tokenId)
  6. currentSupply++
  7. emit TokenMinted
  8. distributeFee(fee)     // split between creator and FeeVault
  9. refund msg.value - (price+fee)
     contract balance += price   // curve reserve, used for future buy-backs
```

For the first token: `currentSupply = 0` → price = `initialPrice`. After it is minted `currentSupply = 1`, and the next token costs more.

Through `Trade.mint`: Trade becomes the mint recipient (`_safeMint` goes to `msg.sender` = Trade), then `safeTransferFrom`s the NFT to the user. The user must send enough ETH to Trade.

---

## 3. Sell (sell back into the pool)

```
Owner ── sell(tokenId) ──► Flip
  1. ownerOf(tokenId) == msg.sender
  2. (price, fee) = Price.getSellPriceAndFee(this)    // the supply-1 step
  3. _transfer(user → this)
  4. _addAvailableToken(tokenId)                      // enters the pool
  5. currentSupply--                                  // curve steps back one level
  6. emit TokenSold
  7. user.call{value: price - fee}
  8. distributeFee(fee)
```

Afterwards `ownerOf(tokenId) == address(this)` and `isOnSale = true`. Nothing is burned; the id survives, only the owner becomes the pool.

**Reserve intuition** (same level):

- Mint at supply=n: the contract receives `buyPrice(n)`
- Sell right after: `currentSupply` is now n+1 and the sell price uses n, roughly the level just paid
- The contract pays out `sellPrice(n)`, returning the reserve to where it was

With fees, both directions skim ETH, so the pool thins out — that is the intended protocol/creator cut, not a lossless AMM.

---

## 4. Buy (buy from the pool)

```
Buyer ── buy{value}(tokenId) ──► Flip
  1. ownerOf(tokenId) == address(this)                // must be in the pool
  2. (price, fee) = Price.getBuyPriceAndFee(this)     // buy price at current supply
  3. _transfer(this → buyer)
  4. _removeAvailableToken(tokenId)                   // O(1) swap-and-pop
  5. currentSupply++
  6. distributeFee + refund
```

Note: **which tokenId you buy does not change the price**. Price only depends on `currentSupply`. `quickBuy` takes the last entry of `availableTokens`, which merely saves picking an id.

When the pool is empty you can only `mint` new ids, not `buy`. `mint` is also bounded by `maxSupply` (lifetime mint cap): if every id has been minted and all are held by users, you can only wait for someone to `sell` one back.

```
totalSupply     monotonically increasing, lifetime mint count
currentSupply   user-held amount = totalSupply - pooled amount
availableTokens list of token ids in the pool
```

---

## 5. Fee flow

For mint/buy, the user pays `P + F` where `F = P * creatorFeePercent`:

```
user ETH
  ├─ P     stays in Flip                 ← curve reserve
  └─ F
       ├─ F * 20%    → FeeVault         ← protocol
       └─ F * 80%    → creator()        ← creator (paid immediately, not accrued)
```

On sell, `P` comes out of the reserve:

```
Flip reserve
  ├─ P - F  → seller
  └─ F
       ├─ 20% → FeeVault
       └─ 80% → creator
```

The creator fee percent is fixed at creation. The protocol share is fixed in the FeeVault constructor. Both are paid immediately with `call{value}`; if the creator is a contract that cannot receive ETH, the whole transaction reverts (`TransferFailed`).

---

## 6. Batching and quick trades (Trade)

```
bulkMint(n)     loop n mints, price each time, validate msg.value against the sum
bulkBuy(ids)    buy each given id in order
quickBuy        buy availableTokens[last]
bulkQuickBuy(n) buy n last entries in a row
bulkSell(ids)   user approves Trade, NFTs are transferred in and sold one by one, one payout at the end
```

Each iteration changes `currentSupply`, so token i+1 costs more than token i (moving up the curve). This is why batch minting cannot be settled at a single unit price.

---

## State machine (single tokenId)

```
                    mint
         [nonexistent] ──────────► [held by user]
                                  │
                     sell         │         buy
              ┌───────────────────┴───────────────────┐
              ▼                                       ▲
         [in the pool] ───────────────────────────────┘
```

"Available in the pool" means `ownerOf(tokenId) == address(this)` **and** the id is in `availableTokens`.

Chinese version: [flows.zh.md](./flows.zh.md).
