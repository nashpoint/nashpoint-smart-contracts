#!/usr/bin/env bash
set -euo pipefail

rm -f lcov.info
rm -rf coverage

forge coverage \
  --report lcov \
  --no-match-contract "(EthereumForkTest|ArbitrumForkTest|MorphoVaultForTest|SiloVaultForkTest|EulerVaultForTest|DolomiteForkTest)"

genhtml -o coverage lcov.info \
  --branch-coverage \
  --ignore-errors inconsistent

open coverage/index.html