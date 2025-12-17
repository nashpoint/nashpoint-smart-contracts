// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIncentraDistributor} from "../../src/interfaces/external/IIncentraDistributor.sol";

contract IncentraDistributorMock is IIncentraDistributor {
    address public lastEarner;
    bytes32 public lastCampaignAddrsHash;
    bytes32 public lastRewardsHash;

    function claimAll(address earner, address[] calldata campaignAddrs, CampaignReward[] calldata campaignRewards)
        external
        override
    {
        lastEarner = earner;
        lastCampaignAddrsHash = keccak256(abi.encode(campaignAddrs));
        lastRewardsHash = keccak256(abi.encode(campaignRewards));
    }
}
