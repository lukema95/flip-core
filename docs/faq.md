English | [中文](./faq.zh.md)

# FAQ

Organized as "question → conclusion → rationale". Numbers and formulas reflect the current `src`.

---

## A. Product and mechanics

### 1. How is Flip different from OpenSea / Sudoswap / plain ERC721?

- Plain ERC721: bookkeeping only; trading happens on external markets and liquidity depends on order books.
- OpenSea-style: off-chain orders + on-chain settlement, royalties not always enforced.
- Sudoswap: NFT AMM, but pools are separate pairs and pricing is usually linear/exponential or custom.
- Flip: each collection contract **is the pool**, with a mandatory bonding curve, no reserved mint for creators, and fees charged on all of mint/buy/sell.

In short: asset, curve, reserve and pool are one contract.

### 2. Why use a bonding curve to price NFTs?

NFTs differ a lot per item and order books are thin. A curve turns "next buy price / previous sell price" into `f(supply)` and guarantees:

- a quote at all times (as long as the pool holds NFTs or minting is possible)
- price rises as supply grows and falls as it is sold back
- no need for a market maker to place orders manually

The trade-off: all tokenIds in a collection **share one price** (rarity is ignored), and fees skim the reserve.

### 3. How is "no reserved mint" actually guaranteed?

Factory has no `mintToCreator`. `creator` only appears in Storage and as the fee recipient. To get an NFT a creator must `mint` and pay the current curve price. The `Ownable owner` is Factory, so creators have no upgrade rights either.

---

## B. Pricing and supply

### 4. Why separate `currentSupply` from `totalSupply`?

| | Changed by | Meaning |
|--|------|------|
| `ERC721.totalSupply` | +1 on mint, never decreases on sell | number of tokens that exist (including pooled ones) |
| `Storage.currentSupply` | +1 on mint/buy, -1 on sell | number held by users, **the x in the curve** |

Pricing off `totalSupply` would keep the sell-back price from falling and make buy-backs impossible to close the loop.

### 5. How are buy and sell prices computed? Is there a spread?

```
buyPrice  = calculatePrice(currentSupply)
sellPrice = calculatePrice(currentSupply == 0 ? 0 : currentSupply - 1)
```

There is no extra bid-ask spread. The difference users see comes from:

1. buys and sells using adjacent supply levels
2. `creatorFeePercent`: buyers pay `P+F`, sellers receive `P-F`

The default `calculatePrice` is a `sqrt`-based polynomial, falls back to `initialPrice` when `supply=0`, and is capped when `maxPrice>0`.

### 6. How would you explain the curve formula in plain words?

No need to recite the expansion. Key points:

- monotonically increasing (more supply, higher price)
- `Math.sqrt` bounds the growth
- includes `maxSupply`, so the supply cap slows growth
- `maxPrice` is a hard ceiling against runaway prices

Pluggable: `IPrice` also ships `LinearPrice` (multiplier) and `FixedIncrementPrice` (fixed step). Factory currently injects the default `Price`.

### 7. Why does batch minting get more expensive per token?

In `Trade.bulkMint`, every `mint` increments `currentSupply`, so the next `getBuyPriceAfterFee` already sees the new supply. You must accumulate the instantaneous price along the path rather than multiplying a unit price by n (unless the curve has already reached `maxPrice`).

---

## C. Architecture and upgrades

### 8. Why proxies with a shared implementation instead of cloning full code per collection?

- Deployment gas: the proxy is small and the logic is deployed once
- Upgrades: UUPS `_authorizeUpgrade` lets every collection point at a new implementation (executed by the Factory owner)
- Stable addresses: users always interact with the proxy

ERC1967 instead of a minimal Beacon: each collection can still be upgraded individually; with the owner set to Factory it is effectively "factory-controlled upgrades".

### 9. Why ERC-7201 for storage?

OZ's ERC721/Ownable/UUPS occupy the layout starting at slot 0. If Flip put `currentSupply` into ordinary variables of the implementation, adding parent fields during an upgrade could easily land in the wrong slot.

Namespaced storage moves business state to a hashed slot (`flip.storage.Storage` → `0xeb5d…b000`), decoupled from OZ's layout. `StorageSlotTest` asserts the constant equals the computed value, so changing the namespace without changing the constant fails the build.

### 10. Why aren't owner and creator the same address?

| | Address | Powers |
|--|------|------|
| `owner` | Factory | UUPS upgrades |
| `creator` | the user who launched the collection | receives 80% of the fee; manages the URI; transfers creator |

Creators cannot upgrade logic (which would let a malicious implementation drain the reserve), and the protocol cannot impersonate the creator to collect the creator fee.

