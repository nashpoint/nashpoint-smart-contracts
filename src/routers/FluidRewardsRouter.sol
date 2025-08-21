// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {INode} from "src/interfaces/INode.sol";
import {IFluidDistributor} from "src/interfaces/external/IFluidDistributor.sol";
import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract FluidRewardsRouter is ReentrancyGuard, RegistryAccessControl {
    /* IMMUTABLES */
    /// @notice The address of the Fluid Rewards Distributor
    address public immutable distributor;

    /* EVENTS */
    /// @notice Emitted when tokens are claimed from Fluid
    event FluidRewardsClaimed(address indexed node, uint256 cycle, uint256 cumulativeAmount);

    /* CONSTRUCTOR */
    constructor(address registry_, address distributor_) RegistryAccessControl(registry_) {
        if (distributor_ == address(0)) revert ErrorsLib.ZeroAddress();
        distributor = distributor_;
    }

    /* FUNCTIONS */
    /// @notice Claims rewards from FluidDistributor
    /// @param node Node address.
    /// @param cumulativeAmount Total accrued amount of rewards.
    /// @param positionId Position id on Fluid market.
    /// @param cycle Current cycle for claiming on Fluid.
    /// @param merkleProof Array of hashes for the Merkle proof.
    function claim(
        address node,
        uint256 cumulativeAmount,
        bytes32 positionId,
        uint256 cycle,
        bytes32[] calldata merkleProof
    ) external nonReentrant onlyNodeRebalancer(node) {
        INode(node).execute(
            distributor,
            // position type is 1 - lending
            abi.encodeCall(IFluidDistributor.claim, (node, cumulativeAmount, 1, positionId, cycle, merkleProof, ""))
        );
        emit FluidRewardsClaimed(node, cycle, cumulativeAmount);
    }
}
