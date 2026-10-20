English | [中文](./modules.zh.md)

# Module Design

Organized as "responsibility / key interface / permissions / notes". All sources live in `src/`.

## 1. Factory — collection factory

File: `Factory.sol`

**Responsibilities**

- Parameter validation (`Validator` + `Constants`)
- Deploying collections with `CREATE2 + ERC1967Proxy`
- Injecting the global `feeVault`, `priceContract` and `creator` at initialization
- Registering the collection in `Registry`
- Precomputing addresses (`calculateFlipAddress`)
- Acting as the proxy's UUPS `owner` (the collection's real `onlyOwner` is Factory)

**Creation path**

| Method | Implementation | Parameters |
|------|----------------|------|
| `createFlip` | `Flip` | `name, symbol, initialPrice, maxSupply, maxPrice, creatorFeePercent, baseUri` |

Salt: `keccak256(abi.encode(name, symbol, initialPrice, maxSupply, maxPrice))`. The final address also depends on the `initialize` calldata (creator, fee, URI) hashed into the creation bytecode, so different creators never collide; the same creator repeating all five parameters will fail because CREATE2 reuses salt and bytecode.

**Permissions**

- Anyone can create a collection (no allowlist)
- There are no standing admin functions; Factory exposes no way to change collection parameters

**Summary**: Factory is where "permissionless issuance + deterministic addresses + shared logic" meet; upgrade authority stays with Factory so individual creators cannot tamper with implementations.

## 2. Registry — project index

File: `Registry.sol`

- `creator => address[]` and `contract => creator`
- `register` checks `supportsInterface(IFlip)` so arbitrary contracts cannot register
- **No `onlyFactory`**: any contract satisfying the interface can self-register

Note: this is a discovery layer, not an authorization layer; to harden it, add `onlyFactory` or EIP-712 signatures.

## 3. Flip — core trading

File: `Flip.sol`, interface `IFlip`

Three write methods:

| Method | Preconditions | State changes | ETH |
|------|------|----------|-----|
| `mint()` | `totalSupply < maxSupply` | mints tokenId = totalSupply+1, `currentSupply++` | user pays `price+fee`, contract keeps `price`, splits `fee` |
| `buy(tokenId)` | `ownerOf == address(this)` | transfers from the pool to the buyer, removes from `availableTokens`, `currentSupply++` | same as mint |
| `sell(tokenId)` | caller is the owner | transfers to the contract, adds to the pool, `currentSupply--` | contract pays `price-fee` to the seller, then splits `fee` |

`isOnSale`: whether the owner is the contract itself.

`distributeFee`:

```
protocolFee = fee * FeeVault.protocolFeePercent / 1e18
creatorFee  = fee - protocolFee
creator.call{value: creatorFee}
feeVault.call{value: protocolFee}
```

Overpayment is handled by `_refundExcess`.

## 4. BaseNFT — NFT base

File: `core/BaseNFT.sol`

Composition:

- OZ ERC721 + Enumerable + Holder (the contract must be able to receive its own NFTs to act as a pool)
- Ownable + UUPS (`_authorizeUpgrade` = `onlyOwner`)
- `Storage`

Metadata:

- `tokenURI` = `baseURI/tokenId.json`
- `contractURI` = `baseURI/collection.json` (ERC-7572)

`tokensOfOwner` / `tokensOfOwnerInRange`: on-chain enumeration; gas grows linearly with holdings, and the code carries a TODO — such queries are better served by a Subgraph.

Initialization calls `__Ownable_init(msg.sender)`; the proxy is deployed by Factory and `delegatecall`s `initialize`, so **owner = Factory**.

## 5. Storage — collection state

File: `core/Storage.sol`

The ERC-7201 struct is described in the architecture doc. The most important business part is the pool:

```
_addAvailableToken    // sell: push + record index
_removeAvailableToken // buy: swap-with-last + pop, O(1)
```

`currentSupply` only changes through `_increment / _decrement`, keeping it aligned with mint/buy/sell.

