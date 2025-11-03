#!/bin/bash
# Patch Optimism library imports for Echidna compatibility

# Patch MerkleTrie.sol
sed -i.bak 's|import { Bytes } from "src/libraries/Bytes.sol";|import { Bytes } from "../Bytes.sol";|g' \
    lib/optimism/packages/contracts-bedrock/src/libraries/trie/MerkleTrie.sol

sed -i.bak 's|import { RLPReader } from "src/libraries/rlp/RLPReader.sol";|import { RLPReader } from "../rlp/RLPReader.sol";|g' \
    lib/optimism/packages/contracts-bedrock/src/libraries/trie/MerkleTrie.sol

# Patch SecureMerkleTrie.sol
sed -i.bak 's|import { MerkleTrie } from "src/libraries/trie/MerkleTrie.sol";|import { MerkleTrie } from "./MerkleTrie.sol";|g' \
    lib/optimism/packages/contracts-bedrock/src/libraries/trie/SecureMerkleTrie.sol

# Patch RLPReader.sol
sed -i.bak 's|import { Bytes } from "src/libraries/Bytes.sol";|import { Bytes } from "../Bytes.sol";|g' \
    lib/optimism/packages/contracts-bedrock/src/libraries/rlp/RLPReader.sol

echo "Optimism library patches applied successfully!"
