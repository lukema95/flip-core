English | [中文](./CHANGELOG.zh.md)

# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Core contracts are source-available under BUSL-1.1 and convert to MIT on the
Change Date listed in [licenses/BUSL_LICENSE](./licenses/BUSL_LICENSE). Tag every
release, because the Change Date applies per version.

## [1.0.0] - 2025-10-20

First release of Flip Core.

### Added

- Bonding-curve NFT AMM: `Flip`, `Factory`, `Registry`, `core/BaseNFT`, `core/Storage`, `core/Price` and `core/FeeVault`
- `Trade` periphery for batched and quick trades
- Alternative pricing curves: `LinearPrice` and `FixedIncrementPrice`
- Example collection `FlipNFT` with on-chain SVG art and `Trait`
- ERC-7201 namespaced storage for collection state, with the slot derived from the namespace and asserted in tests
- UUPS-upgradeable collections deployed as `ERC1967Proxy` through `CREATE2`, with deterministic address precomputation
- Split licensing: BUSL-1.1 for the core, MIT for interfaces, periphery, examples, scripts and tests, enforced by `scripts/check-licenses.sh`
- Bilingual documentation (English primary, `*.zh.md` Chinese copies): architecture, modules, flows, FAQ, deployment, security and upgrade guide
- Deployment tooling: `script/Deploy.s.sol` for Foundry plus Hardhat scripts, with a committed `pnpm-lock.yaml`
- Tests: 154 Foundry tests, including fuzz coverage of supply accounting and price monotonicity, at 98%+ line coverage
- CI: license headers, `forge fmt --check`, `forge lint`, size report, tests and coverage, plus solhint, Prettier, `tsc`, `hardhat compile` and a Slither baseline (`slither.config.json`, `--fail-medium`)
- Community health files: SECURITY, CONTRIBUTING, CODE_OF_CONDUCT, MAINTAINERS, issue forms, a pull request template and Dependabot
- `.github/release.yml` grouping generated release notes by label

### Security

- No third-party audit has been performed yet; see [SECURITY.md](./SECURITY.md) for reporting.