The creator can change `setCreator` and `setBaseURI`. `priceContract` / `initialPrice` / `maxSupply` cannot be changed (locked at deployment).

## 6. Price — pricing engine

File: `core/Price.sol`, interface `IPrice`

**Singleton, stateless.** Every collection shares one Price; computations take a `storageContract` (the collection address) and read parameters through `IStorage`.

Default curve (`calculatePrice`):

- `supply == 0` → `initialPrice`
- otherwise:

```
price = initialPrice
      + initialPrice * 2
        * sqrt(100 * supply * maxSupply)
        * sqrt(10000 * supply²)
        / maxSupply²
```

- when `maxPrice > 0`, `min(price, maxPrice)` caps it

The buy/sell spread comes from which supply value is used, not an extra spread:

| | supply used |
|--|-------------|
| buy / mint | `currentSupply` (price of the next token) |
| sell | `currentSupply == 0 ? 0 : currentSupply - 1` (the level just bought at) |

Fees: `fee = price * creatorFeePercent / 1 ether`

- `getBuyPriceAfterFee` = price + fee (what the user pays)
- `getSellPriceAfterFee` = price - fee (what the seller receives)

Pluggable implementations (`extensions/bodingcurve/`, the directory name is a typo for bonding):

| Contract | Growth shape | Parameters |
|------|----------|------|
| `Price` (default) | moderate, sqrt-based | no extra immutables |
| `LinearPrice` | roughly geometric | `PRICE_MULTIPLIER` (1000–2000 bps) |
| `FixedIncrementPrice` | linear | `PRICE_INCREMENT` |

Swapping curves means deploying a new Price and pointing the collection's `priceContract` at it (Storage **has no setter**, so in practice the curve is chosen at creation or via an upgrade). The interface allows pluggable curves, but the current Factory hardcodes the same Price into `initialize`.

## 7. FeeVault — protocol vault

File: `core/FeeVault.sol`

- `admin` = deployer; can change the admin and withdraw
- `protocolFeePercent = 0.2 ether` (20% of the **creatorFee**, not 20% of the sale price)
- **No `setProtocolFeePercent`**; the rate is locked at deployment
- `receive()` accepts ETH

Example: sale price 1 ETH with `creatorFeePercent = 5%` → fee = 0.05 ETH → protocol 0.01 ETH, creator 0.04 ETH.

## 8. Trade — periphery router

File: `periphery/Trade.sol`

It is an `ERC721Holder`; the flow is always:

1. Call the collection's mint/buy/sell with Trade as `msg.sender`
2. Then `safeTransferFrom` the NFT to the real user
3. Or the reverse: the user transfers the NFT to Trade first, then `sell`

Capabilities: `mint/buy/sell`, `quickBuy` (the last tokenId in the pool), `bulk*`.

`quickBuy` forwards only `price` to `buy()`, so excess ETH is not refunded on that path (unlike calling `Flip.buy` directly). The periphery decides its own payment precision.

The `ReentrancyGuard` import at the top of the file is commented out and the batch loops make external calls — this is a valid improvement area.

## 9. Libs / Examples / Interfaces

| Module | Purpose |
|------|------|
| `libs/Constants` | initial price 0.0001–1 ETH; supply 100–1e6; creator fee 1%–100% (exclusive) |
| `libs/Validator` | pre-creation validation used by Factory |
| `examples/FlipNFT` + `Trait` | writes a `tokenSeed` on mint; `tokenURI` returns an on-chain random SVG |
| `IFlip` | protocol fingerprint; Registry and the periphery rely on this interface |

## Permissions at a glance

| Action | Who may call |
|------|--------|
| Create a collection | anyone |
| mint / buy / sell | anyone |
| Upgrade a collection implementation | Factory (UUPS owner) |
| Change baseURI / transfer creator | creator |
| Withdraw protocol fees | FeeVault.admin |
| Register in Registry | anyone (interface check) |

There is no multi-role AccessControl, no Pausable and no Timelock. Upgrades exist, and governance is "Factory owner + FeeVault admin".

Chinese version: [modules.zh.md](./modules.zh.md).
