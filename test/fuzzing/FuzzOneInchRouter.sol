// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsOneInchRouter.sol";
import "./helpers/postconditions/PostconditionsOneInchRouter.sol";

import {OneInchV6RouterV1} from "../../src/routers/OneInchV6RouterV1.sol";

contract FuzzOneInchRouter is PreconditionsOneInchRouter, PostconditionsOneInchRouter {
    function fuzz_oneInch_swap(uint256 incentiveSeed, uint256 amountSeed, uint256 slippageSeed) public {
        _forceActor(rebalancer, incentiveSeed);
        OneInchSwapParams memory params = oneInchSwapPreconditions(incentiveSeed, amountSeed, slippageSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerOneInch),
            abi.encodeWithSelector(
                OneInchV6RouterV1.swap.selector,
                address(node),
                params.incentive,
                params.incentiveAmount,
                params.minAssetsOut,
                params.executor,
                params.swapCalldata
            ),
            currentActor
        );

        oneInchSwapPostconditions(success, returnData, params);
    }

    function fuzz_oneInch_setIncentiveWhitelist(uint256 seed, bool status) public {
        _forceActor(owner, seed);
        OneInchStatusParams memory params = oneInchSetIncentivePreconditions(seed, status);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerOneInch),
            abi.encodeWithSelector(OneInchV6RouterV1.setIncentiveWhitelistStatus.selector, params.target, params.status),
            currentActor
        );

        oneInchIncentiveStatusPostconditions(success, returnData, params);
    }

    function fuzz_oneInch_setExecutorWhitelist(uint256 seed, bool status) public {
        _forceActor(owner, seed);
        OneInchStatusParams memory params = oneInchSetExecutorPreconditions(seed, status);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerOneInch),
            abi.encodeWithSelector(OneInchV6RouterV1.setExecutorWhitelistStatus.selector, params.target, params.status),
            currentActor
        );

        oneInchExecutorStatusPostconditions(success, returnData, params);
    }
}
