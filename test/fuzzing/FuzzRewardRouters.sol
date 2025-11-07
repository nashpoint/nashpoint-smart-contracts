// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsRewardRouters.sol";
import "./helpers/postconditions/PostconditionsRewardRouters.sol";

import {FluidRewardsRouter} from "../../src/routers/FluidRewardsRouter.sol";
import {IncentraRouter} from "../../src/routers/IncentraRouter.sol";
import {MerklRouter} from "../../src/routers/MerklRouter.sol";

contract FuzzRewardRouters is PreconditionsRewardRouters, PostconditionsRewardRouters {
    function fuzz_fluid_claimRewards(uint256 positionIdSeed, uint256 cycleSeed, uint256 amountSeed) public {
        forceActor(rebalancer, positionIdSeed);

        FluidClaimParams memory params = fluidClaimPreconditions(positionIdSeed, cycleSeed, amountSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerFluid),
            abi.encodeWithSelector(
                FluidRewardsRouter.claim.selector,
                address(node),
                params.cumulativeAmount,
                params.positionId,
                params.cycle,
                params.merkleProof
            ),
            currentActor
        );

        fluidClaimPostconditions(success, returnData, params);
    }

    function fuzz_incentra_claimRewards(uint256 campaignSeed, uint256 amountSeed) public {
        forceActor(rebalancer, campaignSeed);

        IncentraClaimParams memory params = incentraClaimPreconditions(campaignSeed, amountSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerIncentra),
            abi.encodeWithSelector(IncentraRouter.claim.selector, address(node), params.campaignAddrs, params.rewards),
            currentActor
        );

        incentraClaimPostconditions(success, returnData, params);
    }

    function fuzz_merkl_claimRewards(uint256 amountSeed) public {
        forceActor(rebalancer, amountSeed);

        MerklClaimParams memory params = merklClaimPreconditions(amountSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerMerkl),
            abi.encodeWithSelector(
                MerklRouter.claim.selector, address(node), params.tokens, params.amounts, params.proofs
            ),
            currentActor
        );

        merklClaimPostconditions(success, returnData, params);
    }
}
