[English](./MAINTAINERS.md) | 中文

# 维护者

| 维护者 | GitHub | 负责范围 |
|---|---|---|
| lukema95 | [@lukema95](https://github.com/lukema95) | 合约、工具链、发布 |

## 职责

- 评审并合并 PR
- 保持 CI 绿色，保证 `main` 随时可发布
- 打版本 tag 并更新 [CHANGELOG.zh.md](./CHANGELOG.zh.md)
- 按 [SECURITY.zh.md](./SECURITY.zh.md) 协调安全报告
- 保管与轮换部署私钥及 `FeeVault.admin` 角色（建议放在多签背后）

## 如何成为维护者

持续提交高质量 PR 与评审的贡献者可由现有维护者提名。提名在 issue 中公示；7 天内无人反对即加入本文件。

## 决策方式

日常变更在 PR 中由维护者达成粗略共识决定。涉及许可证、代币模型，或已部署合约 ABI/存储布局的变更，需要全部维护者明确同意，并在 PR 中注明。

## 升级处理

若某位维护者在安全事务上超过 30 天不可达，其他维护者可直接处理该报告。若怀疑某维护者账号或私钥被攻破，先轮换 `FeeVault.admin` 与所有部署私钥，再对外公告。
