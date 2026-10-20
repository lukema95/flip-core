English | [中文](./architecture.zh.md)

# Contract Architecture

## Product problem

| Market pain point | Flip mechanism | Where it lives |
|----------|-------------|--------------|
| NFT listings are hard to fill | The contract is the pool and can trade on the curve at any time | `Flip.mint/buy/sell` + `Storage.availableTokens` |
| Pricing is guesswork | Bonding curve: price is a function of supply | `core/Price.sol` + pluggable `IPrice` |
| Creators dump on holders | No reserved mint; creators go through the same `mint` | `Factory` gives creators no privileged mint |
| Royalties are hard to enforce | `creatorFeePercent` is taken on every trade | `Flip.distributeFee` + `FeeVault` |

## Layers

```
┌─────────────────────────────────────────────────────────┐
│  Periphery (user-friendly entry points, no core state)   │
│  Trade.sol: bulkMint / quickBuy / bulkSell              │
└──────────────────────────┬──────────────────────────────┘
                           │ calls IFlip
┌──────────────────────────▼──────────────────────────────┐
│  Collection instance (one ERC1967Proxy per project)      │
│  Flip                                                   │
│  inherits BaseNFT = ERC721 + Enumerable + UUPS + Storage │
└──────────┬───────────────────────────────┬──────────────┘
           │ reads the curve               │ pays fees
┌──────────▼──────────┐           ┌────────▼────────┐
│  Price (singleton,   │           │  FeeVault        │
│  stateless)          │           │  (protocol vault)│
│  prices from Storage │           │  20% of fees     │
└─────────────────────┘           └─────────────────┘
           ▲
┌──────────┴──────────────────────────────────────────────┐
│  System (global, deployed once)                          │
│  Factory → deploys proxies with CREATE2                  │
│  Registry → creator ↔ collection index                   │
└─────────────────────────────────────────────────────────┘
```

Design principles:

1. **Logic separate from instances** — one shared `Flip` implementation; each collection is just a proxy plus its own ERC-7201 storage.
2. **Pricing separate from assets** — `Price` holds neither ETH nor NFTs and only computes `view` results; each collection holds its own ETH reserve and pooled NFTs.
3. **Core separate from periphery** — single mint/buy/sell live in the collection; batching and quick buys live in `Trade`.
4. **A single creation entry point** — every collection is deployed by the same `Factory`, keeping implementation versions and init parameters consistent.

## Inheritance

```
Initializable
    └── Storage (ERC-7201: curve params, pool, creator)
            └── BaseNFT
                  ERC721Upgradeable
                  ERC721EnumerableUpgradeable
                  ERC721HolderUpgradeable
                  OwnableUpgradeable
                  UUPSUpgradeable
                    └── Flip  ──implements──► IFlip
                              └── examples/FlipNFT (+ Trait, on-chain SVG)
```

## Deployment topology

System contracts are deployed once; collections are cloned on demand:

```
Deployment order (see scripts/README-deployment.md)

FeeVault ─┐
Registry ─┼─► Factory(registry, feeVault, price, flipImpl)
Price    ─┤
Flip implementation ─┘

User createFlip()
    └── new ERC1967Proxy{salt}(implementation, initialize calldata)
            └── Registry.register(creator, proxy)
```

## Storage model

Collection state is not kept in ordinary state variables but in **ERC-7201 namespaced storage**:

- namespace: `flip.storage.Storage`
- slot: `keccak256(abi.encode(uint256(keccak256(namespace)) - 1)) & ~bytes32(uint256(0xff))`
- current value: `0xeb5d050250a195793d5c215e55811a7e5bc03a3f511fa4bdb2cdf5696dd5b000`
- a test in `StorageSlotTest` asserts that the constant equals the value derived from the namespace, so changing the namespace requires changing the constant too

The benefit: when a UUPS upgrade swaps the implementation, a new contract that keeps reading the same namespace cannot collide with OZ's ERC721/Ownable layout.

Key fields:

| Field | Meaning |
|------|------|
| `initialPrice / maxSupply / maxPrice` | Curve parameters; `maxPrice = 0` means no cap |
| `creatorFeePercent` | Fee relative to price, `1 ether = 100%` |
| `currentSupply` | **Circulating supply**, which determines the current buy/sell price |
| `availableTokens[]` + `tokenIndex` | Token ids waiting in the pool, O(1) insert/remove |
| `creator` | Business admin (not the Ownable owner) |
| `feeVault / priceContract` | Pointers to global singletons |

## How this differs from a traditional NFT marketplace

Traditional: NFT contract (asset) + marketplace (listings/matching) + royalty registry.

Flip: the NFT contract **is the market**. `address(this)` holds the NFTs for sale and the ETH reserve lives in the same contract. The marketplace (`Trade`) is only an optional router, not where liquidity lives.

Chinese version: [architecture.zh.md](./architecture.zh.md).
