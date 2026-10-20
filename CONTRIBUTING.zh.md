[English](./CONTRIBUTING.md) | 中文

# 为 Flip 贡献代码

感谢关注。本仓库只包含合约层。

## 开始之前

- 需要 **Foundry**。CI 固定使用 v1.8.5，请用 `foundryup -v 1.8.5` 安装同一版本。
- 只有运行 Hardhat 部署脚本时才需要 **Node.js 20+**。
- 克隆时必须带 submodule，否则 `forge build` 会失败：

```bash
`lib/` 是三个 submodule，锁在以下上游版本。只需要这三个顶层 submodule——
不要用递归克隆，OpenZeppelin 内部的嵌套测试 submodule 会让 Hardhat 的 remapping 解析失败：forge build
forge test
```

## 本地检查

提交 PR 前请执行——CI 跑的是同一套命令：

```bash
forge fmt --check
forge lint
bash scripts/check-licenses.sh
forge build --sizes
forge test

# Solidity lint、TypeScript 格式与类型检查（需要 Node 20+）
pnpm install --frozen-lockfile
pnpm lint
pnpm format:ts:check
pnpm typecheck

# 行覆盖率必须保持在 98% 以上
bash scripts/check-coverage.sh
```

静态分析在本地可选、在 CI 强制：

```bash
pip install slither-analyzer
slither . --config-file slither.config.json --fail-medium
```

## 贡献的许可

仓库采用分层许可：

- 核心合约（`Factory`、`Flip`、`Registry`、`src/core`、`src/libs`、`src/extensions/bodingcurve`）→ BUSL-1.1
- 接口、外围、示例与测试 → MIT

提交贡献即表示你同意该贡献按所修改文件已有的许可授权（inbound = outbound）。请不要拷贝其他项目的代码，除非其许可兼容且保留原始署名。

新增 Solidity 文件时：

- 新的核心逻辑用 BUSL-1.1，其余用 MIT
- 第一行保留 `// SPDX-License-Identifier: ...`
- 把路径补进 `licenses/README.md` 的对照表
- 运行 `bash scripts/check-licenses.sh`

对于较大的核心代码贡献，维护者可能先引入 CLA，以保证商业授权链条完整；届时会在 PR 中说明。

## 工作流

1. Fork 仓库并从 `main` 切分支：`feat/<topic>`、`fix/<topic>`、`docs/<topic>`。
2. 提交保持聚焦。提交信息遵循 Conventional Commits（`feat:`、`fix:`、`docs:`、`refactor:`、`test:`、`chore:`）；破坏性变更用 `!` 并在正文写 `BREAKING CHANGE:`。
3. 一个 PR 只做一件事，保持可评审。
4. 测试与文档在同一个 PR 内更新。

## PR 检查清单

- [ ] `forge fmt --check` 与 `forge lint` 通过
- [ ] `bash scripts/check-licenses.sh` 通过
- [ ] `pnpm lint`、`pnpm format:ts:check`、`pnpm typecheck` 通过
- [ ] `forge test` 通过，且新行为有测试覆盖
- [ ] 所有新文件的 SPDX 头正确
- [ ] 文档中英同步（`docs/x.md` **与** `docs/x.zh.md`、`README.md` **与** `README.zh.md`）
- [ ] 未提交任何密钥、私钥、RPC 地址或 `.env`
- [ ] PR 描述说明了动机、改动与验证方式

## 代码风格

- 每个 public/external 函数、事件、自定义错误都要有 NatSpec
- 用自定义 error，不用 revert 字符串
- 先改状态再外部调用（checks-effects-interactions）
- 新状态放进 ERC-7201 命名空间；不要调整 `StorageData` 字段顺序
- 测试放在对应的 `test/` 路径下

## 问题与漏洞

- bug 与功能建议：开 issue，附最小复现
- 安全问题：按 [SECURITY.zh.md](./SECURITY.zh.md) 处理，绝不要开公开 issue

## 行为准则

保持尊重与建设性。不接受骚扰、人身攻击与歧视；维护者可以编辑或删除评论、封禁账号。

## 提问

开 discussion，或用 `question` 标签的 issue。
