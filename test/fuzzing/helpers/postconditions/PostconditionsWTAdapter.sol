// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {WTAdapter} from "../../../../src/adapters/wt/WTAdapter.sol";

contract PostconditionsWTAdapter is PostconditionsBase {
    function wtForwardRequestsPostconditions(
        bool success,
        bytes memory returnData,
        WTForwardRequestParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 forwardedDeposits;
            while (_pendingWTDepositCount() > 0) {
                WTPendingDepositRecord memory record =
                    _consumeWTPendingDeposit(_pendingWTDepositCount() - 1);
                forwardedDeposits += record.assets;
                _recordWTForwardedDeposit(record);
            }

            uint256 globalPendingDeposit = wtAdapter.globalPendingDepositRequest();
            if (forwardedDeposits > 0 && params.shouldSucceed && globalPendingDeposit > 0) {
                invariant_WT_01(globalPendingDeposit, forwardedDeposits);
            }

            uint256 forwardedRedemptions;
            while (_pendingWTRedemptionCount() > 0) {
                WTPendingRedemptionRecord memory record =
                    _consumeWTPendingRedemption(_pendingWTRedemptionCount() - 1);
                forwardedRedemptions += record.shares;
                _recordWTForwardedRedemption(record);
            }

            uint256 globalPendingRedeem = wtAdapter.globalPendingRedeemRequest();
            if (forwardedRedemptions > 0 && params.shouldSucceed && globalPendingRedeem > 0) {
                invariant_WT_02(globalPendingRedeem, forwardedRedemptions);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function wtSettleDepositFlowPostconditions(
        bool success,
        bytes memory returnData,
        WTSettleDepositParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 recordsProcessed;
            for (uint256 i = 0; i < params.records.length; i++) {
                uint256 remaining = _forwardedWTDepositCount();
                if (remaining == 0) {
                    break;
                }
                WTPendingDepositRecord memory record = _consumeWTForwardedDeposit(remaining - 1);
                if (record.node != address(0)) {
                    uint256 maxMintable = wtAdapter.maxMint(record.node);
                    invariant_WT_05(maxMintable);
                }
                recordsProcessed += record.assets;
            }

            if (recordsProcessed > 0) {
                uint256 remainingPending = wtAdapter.globalPendingDepositRequest();
                invariant_WT_03(remainingPending);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function wtSettleRedeemFlowPostconditions(
        bool success,
        bytes memory returnData,
        WTSettleRedeemParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 recordsProcessed;
            uint256 totalMaxWithdrawable;
            for (uint256 i = 0; i < params.records.length; i++) {
                uint256 remaining = _forwardedWTRedemptionCount();
                if (remaining == 0) {
                    break;
                }
                WTPendingRedemptionRecord memory record = _consumeWTForwardedRedemption(remaining - 1);
                if (record.node != address(0)) {
                    uint256 maxWithdrawable = wtAdapter.maxWithdraw(record.node);
                    invariant_WT_06(maxWithdrawable);
                    totalMaxWithdrawable += maxWithdrawable;
                }
                recordsProcessed += record.shares;
            }

            if (recordsProcessed > 0) {
                uint256 remainingPending = wtAdapter.globalPendingRedeemRequest();
                invariant_WT_04(remainingPending);
            }

            if (params.assetsExpected > 0) {
                invariant_WT_07(totalMaxWithdrawable, params.assetsExpected);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function wtMintPostconditions(bool success, bytes memory returnData, WTMintParams memory params) internal {
        if (success) {
            _after();
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function wtWithdrawPostconditions(bool success, bytes memory returnData, WTWithdrawParams memory params)
        internal
    {
        if (success) {
            _after();

            invariant_WT_08(params.assets, params.maxWithdrawBefore);

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            invariant_WT_09(nodeBalanceAfter, params.nodeBalanceBefore);

            uint256 maxWithdrawAfter = wtAdapter.maxWithdraw(address(node));
            invariant_WT_10(maxWithdrawAfter);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function wtRequestRedeemFlowPostconditions(
        bool success,
        bytes memory returnData,
        WTRequestRedeemParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 pendingAfter = wtAdapter.pendingRedeemRequest(0, address(node));
            invariant_WT_11(pendingAfter, params.pendingBefore);

            uint256 balanceAfter = wtAdapter.balanceOf(address(node));
            invariant_WT_12(balanceAfter, params.balanceBefore);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function wtSettleDividendPostconditions(
        bool success,
        bytes memory returnData,
        WTSettleDividendParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 totalSupplyAfter = wtAdapter.totalSupply();
            invariant_WT_13(params.totalSupplyBefore, totalSupplyAfter, params.dividendAmount);

            uint256 totalMintedToNodes;
            for (uint256 i = 0; i < params.nodes.length; i++) {
                uint256 balanceBefore = i < params.nodeBalancesBefore.length ? params.nodeBalancesBefore[i] : 0;
                uint256 balanceAfter = wtAdapter.balanceOf(params.nodes[i]);
                fl.t(balanceAfter >= balanceBefore, WT_14);
                totalMintedToNodes += balanceAfter - balanceBefore;
            }
            invariant_WT_14(totalMintedToNodes, params.dividendAmount);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
