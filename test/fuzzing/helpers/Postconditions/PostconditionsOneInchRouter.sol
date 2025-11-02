// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregationRouterV6Mock} from "../../../mocks/AggregationRouterV6Mock.sol";

contract PostconditionsOneInchRouter is PostconditionsBase {
    event OneInchSwapObserved(uint256 returnAmount, uint256 feeAmount);

    function oneInchSwapPostconditions(bool success, bytes memory returnData, OneInchSwapParams memory params)
        internal
    {
        if (params.shouldSucceed) {
            // fl.t(success, "1INCH_SWAP_SUCCESS");

            AggregationRouterV6Mock aggregationMock =
                AggregationRouterV6Mock(routerOneInch.ONE_INCH_AGGREGATION_ROUTER_V6());

            uint256 returnAmount = aggregationMock.lastReturnAmount();
            uint256 spentAmount = aggregationMock.lastSpentAmount();
            // fl.eq(spentAmount, params.incentiveAmount, "1INCH_SPENT_AMOUNT");
            // fl.t(returnAmount >= params.minAssetsOut, "1INCH_RETURN_MIN_OUT");

            uint256 nodeAssetAfter = asset.balanceOf(address(node));
            uint256 incentiveBalanceAfter = IERC20(params.incentive).balanceOf(address(node));

            // fl.eq(
            // incentiveBalanceAfter,
            // params.incentiveBalanceBefore - params.incentiveAmount,
            // "1INCH_INCENTIVE_SPENT"
            // );
            // fl.t(
            // nodeAssetAfter >= params.nodeAssetBalanceBefore + returnAmount,
            // "1INCH_ASSET_INCREASE"
            // );

            uint256 feeAmount =
                nodeAssetAfter > params.nodeAssetBalanceBefore ? nodeAssetAfter - params.nodeAssetBalanceBefore : 0;
            emit OneInchSwapObserved(returnAmount, feeAmount);

            vm.prank(rebalancer);
            node.updateTotalAssets();

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "1INCH_SWAP_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function oneInchIncentiveStatusPostconditions(
        bool success,
        bytes memory returnData,
        OneInchStatusParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "1INCH_INCENTIVE_STATUS_SUCCESS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "1INCH_INCENTIVE_STATUS_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function oneInchExecutorStatusPostconditions(
        bool success,
        bytes memory returnData,
        OneInchStatusParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "1INCH_EXECUTOR_STATUS_SUCCESS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "1INCH_EXECUTOR_STATUS_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }
}
