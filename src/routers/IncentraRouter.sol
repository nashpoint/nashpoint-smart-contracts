// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {INode} from "src/interfaces/INode.sol";
import {IIncentraDistributor} from "src/interfaces/external/IIncentraDistributor.sol";
import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract IncentraRouter is ReentrancyGuard, RegistryAccessControl {
    /* IMMUTABLES */
    /// @notice The address of the Incentra Distributor
    address public immutable distributor;

    /* EVENTS */
    /// @notice Emitted when tokens are claimed on Incentra
    event IncentraRewardsClaimed(address indexed node);

    /* CONSTRUCTOR */
    constructor(address registry_, address distributor_) RegistryAccessControl(registry_) {
        if (distributor_ == address(0)) revert ErrorsLib.ZeroAddress();
        distributor = distributor_;
    }

    /* FUNCTIONS */
    /// @notice Claims rewards from Incentra
    function claim(
        address node,
        address[] calldata campaignAddrs,
        IIncentraDistributor.CampaignReward[] calldata campaignRewards
    ) external nonReentrant onlyNodeRebalancer(node) {
        INode(node).execute(
            distributor, abi.encodeCall(IIncentraDistributor.claimAll, (node, campaignAddrs, campaignRewards))
        );
        emit IncentraRewardsClaimed(node);
    }
}
