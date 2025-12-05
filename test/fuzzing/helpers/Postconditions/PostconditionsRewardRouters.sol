// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {FluidDistributorMock} from "../../../mocks/FluidDistributorMock.sol";
import {IncentraDistributorMock} from "../../../mocks/IncentraDistributorMock.sol";
import {MerklDistributorMock} from "../../../mocks/MerklDistributorMock.sol";

contract PostconditionsRewardRouters is PostconditionsBase {
    function fluidClaimPostconditions(bool success, bytes memory returnData, FluidClaimParams memory params) internal {
        if (success) {
            _after();

            (
                address recipient,
                uint256 cumulativeAmount,
                uint8 positionType,
                bytes32 positionId,
                uint256 cycle,
                bytes32 proofHash
            ) = fluidDistributor.lastClaimInfo();

            invariant_REWARD_FLUID_01(params, recipient);
            invariant_REWARD_FLUID_02(params, cumulativeAmount);
            invariant_REWARD_FLUID_03(params, positionId);
            invariant_REWARD_FLUID_04(params, cycle);
            invariant_REWARD_FLUID_05(params, proofHash);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function incentraClaimPostconditions(bool success, bytes memory returnData, IncentraClaimParams memory params)
        internal
    {
        if (success) {
            _after();

            invariant_REWARD_INCENTRA_01(incentraDistributor.lastEarner());
            invariant_REWARD_INCENTRA_02(params, incentraDistributor.lastCampaignAddrsHash());
            invariant_REWARD_INCENTRA_03(params, incentraDistributor.lastRewardsHash());

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function merklClaimPostconditions(bool success, bytes memory returnData, MerklClaimParams memory params) internal {
        if (success) {
            _after();

            invariant_REWARD_MERKL_01(params, merklDistributor.lastUsersHash());
            invariant_REWARD_MERKL_02(params, merklDistributor.lastTokensHash());
            invariant_REWARD_MERKL_03(params, merklDistributor.lastAmountsHash());
            invariant_REWARD_MERKL_04(params, merklDistributor.lastProofsHash());

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
