English | [中文](./MAINTAINERS.zh.md)

# Maintainers

| Maintainer | GitHub | Areas |
|---|---|---|
| lukema95 | [@lukema95](https://github.com/lukema95) | contracts, tooling, releases |

## Responsibilities

- review and merge pull requests
- keep CI green and the `main` branch releasable
- tag releases and update [CHANGELOG.md](./CHANGELOG.md)
- coordinate security reports per [SECURITY.md](./SECURITY.md)
- hold and rotate deployment keys and the `FeeVault.admin` role (preferably behind a multisig)

## Becoming a maintainer

Contributors with a consistent track record of high-quality pull requests and reviews can be nominated by an existing maintainer. Nomination is announced in an issue; if no maintainer objects within seven days, the nominee is added to this file.

## Decision making

Day-to-day changes are decided in pull requests by rough consensus of the maintainers. Changes to the license, the token model or a deployed contract's ABI/storage layout require explicit agreement from all maintainers and a note in the pull request.

## Escalation

If a maintainer is unreachable for more than 30 days on a security matter, any other maintainer may act on the report. If a maintainer's account or keys are suspected to be compromised, rotate `FeeVault.admin` and any deployment keys first, then announce.
