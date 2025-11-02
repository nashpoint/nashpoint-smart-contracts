// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {IncentraDistributorMock} from "../../../mocks/IncentraDistributorMock.sol";

contract PostconditionsIncentraRouter is PostconditionsBase {
    function incentraClaimPostconditions(bool success, bytes memory returnData, IncentraClaimParams memory params)
        internal
    {
        if (params.shouldSucceed) {
            // fl.t(success, "INCENTRA_CLAIM_SUCCESS");
            // fl.eq(IncentraDistributorMock(address(incentraDistributor)).lastEarner(), address(node), "INCENTRA_EARNER");
            // fl.t(
            // IncentraDistributorMock(address(incentraDistributor)).lastCampaignAddrsHash()
            // == params.campaignAddrsHash,
            // "INCENTRA_CAMPAIGNS"
            // );
            // fl.t(
            // IncentraDistributorMock(address(incentraDistributor)).lastRewardsHash()
            // == params.rewardsHash,
            // "INCENTRA_REWARDS"
            // );
            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "INCENTRA_CLAIM_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }
}
