// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {IIncentraDistributor} from "../../../../src/interfaces/external/IIncentraDistributor.sol";

contract PreconditionsIncentraRouter is PreconditionsBase {
    function incentraClaimPreconditions(uint256 amountSeed, uint256 epochSeed, uint256 proofSeed)
        internal
        returns (IncentraClaimParams memory params)
    {
        uint256 len = COMPONENTS.length == 0 ? 1 : (amountSeed % COMPONENTS.length) + 1;
        params.campaignAddrs = new address[](len);
        params.rewards = new IIncentraDistributor.CampaignReward[](len);

        for (uint256 i = 0; i < len; i++) {
            address campaign = COMPONENTS.length == 0 ? address(node) : COMPONENTS[i % COMPONENTS.length];
            params.campaignAddrs[i] = campaign;

            uint256 amountsLen = (proofSeed % 2) + 1;
            uint256[] memory cumulativeAmounts = new uint256[](amountsLen);
            bytes32[] memory proof = new bytes32[](amountsLen);

            for (uint256 j = 0; j < amountsLen; j++) {
                cumulativeAmounts[j] = fl.clamp(amountSeed + j * 1e16, 1e16, 1_000_000e18);
                proof[j] = keccak256(abi.encodePacked(proofSeed, i, j));
            }

            params.rewards[i] = IIncentraDistributor.CampaignReward({
                campaignAddr: campaign,
                cumulativeAmounts: cumulativeAmounts,
                epoch: uint64((epochSeed + i) % 1000 + 1),
                proof: proof
            });
        }

        params.campaignAddrsHash = keccak256(abi.encode(params.campaignAddrs));
        params.rewardsHash = keccak256(abi.encode(params.rewards));
        params.shouldSucceed = true;
    }
}
