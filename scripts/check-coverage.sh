#!/usr/bin/env bash
# Fails when line coverage drops below the configured threshold.
#
# Gas assertions are excluded because coverage instrumentation inflates gas usage;
# they are still enforced by `forge test`.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

THRESHOLD="${COVERAGE_THRESHOLD:-98}"

forge coverage --report lcov --report-file lcov.info --no-match-test "test_gas_" >/dev/null

python3 - "$THRESHOLD" <<'PY'
import pathlib
import sys

threshold = float(sys.argv[1])
hit = total = 0
for line in pathlib.Path("lcov.info").read_text().splitlines():
    if line.startswith("LH:"):
        hit += int(line[3:])
    elif line.startswith("LF:"):
        total += int(line[3:])

if total == 0:
    print("no coverage data found in lcov.info")
    sys.exit(1)

percent = hit / total * 100
print(f"line coverage: {hit}/{total} = {percent:.2f}% (threshold {threshold:.0f}%)")
if percent < threshold:
    print("coverage is below the threshold")
    sys.exit(1)
PY