### 11. Why doesn't the CREATE2 salt include the creator?

`salt = keccak(name, symbol, initialPrice, maxSupply, maxPrice)`. The address still differs because the `initialize` calldata (creator, fee, URI) is hashed into the creation bytecode.

So salt collisions are not address collisions. Two people launching with identical parameters get different initData and therefore different addresses; the same person repeating the parameters exactly fails CREATE2 (same salt, same bytecode).

---

## D. Funds and security

### 12. Where does the ETH in the pool come from and where does it go?

In: the `price` retained on every mint/buy.
Out: on sell the contract pays `price` (part of which immediately becomes fees for the creator and FeeVault).

The contract must be able to receive and send ETH. `Flip` has no `receive`; ETH enters through payable `mint/buy`. `Trade` has a `receive`. Selling requires the contract balance to cover the payout, otherwise `TransferFailed`.

### 13. How is reentrancy handled?

mint/buy order: update supply and NFT state → then `distributeFee` / `refund` (external calls).
sell: transfer the NFT in, update the pool, decrement supply, then pay the seller, then split fees.

State is updated before external calls, so a naive reentrant mint buys the **next, more expensive** level rather than double-spending the same one. Still, there is room to improve:

- no `ReentrancyGuard` (it is commented out in Trade)
- a malicious creator contract can re-enter while receiving fees
- batch functions make repeated external calls

The checks-effects-interactions pattern is followed, but explicit reentrancy protection and a pause switch are missing.

### 14. What is the risk of Registry having no onlyFactory?

Any contract implementing `supportsInterface(IFlip)` can register and pollute `getCreatorContracts`. It does not put user funds at risk but pollutes the index. Front ends and the subgraph should treat Factory's `FlipCreated` event as the source of truth.

### 15. Is the 20% protocol fee 20% of the sale amount?

No. It is 20% of the **creatorFee**. For a 1 ETH sale with a 5% creator fee, the protocol receives 0.01 ETH. `protocolFeePercent` has no setter; changing it requires redeploying FeeVault and upgrading the collection's `feeVault` pointer (and Storage has no `setFeeVault` either) — in practice the protocol rate is effectively immutable.

### 16. What happens if the creator is a contract whose `receive` reverts?

The whole sell reverts and the user cannot sell. Immediate settlement imposes a "creator must be able to receive ETH" constraint. Compared with an accrued-pending/withdraw model, this is simpler but more fragile against malicious or misconfigured creators.

---

## E. Engineering and risks

### 17. Why is Price an external contract rather than a library?

A library would inline the curve into every implementation. An external `IPrice`:

- shares one copy of curve code across all collections
- allows swapping curves (the interface already takes a `storageContract` argument)
- costs one extra external `view` call in exchange for upgradeable pricing

Trade calls `getBuyPriceAfterFee` on every loop iteration, so batching pays that extra gas.

### 18. What is Trade for, given that collections already have mint/buy/sell?

- Single trades: users can call Flip directly
- Batching, quick buys and unified events live in the periphery so the core contract stays under the size limit
- Trade holds NFTs only for a very short window (within one transaction)

This is the Uniswap-style Core / Periphery split.

### 19. What are the main technical risks today?

Three, in priority order:

1. **The ETH reserve and the NFTs share one contract**: if the UUPS owner (Factory) is compromised, an upgrade can drain the reserve
2. **`buy` only checks `owner == this`**, not membership in `availableTokens`, so the conditions overlap loosely
3. **No pause, no `ReentrancyGuard`, no Registry gatekeeping**, which weakens incident response

Mitigations: put Factory ownership behind a Timelock, have `buy` check `tokenIndex`, add Pausable, and add `onlyFactory` to Registry.

### 20. What do the tests cover?

`test/`:

- `Factory.t.sol`: creation, CREATE2 addresses, events, parameter validation
- `periphery/Trade.t.sol`: batching paths
- `extensions/BondingCurveTest.t.sol`: alternative curves
- `Registry.t.sol` / `StorageSlotTest.t.sol`: registration and ERC-7201 slots (including the constant assertion)

Not covered yet: curve behaviour near `maxPrice`, selling when supply=0, and invariants where fees thin the reserve so a full buy-back is impossible.

---

## One-page overview

1. System layer: Factory / Registry / Price / FeeVault → collection proxies (Flip) → Trade
2. mint: ETH enters the contract, the NFT goes to the user, supply +1, price rises
3. sell: the NFT enters the pool array, supply -1, ETH leaves, price falls
4. Upgrade rights stay with Factory; creators only collect fees and manage metadata

Chinese version: [faq.zh.md](./faq.zh.md).
