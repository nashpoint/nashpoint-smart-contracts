// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {ERC4626Router} from "../../../../src/routers/ERC4626Router.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PostconditionsERC4626Router is PostconditionsBase {
    function router4626InvestPostconditions(
        bool success,
        bytes memory returnData,
        RouterInvestParams memory params,
        address[] memory actors
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER4626_INVEST_SHOULD_SUCCEED");
            uint256 depositAmount = abi.decode(returnData, (uint256));
            // fl.t(depositAmount > 0, "ROUTER4626_INVEST_ZERO_DEPOSIT");

            _after(actors);

            uint256 nodeAssetAfter = asset.balanceOf(address(node));
            uint256 sharesAfter = IERC20(params.component).balanceOf(address(node));

            // fl.t(nodeAssetAfter <= params.nodeAssetBalanceBefore, "ROUTER4626_INVEST_ASSET_INCREASE");
            // fl.t(
            // params.nodeAssetBalanceBefore - nodeAssetAfter >= depositAmount,
            // "ROUTER4626_INVEST_ASSET_DELTA"
            // );
            // fl.t(sharesAfter > params.sharesBefore, "ROUTER4626_INVEST_SHARE_DELTA");

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER4626_INVEST_SHOULD_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626LiquidatePostconditions(
        bool success,
        bytes memory returnData,
        RouterLiquidateParams memory params,
        address[] memory actors
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER4626_LIQUIDATE_SHOULD_SUCCEED");
            uint256 assetsReturned = abi.decode(returnData, (uint256));
            // fl.t(assetsReturned > 0, "ROUTER4626_LIQUIDATE_ZERO_ASSETS");

            _after(actors);

            uint256 nodeAssetAfter = asset.balanceOf(address(node));
            uint256 sharesAfter = IERC20(params.component).balanceOf(address(node));

            // fl.eq(
            // params.sharesBefore - sharesAfter,
            // params.shares,
            // "ROUTER4626_LIQUIDATE_SHARE_DELTA"
            // );
            // fl.t(
            // nodeAssetAfter >= params.nodeAssetBalanceBefore + assetsReturned,
            // "ROUTER4626_LIQUIDATE_ASSET_DELTA"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER4626_LIQUIDATE_SHOULD_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626FulfillPostconditions(
        bool success,
        bytes memory returnData,
        RouterFulfillParams memory params,
        address[] memory actors
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER4626_FULFILL_SHOULD_SUCCEED");
            uint256 assetsReturned = abi.decode(returnData, (uint256));
            // fl.t(assetsReturned > 0, "ROUTER4626_FULFILL_ZERO_ASSETS");

            _after(actors);

            (uint256 pending,,,) = node.requests(params.controller);
            uint256 escrowBalanceAfter = asset.balanceOf(address(escrow));

            // fl.t(pending <= params.pendingBefore, "ROUTER4626_FULFILL_PENDING_NOT_REDUCED");
            // fl.eq(
            // escrowBalanceAfter,
            // params.escrowBalanceBefore + assetsReturned,
            // "ROUTER4626_FULFILL_ESCROW_BALANCE"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER4626_FULFILL_SHOULD_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626BatchWhitelistPostconditions(
        bool success,
        bytes memory returnData,
        RouterBatchWhitelistParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER4626_BATCH_WHITELIST_SUCCESS");

            for (uint256 i = 0; i < params.components.length; ++i) {
                // fl.eq(
                // router4626.isWhitelisted(params.components[i]),
                // params.statuses[i],
                // "ROUTER4626_BATCH_WHITELIST_STATUS"
                // );
            }

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER4626_BATCH_WHITELIST_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626SingleWhitelistPostconditions(
        bool success,
        bytes memory returnData,
        RouterSingleStatusParams memory params,
        bool isBlacklist
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER4626_STATUS_SUCCESS");
            bool stored =
                isBlacklist ? router4626.isBlacklisted(params.component) : router4626.isWhitelisted(params.component);
            // fl.eq(stored, params.status, "ROUTER4626_STATUS_MISMATCH");
            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER4626_STATUS_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626TolerancePostconditions(
        bool success,
        bytes memory returnData,
        RouterToleranceParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER4626_TOLERANCE_SUCCESS");
            // fl.eq(router4626.tolerance(), params.newTolerance, "ROUTER4626_TOLERANCE_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER4626_TOLERANCE_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }
}
