// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFluidDistributor} from "../../src/interfaces/external/IFluidDistributor.sol";

contract FluidDistributorMock is IFluidDistributor {
    struct ClaimInfo {
        address recipient;
        uint256 cumulativeAmount;
        uint8 positionType;
        bytes32 positionId;
        uint256 cycle;
        bytes32 proofHash;
    }

    mapping(address => mapping(bytes32 => uint256)) private _claimed;

    ClaimInfo public lastClaimInfo;

    function claimed(address user, bytes32 positionId) external view override returns (uint256) {
        return _claimed[user][positionId];
    }

    function claim(
        address recipient_,
        uint256 cumulativeAmount_,
        uint8 positionType_,
        bytes32 positionId_,
        uint256 cycle_,
        bytes32[] calldata merkleProof_,
        bytes memory /* metadata_ */
    ) external override {
        _claimed[recipient_][positionId_] = cumulativeAmount_;
        lastClaimInfo = ClaimInfo({
            recipient: recipient_,
            cumulativeAmount: cumulativeAmount_,
            positionType: positionType_,
            positionId: positionId_,
            cycle: cycle_,
            proofHash: keccak256(abi.encode(merkleProof_))
        });
    }

    function getClaimed(address user, bytes32 positionId) external view returns (uint256) {
        return _claimed[user][positionId];
    }
}
