// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {INode} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {IFluidDistributor} from "src/interfaces/external/IFluidDistributor.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract FluidRewardsRouter is ReentrancyGuard {
    /* IMMUTABLES */

    /// @notice The address of the Fluid Rewards Distributor
    address public immutable distributor;

    /// @notice The address of the NodeRegistry
    INodeRegistry public immutable registry;

    /* EVENTS */
    /// @notice Emitted when tokens are claimed from Fluid
    event FluidRewardsClaimed(address indexed node, uint256 cycle, uint256 cumulativeAmount);

    /* CONSTRUCTOR */
    constructor(address registry_, address distributor_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        if (distributor_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
        distributor = distributor_;
    }

    /* MODIFIERS */
    /// @dev Reverts if the caller is not a rebalancer for the node
    modifier onlyNodeRebalancer(address node) {
        if (!registry.isNode(node)) revert ErrorsLib.InvalidNode();
        if (!INode(node).isRebalancer(msg.sender)) revert ErrorsLib.NotRebalancer();
        _;
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
