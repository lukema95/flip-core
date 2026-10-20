# Licensing

Flip Core is split-licensed: the core AMM is source-available under the Business
Source License 1.1, while interfaces, periphery, examples and tests are MIT.

| Path | License | SPDX identifier |
|------|---------|-----------------|
| `src/Factory.sol`, `src/Flip.sol`, `src/Registry.sol` | Business Source License 1.1 | `BUSL-1.1` |
| `src/core/` | Business Source License 1.1 | `BUSL-1.1` |
| `src/libs/` | Business Source License 1.1 | `BUSL-1.1` |
| `src/extensions/bodingcurve/` | Business Source License 1.1 | `BUSL-1.1` |
| `src/interfaces/` | MIT | `MIT` |
| `src/periphery/` | MIT | `MIT` |
| `src/examples/` | MIT | `MIT` |
| `script/` | MIT | `MIT` |
| `test/` | MIT | `MIT` |
| `scripts/`, `docs/` | MIT | — |
| `lib/` | upstream licenses (`forge-std` MIT/Apache-2.0, OpenZeppelin MIT) | — |

## What BUSL-1.1 means here

- **Non-production use is granted**: reading, auditing, testing, research and
  development are allowed without asking.
- **Production use needs a commercial license**: deploying the core contracts
  (or a derivative) to run an NFT AMM, marketplace or any product competitive
  with Flip requires a license from the Licensor.
- **It expires into MIT**: each version converts to the MIT License on the
  earlier of 2029-06-15 or four years after that version's first public
  distribution. After that date the code is ordinary open source.
- BUSL is **not** an open-source license before the Change Date; describe the
  project as source-available.

## Notes

- `src/examples/` and `test/` are MIT but import the BUSL core, so any
  distributed artifact that includes the core is still subject to BUSL until the
  Change Date.
- The licenses grant no trademark rights. "Flip" is a trademark of Flip
  Contributors.
- `scripts/check-licenses.sh` verifies that every Solidity file's SPDX header
  matches this table; CI runs it on every push and pull request.
