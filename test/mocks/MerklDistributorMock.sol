// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMerklDistributor} from "../../src/interfaces/external/IMerklDistributor.sol";

contract MerklDistributorMock is IMerklDistributor {
    address[] internal lastUsers;
    address[] internal lastTokens;
    uint256[] internal lastAmounts;
    bytes32 public lastProofsHash;

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
        lastUsers = users;
        lastTokens = tokens;
        lastAmounts = amounts;
        lastProofsHash = keccak256(abi.encode(proofs));
    }

    function setMerkleTree(bytes32 root, bytes32 ipfsHash) external {
        currentTree = MerkleTree({merkleRoot: root, ipfsHash: ipfsHash});
    }

    function getLastUsers() external view returns (address[] memory) {
        return lastUsers;
    }

    function getLastTokens() external view returns (address[] memory) {
        return lastTokens;
    }

    function getLastAmounts() external view returns (uint256[] memory) {
        return lastAmounts;
    }
}
