// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

contract PreconditionsMerklRouter is PreconditionsBase {
    function merklClaimPreconditions(uint256 amountSeed, uint256 proofSeed)
        internal
        returns (MerklClaimParams memory params)
    {
        uint256 len = TOKENS.length == 0 ? 1 : (amountSeed % TOKENS.length) + 1;
        params.tokens = new address[](len);
        params.amounts = new uint256[](len);
        params.proofs = new bytes32[][](len);

        for (uint256 i = 0; i < len; i++) {
            address token = TOKENS.length == 0 ? address(asset) : TOKENS[i % TOKENS.length];
            params.tokens[i] = token;
            params.amounts[i] = fl.clamp(amountSeed + i * 1e16, 1e15, 10_000e18);

            bytes32[] memory proof = new bytes32[](2);
            proof[0] = keccak256(abi.encodePacked(proofSeed, i, token));
            proof[1] = keccak256(abi.encodePacked(amountSeed, blockhash(block.number - 1), i));
            params.proofs[i] = proof;
        }

        address[] memory users = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            users[i] = address(node);
        }

        params.usersHash = keccak256(abi.encode(users));
        params.tokensHash = keccak256(abi.encode(params.tokens));
        params.amountsHash = keccak256(abi.encode(params.amounts));
        params.proofsHash = keccak256(abi.encode(params.proofs));
        params.shouldSucceed = true;

        merklDistributor.setMerkleTree(keccak256(abi.encodePacked(amountSeed, proofSeed)), bytes32(0));
    }
}
