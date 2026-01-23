#!/usr/bin/env bash
set -euo pipefail

rm -f lcov.info
rm -rf coverage

forge coverage \
  --report lcov \
  --no-match-contract "(EthereumForkTest|ArbitrumForkTest|MorphoVaultForTest|SiloVaultForkTest|EulerVaultForTest|DolomiteForkTest)"

lcov --rc branch_coverage=1 \
  --extract lcov.info \
  --include "src/*" \
  -o lcov.info \
  --ignore-errors inconsistent

genhtml -o coverage lcov.info \
  --branch-coverage \
  --ignore-errors inconsistent

open coverage/index.html