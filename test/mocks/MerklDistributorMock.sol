// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMerklDistributor} from "../../src/interfaces/external/IMerklDistributor.sol";

contract MerklDistributorMock is IMerklDistributor {
    bytes32 internal constant USERS_SLOT = keccak256("merkl.mock.users.hash");
    bytes32 internal constant TOKENS_SLOT = keccak256("merkl.mock.tokens.hash");
    bytes32 internal constant AMOUNTS_SLOT = keccak256("merkl.mock.amounts.hash");
    bytes32 internal constant PROOFS_SLOT = keccak256("merkl.mock.proofs.hash");

    MerkleTree internal currentTree;

    function tree() external view override returns (MerkleTree memory) {
        return currentTree;
    }

    function getMerkleRoot() external view override returns (bytes32) {
        return currentTree.merkleRoot;
    }

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external override {
        _writeSlot(USERS_SLOT, keccak256(abi.encode(users)));
        _writeSlot(TOKENS_SLOT, keccak256(abi.encode(tokens)));
        _writeSlot(AMOUNTS_SLOT, keccak256(abi.encode(amounts)));
        _writeSlot(PROOFS_SLOT, keccak256(abi.encode(proofs)));
    }

    function setMerkleTree(bytes32 root, bytes32 ipfsHash) external {
        currentTree = MerkleTree({merkleRoot: root, ipfsHash: ipfsHash});
    }

    function lastUsersHash() external view returns (bytes32) {
        return _readSlot(USERS_SLOT);
    }

    function lastTokensHash() external view returns (bytes32) {
        return _readSlot(TOKENS_SLOT);
    }

    function lastAmountsHash() external view returns (bytes32) {
        return _readSlot(AMOUNTS_SLOT);
    }

    function lastProofsHash() external view returns (bytes32) {
        return _readSlot(PROOFS_SLOT);
    }

    function _writeSlot(bytes32 slot, bytes32 value) internal {
        assembly {
            sstore(slot, value)
        }
    }

    function _readSlot(bytes32 slot) internal view returns (bytes32 value) {
        assembly {
            value := sload(slot)
        }
    }
}
