// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IFluidDistributor {
    error Unauthorized();
    error InvalidParams();

    // claim related errors:
    error InvalidCycle();
    error InvalidProof();
    error NothingToClaim();
    error MsgSenderNotRecipient();

    function claimed(address user, bytes32 positionId) external view returns (uint256);

    function claim(
        address recipient_,
        uint256 cumulativeAmount_,
        uint8 positionType_, // type of position, 1 for lending, 2 for vaults, 3 for smart lending, etc
        bytes32 positionId_,
        uint256 cycle_,
        bytes32[] calldata merkleProof_,
        bytes memory metadata_
    ) external;
}
