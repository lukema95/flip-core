[English](./CHANGELOG.md) | 中文

# 变更记录

本文件记录项目的重要变更。格式参考 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)。

核心合约以 BUSL-1.1 提供 source-available 授权，并在 [licenses/BUSL_LICENSE](./licenses/BUSL_LICENSE) 载明的 Change Date 转为 MIT；由于 Change Date 按版本计算，每次发布都需要打 tag。

## [1.0.0] - 2025-10-20

Flip Core 首次发布。

### 新增

- Bonding Curve NFT AMM：`Flip`、`Factory`、`Registry`、`core/BaseNFT`、`core/Storage`、`core/Price`、`core/FeeVault`
- 外围路由 `Trade`，支持批量与快捷交易
- 备选定价曲线：`LinearPrice`、`FixedIncrementPrice`
- 示例集合 `FlipNFT`，含链上 SVG 与 `Trait`
- 集合状态使用 ERC-7201 命名空间存储，槽位由命名空间推导并有测试断言
- 集合以 `ERC1967Proxy` 形式通过 `CREATE2` 部署，支持确定性地址预计算，并支持 UUPS 升级
- 分层许可：核心 BUSL-1.1，接口/外围/示例/脚本/测试 MIT，由 `scripts/check-licenses.sh` 校验
- 双语文档（英文为主，`*.zh.md` 为中文副本）：架构、模块、流程、FAQ、部署、安全与升级指南
- 部署工具：Foundry 的 `script/Deploy.s.sol` 与 Hardhat 脚本，并提交 `pnpm-lock.yaml`
- 测试：154 个 Foundry 测试，含供给守恒与价格单调性的 fuzz 覆盖，行覆盖率 98%+
- CI：license 头检查、`forge fmt --check`、`forge lint`、合约尺寸报告、测试与覆盖率，以及 solhint、Prettier、`tsc`、`hardhat compile` 与 Slither 基线（`slither.config.json`、`--fail-medium`）
- 社区文件：SECURITY、CONTRIBUTING、CODE_OF_CONDUCT、MAINTAINERS、issue 表单、PR 模板与 Dependabot
- `.github/release.yml`，按 label 分组生成 Release Notes

### 安全

- 尚未进行第三方审计。报告渠道见 [SECURITY.zh.md](./SECURITY.zh.md)。
