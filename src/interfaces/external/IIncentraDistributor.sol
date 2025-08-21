// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IIncentraDistributor {
    struct CampaignReward {
        address campaignAddr;
        uint256[] cumulativeAmounts;
        uint64 epoch;
        bytes32[] proof;
    }

    // // claim all same-chain rewards
    // function claimAll(address earner, address[] calldata campaignAddrs) external;

    // // claim all cross-chain rewards
    // function claimAll(address earner, CampaignReward[] calldata campaignRewards) external;

    // claim all same-chain and cross-chain rewards
    function claimAll(address earner, address[] calldata campaignAddrs, CampaignReward[] calldata campaignRewards)
        external;
}

interface IRewardContract {
    // claim same-chain rewards, send rewards token to earner
    function claim(address earner) external;

    // claim cross-chain rewards, send rewards token to earner
    function claim(address earner, uint256[] calldata cumulativeAmounts, uint64 _epoch, bytes32[] calldata proof)
        external;
}
