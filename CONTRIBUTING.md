English | [中文](./CONTRIBUTING.zh.md)

# Contributing to Flip

Thanks for your interest. This repository contains the contracts layer only.

## Before you start

- **Foundry** is required. CI pins v1.8.5; install the same version with `foundryup -v 1.8.5`.
- **Node.js 20+** is only needed if you want to run the Hardhat deployment scripts.
- Clone with submodules, otherwise `forge build` fails:

```bash
`lib/` 是三个 submodule，锁在以下上游版本。只需要这三个顶层 submodule——
不要用递归克隆，OpenZeppelin 内部的嵌套测试 submodule 会让 Hardhat 的 remapping 解析失败：forge build
forge test
```

## Local checks

Run these before opening a pull request — CI runs the same commands:

```bash
forge fmt --check
forge lint
bash scripts/check-licenses.sh
forge build --sizes
forge test

# Solidity lint, TypeScript formatting and typecheck (needs Node 20+)
pnpm install --frozen-lockfile
pnpm lint
pnpm format:ts:check
pnpm typecheck

# line coverage must stay at or above 98%
bash scripts/check-coverage.sh
```

Static analysis is optional locally and enforced in CI:

```bash
pip install slither-analyzer
slither . --config-file slither.config.json --fail-medium
```

## Licensing of contributions

The repository is split-licensed:

- core contracts (`Factory`, `Flip`, `Registry`, `src/core`, `src/libs`, `src/extensions/bodingcurve`) → BUSL-1.1
- interfaces, periphery, examples and tests → MIT

By submitting a contribution you agree that it is licensed under the license that already applies to the files you modify (inbound = outbound). Do not copy code from another project unless its license is compatible and you preserve the original attribution.

If you add a Solidity file:

- put new core logic under BUSL-1.1 and everything else under MIT
- keep `// SPDX-License-Identifier: ...` on the first line
- add the path to the table in `licenses/README.md`
- run `bash scripts/check-licenses.sh`

The maintainers may adopt a CLA before accepting larger contributions to the core, so that commercial licensing remains possible. If that happens it will be announced in the pull request.

## Workflow

1. Fork the repository and branch from `main`: `feat/<topic>`, `fix/<topic>`, `docs/<topic>`.
2. Keep commits focused. Messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`); breaking changes carry a `!` and a `BREAKING CHANGE:` footer.
3. One concern per pull request, and keep it reviewable.
4. Update tests and documentation in the same pull request.

## Pull request checklist

- [ ] `forge fmt --check` and `forge lint` pass
- [ ] `bash scripts/check-licenses.sh` passes
- [ ] `pnpm lint`, `pnpm format:ts:check` and `pnpm typecheck` pass
- [ ] `forge test` passes and new behavior is covered by tests
- [ ] SPDX headers are correct for every new file
- [ ] documentation is updated in both languages (`docs/x.md` **and** `docs/x.zh.md`, `README.md` **and** `README.zh.md`)
- [ ] no secrets, private keys, RPC URLs or `.env` files are committed
- [ ] the description explains the motivation, the change, and how it was tested

## Code style

- NatSpec on every public/external function, event and custom error
- custom errors instead of revert strings
- state changes before external calls (checks-effects-interactions)
- new storage goes into the ERC-7201 namespace; never reorder fields of `StorageData`
- add tests under the matching `test/` path

## Reporting bugs and vulnerabilities

- bugs and feature requests: open an issue with a minimal reproduction
- security issues: follow [SECURITY.md](./SECURITY.md) and never open a public issue

## Code of conduct

Be respectful and constructive. Harassment, personal attacks and discrimination are not tolerated; maintainers may edit or remove comments and block accounts.

## Questions

Open a discussion or an issue labelled `question`.
