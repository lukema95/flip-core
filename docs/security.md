English | [中文](./security.zh.md)

# Security Model

This document describes who can do what, where the money lives, what the code
assumes, and which known limitations exist. It complements
[SECURITY.md](../SECURITY.md), which covers how to report an issue.

## Status

- **Not audited.** No third-party audit has been performed at the time of writing.
- Contracts are **source-available** under BUSL-1.1 (core) and MIT (interfaces,
  periphery, examples, tests). Being able to read the code is not a substitute
  for an audit.

## Actors and powers

| Actor | Is | Can |
|---|---|---|
| Collection `owner` | the `Factory` contract | upgrade the collection implementation (UUPS `_authorizeUpgrade`) |
| `creator` | the account that called `Factory.createFlip` | receive 80% of fees, change `baseURI`, transfer the creator role |
| `FeeVault.admin` | the FeeVault deployer, or whoever it was handed to | withdraw protocol fees, change admin |
| Anyone | any account | create a collection, `mint` / `buy` / `sell`, register in `Registry` |

There is no pause switch, no allowlist and no role hierarchy. `creator` is a
business role inside `Storage`; it is **not** the Ownable owner.

## Upgrade authority

Collections are `ERC1967Proxy` instances owned by `Factory`. Because
`Factory` itself has no function that calls `upgradeToAndCall`, a collection
cannot be upgraded today without extending `Factory` (or the owner of the proxy).
Treat deployed collections as **effectively immutable** until such an entry point
is added deliberately.

If an upgrade entry point is added, the owner of every collection is a single
contract, so compromise of `Factory` ownership compromises every collection at
once. Hand `Factory` ownership to a multisig or Timelock first.

## Where the money is

Each collection holds its own ETH reserve; `FeeVault` holds protocol fees. There
is no shared pool across collections and `Factory` never holds funds.

Flow of a `mint` or `buy` of price `P` with fee `F = P * creatorFeePercent`:

```
user pays P + F
  P      stays in the collection (curve reserve)
  F      80% -> creator(), 20% -> FeeVault
```

`sell` reverses it: the collection pays the seller `P - F` out of the reserve and
sends the same 80/20 split of `F`.

## Invariants

- `totalSupply() == currentSupply() + pooled tokens`
- the ETH reserve only grows through `mint` / `buy` and shrinks through `sell`
- `currentSupply` changes in exactly one direction per operation
- a token in the pool has `ownerOf(tokenId) == address(collection)`

`test/FlipInvariants.t.sol` fuzzes the first invariant and price monotonicity.

## Known limitations

These are accepted limitations, not undisclosed bugs. Fixing any of them is a
consensus-level change for a deployed collection, so they are listed here to make
the trade-offs explicit.

1. **Pool membership is inferred from ownership.** `buy` checks
   `ownerOf(tokenId) == address(this)` and then removes the token using
   `tokenIndex[tokenId]` without verifying membership. If someone transfers an NFT
   directly into a collection (`safeTransferFrom` to the contract), the pool and
   its index can diverge, and a later `buy` of that token can revert or corrupt
   `availableTokens`. Do not send NFTs to a collection except through `sell`.
   Recommended fix: track an explicit `isPooled[tokenId]` flag, or require
   `availableTokens[tokenIndex[tokenId]] == tokenId` in `buy`.
2. **Fees are paid immediately.** A `creator` that cannot receive ETH (a contract
   without `receive`, or a reverting fallback) makes `mint`, `buy` and `sell`
   revert for that collection. There is no accrued-pending fallback.
3. **No reentrancy guard.** State is updated before external calls, which blocks
   the classic reentrancy, but there is no `ReentrancyGuard` and no pause switch.
   Batch functions in `Trade` make repeated external calls.
4. **`Registry` is permissionless.** Any contract implementing `IFlip` can
   register. Treat Factory's `FlipCreated` event as the source of truth for
   discovery.
5. **Pricing ignores rarity.** Every token in a collection trades at the same
   curve price; there is no per-token pricing.
6. **The curve is fixed per collection.** `Storage` exposes no setter for
   `priceContract`, `initialPrice` or `maxSupply`, so they cannot be changed after
   creation without an upgrade.

## Operational assumptions

- deployer keys and `FeeVault.admin` should be held by a multisig
- `Factory` ownership should be a multisig or Timelock before any upgrade entry point is added
- front ends must read collection addresses from `Factory` events rather than from `Registry` alone
- monitor `FeeVault` balance and the reserve of high-volume collections

## Out of scope

- front ends, subgraphs, deployment infrastructure
- third-party dependencies under `lib/` (OpenZeppelin, forge-std)
- economic/oracle risks that do not originate from this code

## Reporting

Follow [SECURITY.md](../SECURITY.md). Please do not open a public issue.

## Static analysis

CI runs [Slither](https://github.com/crytic/slither) with `slither.config.json` and
`--fail-medium`, so a new high or medium finding fails the build. The baseline
excludes five detectors that were reviewed and accepted:

| Detector | Why it is accepted |
|---|---|
| `arbitrary-send-eth` | `Flip.sell` pays the seller, and `Trade` forwards the caller's ETH to the collection the caller chose — both are the intended behaviour of a marketplace and a router |
| `weak-prng` | Only used by `Trait` to pick art shapes; no funds or access control depend on it |
| `reentrancy-eth` | `Flip` follows checks-effects-interactions (state is updated before paying out); a reentrant call can only act on tokens the caller already owns. No `ReentrancyGuard` is present — tracked as hardening work |
| `incorrect-equality` | Strict equality on `seed % 5` in the art generator is a switch, not a balance check |
| `uninitialized-local` | Solidity zero-initializes memory; the flagged structs and strings have every field assigned immediately |

Anything outside this baseline is treated as a regression.
