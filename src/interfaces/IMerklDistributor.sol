// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IMerklDistributor {
    struct MerkleTree {
        bytes32 merkleRoot;
        bytes32 ipfsHash;
    }

    function tree() external view returns (MerkleTree memory);

    function getMerkleRoot() external view returns (bytes32);

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}
