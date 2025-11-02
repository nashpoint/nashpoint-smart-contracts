// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {ERC7540Router} from "../../../../src/routers/ERC7540Router.sol";
import {ERC7540Mock} from "../../../mocks/ERC7540Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7575} from "../../../../src/interfaces/IERC7575.sol";

contract PostconditionsERC7540Router is PostconditionsBase {
    function router7540InvestPostconditions(
        bool success,
        bytes memory returnData,
        RouterAsyncInvestParams memory params,
        address[] memory actors
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_INVEST_SUCCESS");
            uint256 depositAmount = abi.decode(returnData, (uint256));
            // fl.t(depositAmount > 0, "ROUTER7540_INVEST_ZERO");

            _after(actors);

            uint256 pendingAfter = ERC7540Mock(params.component).pendingDepositRequest(0, address(node));
            uint256 nodeAssetAfter = asset.balanceOf(address(node));

            // fl.eq(
            // pendingAfter,
            // params.pendingDepositBefore + depositAmount,
            // "ROUTER7540_INVEST_PENDING_DELTA"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_INVEST_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540MintClaimablePostconditions(
        bool success,
        bytes memory returnData,
        RouterMintClaimableParams memory params,
        address[] memory actors
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_MINT_SUCCESS");
            uint256 sharesReceived = abi.decode(returnData, (uint256));
            // fl.t(sharesReceived > 0, "ROUTER7540_MINT_ZERO");

            _after(actors);

            uint256 claimableAfter = ERC7540Mock(params.component).claimableDepositRequest(0, address(node));
            uint256 shareBalanceAfter = IERC20(params.component).balanceOf(address(node));

            // fl.t(shareBalanceAfter >= params.shareBalanceBefore + sharesReceived, "ROUTER7540_MINT_SHARE_DELTA");
            // fl.t(
            // claimableAfter + sharesReceived <= params.claimableAssetsBefore,
            // "ROUTER7540_MINT_CLAIMABLE_DEC"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_MINT_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540RequestWithdrawalPostconditions(
        bool success,
        bytes memory returnData,
        RouterRequestAsyncWithdrawalParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_REQUEST_WITHDRAW_SUCCESS");
            uint256 shareBalanceAfter = IERC20(params.component).balanceOf(address(node));
            uint256 pendingAfter = ERC7540Mock(params.component).pendingRedeemRequest(0, address(node));

            // fl.eq(
            // params.shareBalanceBefore - shareBalanceAfter,
            // params.shares,
            // "ROUTER7540_REQUEST_SHARE_DELTA"
            // );
            // fl.eq(
            // pendingAfter,
            // params.pendingRedeemBefore + params.shares,
            // "ROUTER7540_REQUEST_PENDING_DELTA"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_REQUEST_WITHDRAW_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540ExecuteWithdrawalPostconditions(
        bool success,
        bytes memory returnData,
        RouterExecuteAsyncWithdrawalParams memory params,
        address[] memory actors
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_EXECUTE_SUCCESS");
            uint256 assetsReceived = abi.decode(returnData, (uint256));
            // fl.t(assetsReceived > 0, "ROUTER7540_EXECUTE_ZERO");

            _after(actors);

            uint256 nodeAssetAfter = asset.balanceOf(address(node));
            uint256 claimableAfter = IERC7575(params.component).maxWithdraw(address(node));

            // fl.t(
            // nodeAssetAfter >= params.nodeAssetBalanceBefore + assetsReceived,
            // "ROUTER7540_EXECUTE_ASSET_DELTA"
            // );
            // fl.t(
            // claimableAfter + assetsReceived <= params.claimableAssetsBefore,
            // "ROUTER7540_EXECUTE_CLAIMABLE_DELTA"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_EXECUTE_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540FulfillPostconditions(
        bool success,
        bytes memory returnData,
        RouterFulfillAsyncParams memory params,
        address[] memory actors
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_FULFILL_SUCCESS");
            uint256 assetsReturned = abi.decode(returnData, (uint256));
            // fl.t(assetsReturned > 0, "ROUTER7540_FULFILL_ZERO");

            _after(actors);

            (uint256 pending,,,) = node.requests(params.controller);
            uint256 escrowBalanceAfter = asset.balanceOf(address(escrow));
            uint256 claimableAfter = IERC7575(params.component).maxWithdraw(address(node));

            // fl.t(pending <= params.pendingBefore, "ROUTER7540_FULFILL_PENDING");
            // fl.eq(
            // escrowBalanceAfter,
            // params.escrowBalanceBefore + assetsReturned,
            // "ROUTER7540_FULFILL_ESCROW"
            // );
            // fl.t(
            // claimableAfter + assetsReturned <= params.claimableAssetsBefore,
            // "ROUTER7540_FULFILL_CLAIMABLE"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_FULFILL_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540BatchWhitelistPostconditions(
        bool success,
        bytes memory returnData,
        RouterBatchWhitelistParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_BATCH_WHITELIST_SUCCESS");

            for (uint256 i = 0; i < params.components.length; ++i) {
                // fl.eq(
                // router7540.isWhitelisted(params.components[i]),
                // params.statuses[i],
                // "ROUTER7540_BATCH_WHITELIST_STATUS"
                // );
            }

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_BATCH_WHITELIST_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540SingleStatusPostconditions(
        bool success,
        bytes memory returnData,
        RouterSingleStatusParams memory params,
        bool isBlacklist
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_STATUS_SUCCESS");
            bool stored =
                isBlacklist ? router7540.isBlacklisted(params.component) : router7540.isWhitelisted(params.component);
            // fl.eq(stored, params.status, "ROUTER7540_STATUS_MISMATCH");
            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_STATUS_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540TolerancePostconditions(
        bool success,
        bytes memory returnData,
        RouterToleranceParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "ROUTER7540_TOLERANCE_SUCCESS");
            // fl.eq(router7540.tolerance(), params.newTolerance, "ROUTER7540_TOLERANCE_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "ROUTER7540_TOLERANCE_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }
}
