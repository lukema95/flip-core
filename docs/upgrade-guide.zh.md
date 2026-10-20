[English](./upgrade-guide.md) | 中文

# Flip 合约升级指南

## 概述

集合合约使用 OpenZeppelin 的 UUPS（Universal Upgradeable Proxy Standard）代理模式，在保持代理地址与状态不变的前提下升级实现逻辑。

## 升级架构

```
用户 → 代理合约(固定地址) → 实现合约 V1/V2/V3...
     ↑                    ↑
     |                    |
  永不改变              可以升级
```

当前实现里 `Flip` 用的是 OZ `ERC1967Proxy`（由 `Factory` 用 `CREATE2` 部署）+ `UUPSUpgradeable`，升级权限在 `_authorizeUpgrade`，即代理的 `owner`。

**注意**：代理的 `owner` 是 `Factory` 合约本身（`initialize` 里 `__Ownable_init(msg.sender)`，而 `msg.sender` 是 Factory）。因此本仓库里的实现合约 **不能** 由 EOA 直接调用 `upgradeToAndCall`，需要 Factory 增加一个转发入口（当前没有）。

## 核心特性

- ✅ **UUPS 模式**：升级校验在实现合约内，省一次额外调用
- ✅ **ERC-7201 存储**：业务状态放在 `flip.storage.Storage` 命名空间，与 OZ 的线性布局解耦
- ✅ **权限控制**：只有 owner（Factory）可以升级
- ✅ **常量断言**：`StorageSlotTest` 校验存储槽与 namespace 一致

## 存储布局规则

1. `Storage.StorageData` **只能追加字段**，不能改顺序或类型
2. 不要修改 `STORAGE_LOCATION` 常量；改了等于换了一套存储
3. 新增独立状态优先再开一个新 namespace，而不是塞进 `StorageData`
4. 升级前用 `forge inspect <Contract> storageLayout` 对比新旧布局

## 升级步骤

### 1. 写新实现

```solidity
// FlipV2.sol
contract FlipV2 is Flip {
    function version() external pure returns (string memory) {
        return "v2.0.0";
    }
}
```

新增状态请走新的 ERC-7201 namespace；若必须放进 `StorageData`，只能追加到最后并同步更新文档与 slot 断言。

### 2. 本地验证

```bash
forge build
forge test
forge inspect FlipV2 storageLayout
```

### 3. 升级（需要 Factory 侧入口）

由于 owner 是 Factory，实际升级时需要：

1. 部署 `FlipV2` 实现
2. 由协议方通过 Factory（或后续新增的治理入口）对目标代理执行 `upgradeToAndCall`
3. 本仓库当前不包含升级脚本；部署脚本见 `scripts/README-deployment.md`

## 升级安全检查清单

1. **继承关系**：新实现继承自同一 `BaseNFT`/`Storage`
2. **存储布局**：不改变已有字段顺序与类型；`StorageData` 只追加
3. **slot 常量**：`STORAGE_LOCATION` 不变，测试里的断言保持通过
4. **升级权限**：`_authorizeUpgrade` 仍为 `onlyOwner`
5. **初始化器**：新逻辑用 `reinitializer(n)`，不要重复调用 `initialize`
6. **向后兼容**：现有 `IFlip` 方法语义不变
7. **事件**：新增状态变更尽量补事件
8. **测试**：新增路径要有测试，`forge test` 全绿

## 常见问题

### Q: 升级后原有数据会丢失吗？

不会。升级只改变逻辑，NFT 所有权、余额、池内 tokenId 都存在代理的存储里。

### Q: 升级后合约地址会改变吗？

不会。代理地址不变；`Factory.calculateFlipAddress` 只用于预测新集合地址，与升级无关。

### Q: 如何回滚？

部署旧实现并对代理再次执行升级即可，但要注意两次升级之间的状态写入是否与新逻辑兼容。

### Q: 升级权限如何管理？

当前 owner 是 `Factory`。生产环境建议把 Factory 的 owner 交给多签 / Timelock，并在升级前公开新实现代码。

## 最佳实践

1. **测试先行**：先在测试网完整验证
2. **布局对比**：升级前用 `forge inspect` 比对 storage layout
3. **保留版本**：保留历史实现源码以备回滚
4. **文档同步**：`docs/architecture.zh.md` 里的 slot 与字段表要一起更新
5. **社区通知**：提前公布升级计划与新实现地址

英文版：[upgrade-guide.md](./upgrade-guide.md)。
