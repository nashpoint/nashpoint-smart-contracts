// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsFluidRewardsRouter.sol";
import "./helpers/postconditions/PostconditionsFluidRewardsRouter.sol";

import {FluidRewardsRouter} from "../../src/routers/FluidRewardsRouter.sol";

contract FuzzFluidRewardsRouter is PreconditionsFluidRewardsRouter, PostconditionsFluidRewardsRouter {
    function fuzz_fluid_claim(uint256 amountSeed, uint256 positionSeed, uint256 cycleSeed) public {
        _forceActor(rebalancer, amountSeed);
        FluidClaimParams memory params = fluidClaimPreconditions(amountSeed, positionSeed, cycleSeed);

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
}
