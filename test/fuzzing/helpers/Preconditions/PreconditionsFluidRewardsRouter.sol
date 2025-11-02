// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

contract PreconditionsFluidRewardsRouter is PreconditionsBase {
    function fluidClaimPreconditions(uint256 amountSeed, uint256 positionSeed, uint256 cycleSeed)
        internal
        returns (FluidClaimParams memory params)
    {
        params.cumulativeAmount = fl.clamp(amountSeed, 1e16, 1_000_000e18);
        params.positionId = keccak256(abi.encodePacked(positionSeed, address(node)));
        params.cycle = (cycleSeed % 256) + 1;

        params.merkleProof = new bytes32[](2);
        params.merkleProof[0] = keccak256(abi.encodePacked(amountSeed, positionSeed));
        params.merkleProof[1] = keccak256(abi.encodePacked(cycleSeed, blockhash(block.number - 1)));
        params.proofHash = keccak256(abi.encode(params.merkleProof));
        params.shouldSucceed = true;
    }
}
