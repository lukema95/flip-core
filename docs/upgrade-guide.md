English | [中文](./upgrade-guide.zh.md)

# Flip Upgrade Guide

## Overview

Collections use OpenZeppelin's UUPS (Universal Upgradeable Proxy Standard) proxy pattern, so implementation logic can be upgraded while the proxy address and state stay unchanged.

## Upgrade architecture

```
users → proxy (fixed address) → implementation V1/V2/V3...
        ↑                       ↑
        |                       |
   never changes           can be upgraded
```

In the current code `Flip` uses OZ `ERC1967Proxy` (deployed by `Factory` with `CREATE2`) plus `UUPSUpgradeable`. Upgrade authority lives in `_authorizeUpgrade`, i.e. the proxy's `owner`.

**Note**: the proxy's `owner` is the `Factory` contract itself (`initialize` calls `__Ownable_init(msg.sender)` and `msg.sender` is Factory). Therefore an EOA **cannot** call `upgradeToAndCall` on the implementation directly; Factory would need a forwarding entry point, which does not exist today.

## Properties

- ✅ **UUPS**: upgrade checks live in the implementation, saving an extra call
- ✅ **ERC-7201 storage**: business state sits in the `flip.storage.Storage` namespace, decoupled from OZ's linear layout
- ✅ **Authorization**: only the owner (Factory) can upgrade
- ✅ **Constant assertion**: `StorageSlotTest` verifies the storage slot matches its namespace

## Storage layout rules

1. `Storage.StorageData` may **only be appended to**; never reorder or retype fields
2. Do not change `STORAGE_LOCATION`; changing it means switching to a different storage
3. Prefer a new namespace for new state instead of stuffing fields into `StorageData`
4. Before upgrading, compare layouts with `forge inspect <Contract> storageLayout`

## Upgrade steps

### 1. Write the new implementation

```solidity
// FlipV2.sol
contract FlipV2 is Flip {
    function version() external pure returns (string memory) {
        return "v2.0.0";
    }
}
```

Put new state in its own ERC-7201 namespace; if a field must go into `StorageData`, append it at the end and update the docs and slot assertion accordingly.

### 2. Verify locally

```bash
forge build
forge test
forge inspect FlipV2 storageLayout
```

### 3. Upgrade (needs a Factory-side entry point)

Because the owner is Factory, an upgrade in practice requires:

1. Deploying the `FlipV2` implementation
2. The protocol owner calling `upgradeToAndCall` on the target proxy through Factory (or a governance entry point added later)
3. This repository does not ship upgrade scripts; deployment scripts are in `scripts/README-deployment.md`

## Upgrade safety checklist

1. **Inheritance**: the new implementation inherits the same `BaseNFT`/`Storage`
2. **Storage layout**: no reordering or retyping of existing fields; `StorageData` is append-only
3. **Slot constant**: `STORAGE_LOCATION` stays the same and the test assertion keeps passing
4. **Authorization**: `_authorizeUpgrade` remains `onlyOwner`
5. **Initializers**: use `reinitializer(n)` for new logic; never call `initialize` twice
6. **Backward compatibility**: existing `IFlip` methods keep their semantics
7. **Events**: emit events for new state changes
8. **Tests**: cover the new paths and keep `forge test` green

## FAQ

### Q: Does an upgrade lose existing data?

No. Only logic changes; NFT ownership, balances and pooled token ids all live in the proxy's storage.

### Q: Does the contract address change after an upgrade?

No. The proxy address is fixed. `Factory.calculateFlipAddress` only predicts addresses of new collections and is unrelated to upgrades.

### Q: How do I roll back?

Deploy the previous implementation and upgrade the proxy to it again. Make sure state written between the two upgrades is compatible with the older logic.

### Q: How is upgrade authority managed?

The owner is `Factory`. For production, hand Factory's owner to a multisig / Timelock and publish the new implementation code before upgrading.

## Best practices

1. **Test first**: validate fully on a testnet
2. **Compare layouts**: run `forge inspect` before upgrading
3. **Keep versions**: retain the source of every historical implementation for rollbacks
4. **Sync docs**: update the slot and field tables in `docs/architecture.md` together
5. **Notify users**: announce upgrade plans and the new implementation address in advance

Chinese version: [upgrade-guide.zh.md](./upgrade-guide.zh.md).
