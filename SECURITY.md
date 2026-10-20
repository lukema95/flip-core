English | [中文](./SECURITY.zh.md)

# Security Policy

## Supported versions

Only the latest release on the `main` branch is supported with security fixes. Older releases are archived as-is; because core contracts are deployed immutably to public chains, a fix usually means a new deployment rather than an in-place patch.

## Reporting a vulnerability

**Please do not open a public issue, pull request or discussion for a suspected vulnerability.**

Preferred channel: GitHub private vulnerability reporting.
Go to the repository's **Security** tab → **Report a vulnerability**. This creates a private advisory visible only to you and the maintainers.

If you cannot use that channel, contact the maintainer [@lukema95](https://github.com/lukema95) on GitHub to arrange a private channel.

Please include:

- affected contract and function, with the source path and, if possible, a git commit
- a description of the issue and its impact (fund loss, denial of service, privilege escalation, ...)
- reproduction steps, a PoC contract or a Foundry test if you have one
- whether the issue is already public anywhere

## What to expect

| Stage | Target |
|---|---|
| Acknowledgement of the report | within 3 business days |
| Initial triage and severity assessment | within 7 business days |
| Fix or mitigation plan | depends on severity; communicated after triage |
| Public disclosure | coordinated, normally 90 days after the report or after a fix ships, whichever is earlier |

There is no bug bounty at this time. We will credit reporters in the advisory and release notes unless you prefer to stay anonymous.

## Scope

In scope — the Solidity sources in this repository:

- `src/Flip.sol`, `src/Factory.sol`, `src/Registry.sol`
- `src/core/` (ERC-721 base, ERC-7201 storage, pricing, fee vault)
- `src/periphery/`
- `src/libs/`
- `src/extensions/bodingcurve/`

Out of scope:

- third-party dependencies under `lib/` (report those upstream: OpenZeppelin, forge-std)
- deployed protocol instances and their front ends, unless the issue is caused by a bug in this source
- gas optimisation suggestions with no security impact, missing events, style issues
- issues that require a compromised owner key, a malicious creator, or a compromised user device

## Known design properties

These are intentional, not vulnerabilities:

- collections are upgradeable (UUPS) and the upgrade authority is the `Factory`; a compromised Factory owner can upgrade a collection
- fees are paid immediately, so a creator that cannot receive ETH blocks `sell` for its collection
- `Registry` accepts any contract that implements `IFlip` (no access control)
- the price curve ignores individual token rarity

See `docs/faq.md` for the reasoning behind each of these.

## Safe harbour

We will not pursue legal action against researchers who:

- act in good faith and only use their own accounts and funds
- avoid privacy violations, data destruction and service disruption
- give us reasonable time to fix the issue before publishing
- do not exploit the issue beyond what is needed to demonstrate it

## License note

Reporting a vulnerability is welcome regardless of the license: core contracts are source-available under the Business Source License 1.1 and the rest is MIT. Security research, auditing and testing are explicitly granted uses.
