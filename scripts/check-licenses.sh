#!/usr/bin/env bash
# Verifies that every Solidity file carries the SPDX identifier required by
# licenses/README.md, and that the license files are present and consistent.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

status=0

for required in LICENSE licenses/BUSL_LICENSE licenses/MIT_LICENSE licenses/README.md; do
  if [[ ! -f "$required" ]]; then
    printf 'missing %s\n' "$required"
    status=1
  fi
done

while IFS= read -r file; do
  case "$file" in
    src/Flip.sol|src/Factory.sol|src/Registry.sol|src/core/*.sol|src/libs/*.sol|src/extensions/bodingcurve/*.sol)
      expected="BUSL-1.1"
      ;;
    src/interfaces/*.sol|src/interfaces/core/*.sol|src/interfaces/periphery/*.sol|src/periphery/*.sol|src/examples/*.sol|script/*.sol|test/*.sol|test/*/*.sol)
      expected="MIT"
      ;;
    *)
      printf 'unclassified Solidity file: %s\n' "$file"
      status=1
      continue
      ;;
  esac

  actual="$(sed -n 's|^// SPDX-License-Identifier: \(.*\)$|\1|p' "$file" | head -n1)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'SPDX mismatch: %s (expected %s, found %s)\n' "$file" "$expected" "${actual:-none}"
    status=1
  fi
done < <(find src script test -name '*.sol' | sort)

if ! grep -q 'Change License:       MIT License' licenses/BUSL_LICENSE; then
  echo 'licenses/BUSL_LICENSE must convert to the MIT License'
  status=1
fi

if (( status )); then
  echo 'license check failed'
  exit 1
fi

echo 'license check passed'
