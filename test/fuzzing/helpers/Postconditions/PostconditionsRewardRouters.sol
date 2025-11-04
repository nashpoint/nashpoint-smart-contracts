// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {FluidDistributorMock} from "../../../mocks/FluidDistributorMock.sol";
import {IncentraDistributorMock} from "../../../mocks/IncentraDistributorMock.sol";
import {MerklDistributorMock} from "../../../mocks/MerklDistributorMock.sol";

contract PostconditionsRewardRouters is PostconditionsBase {
    function fluidClaimPostconditions(bool success, bytes memory returnData, FluidClaimParams memory params) internal {
        if (success && params.shouldSucceed) {
            (
                address recipient,
                uint256 cumulativeAmount,
                uint8 positionType,
                bytes32 positionId,
                uint256 cycle,
                bytes32 proofHash
            ) = fluidDistributor.lastClaimInfo();

            fl.eq(recipient, address(node), "FLUID_CLAIM_RECIPIENT");
            fl.eq(cumulativeAmount, params.cumulativeAmount, "FLUID_CLAIM_AMOUNT");
            fl.t(positionId == params.positionId, "FLUID_CLAIM_POSITION");
            fl.eq(cycle, params.cycle, "FLUID_CLAIM_CYCLE");
            fl.t(proofHash == params.proofHash, "FLUID_CLAIM_PROOF");

            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function incentraClaimPostconditions(bool success, bytes memory returnData, IncentraClaimParams memory params)
        internal
    {
        if (success && params.shouldSucceed) {
            fl.eq(incentraDistributor.lastEarner(), address(node), "INCENTRA_EARNER");
            fl.t(incentraDistributor.lastCampaignAddrsHash() == params.campaignAddrsHash, "INCENTRA_CAMPAIGNS");
            fl.t(incentraDistributor.lastRewardsHash() == params.rewardsHash, "INCENTRA_REWARDS");

            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function merklClaimPostconditions(bool success, bytes memory returnData, MerklClaimParams memory params) internal {
        if (success && params.shouldSucceed) {
            address[] memory users = merklDistributor.getLastUsers();
            address[] memory tokens = merklDistributor.getLastTokens();
            uint256[] memory amounts = merklDistributor.getLastAmounts();

            fl.t(keccak256(abi.encode(users)) == params.usersHash, "MERKL_USERS");
            fl.t(keccak256(abi.encode(tokens)) == params.tokensHash, "MERKL_TOKENS");
            fl.t(keccak256(abi.encode(amounts)) == params.amountsHash, "MERKL_AMOUNTS");
            fl.t(merklDistributor.lastProofsHash() == params.proofsHash, "MERKL_PROOFS");

            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
