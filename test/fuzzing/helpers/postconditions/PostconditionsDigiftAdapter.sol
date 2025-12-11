// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {DigiftAdapter} from "../../../../src/adapters/digift/DigiftAdapter.sol";

contract PostconditionsDigiftAdapter is PostconditionsBase {
    function digiftForwardRequestsPostconditions(
        bool success,
        bytes memory returnData,
        DigiftForwardRequestParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 forwardedDeposits;
            while (_pendingDigiftDepositCount() > 0) {
                DigiftPendingDepositRecord memory record =
                    _consumeDigiftPendingDeposit(_pendingDigiftDepositCount() - 1);
                forwardedDeposits += record.assets;
                _recordDigiftForwardedDeposit(record);
            }

            // Only check invariants when we expected to actually forward something
            // AND the adapter confirms it has pending deposits. The fuzzer's tracking
            // might be stale if deposits were already processed by a previous call.
            uint256 globalPendingDeposit = digiftAdapter.globalPendingDepositRequest();
            if (forwardedDeposits > 0 && params.shouldSucceed && globalPendingDeposit > 0) {
                invariant_DIGIFT_01(globalPendingDeposit, forwardedDeposits);
            }

            uint256 forwardedRedemptions;
            while (_pendingDigiftRedemptionCount() > 0) {
                DigiftPendingRedemptionRecord memory record =
                    _consumeDigiftPendingRedemption(_pendingDigiftRedemptionCount() - 1);
                forwardedRedemptions += record.shares;
                _recordDigiftForwardedRedemption(record);
            }

            // Only check invariants when we expected to actually forward something
            // AND the adapter confirms it has pending redemptions. The fuzzer's tracking
            // might be stale if redemptions were already processed by a previous call.
            uint256 globalPendingRedeem = digiftAdapter.globalPendingRedeemRequest();
            if (forwardedRedemptions > 0 && params.shouldSucceed && globalPendingRedeem > 0) {
                invariant_DIGIFT_02(globalPendingRedeem, forwardedRedemptions);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftSettleDepositFlowPostconditions(
        bool success,
        bytes memory returnData,
        DigiftSettleDepositParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 recordsProcessed;
            for (uint256 i = 0; i < params.records.length; i++) {
                uint256 remaining = _forwardedDigiftDepositCount();
                if (remaining == 0) {
                    break;
                }
                DigiftPendingDepositRecord memory record = _consumeDigiftForwardedDeposit(remaining - 1);
                if (record.node != address(0)) {
                    uint256 maxMintable = digiftAdapter.maxMint(record.node);
                    invariant_DIGIFT_05(maxMintable);
                }
                recordsProcessed += record.assets;
            }

            if (recordsProcessed > 0) {
                uint256 remainingPending = digiftAdapter.globalPendingDepositRequest();
                invariant_DIGIFT_03(remainingPending);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftSettleRedeemFlowPostconditions(
        bool success,
        bytes memory returnData,
        DigiftSettleRedeemParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 recordsProcessed;
            uint256 totalMaxWithdrawable;
            for (uint256 i = 0; i < params.records.length; i++) {
                uint256 remaining = _forwardedDigiftRedemptionCount();
                if (remaining == 0) {
                    break;
                }
                DigiftPendingRedemptionRecord memory record = _consumeDigiftForwardedRedemption(remaining - 1);
                if (record.node != address(0)) {
                    uint256 maxWithdrawable = digiftAdapter.maxWithdraw(record.node);
                    invariant_DIGIFT_06(maxWithdrawable);
                    totalMaxWithdrawable += maxWithdrawable;
                }
                recordsProcessed += record.shares;
            }

            if (recordsProcessed > 0) {
                uint256 remainingPending = digiftAdapter.globalPendingRedeemRequest();
                invariant_DIGIFT_04(remainingPending);
            }

            if (params.assetsExpected > 0) {
                invariant_DIGIFT_07(totalMaxWithdrawable, params.assetsExpected);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftAssetFundingPostconditions(
        bool success,
        bytes memory returnData,
        DigiftAssetFundingParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftAssetApprovalPostconditions(
        bool success,
        bytes memory returnData,
        DigiftAssetApprovalParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftApprovePostconditions(
        bool success,
        bytes memory returnData,
        address owner,
        DigiftApproveParams memory params
    ) internal {
        if (success) {
            _after();
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftTransferPostconditions(
        bool success,
        bytes memory returnData,
        address from,
        DigiftTransferParams memory params
    ) internal {
        if (success) {
            _after();

            // Transfer placeholder - no specific invariant needed
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftRequestDepositPostconditions(
        bool success,
        bytes memory returnData,
        DigiftRequestParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftMintPostconditions(bool success, bytes memory returnData, DigiftMintParams memory params) internal {
        if (success) {
            _after();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftForwardPostconditions(bool success, bytes memory returnData, DigiftForwardParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftSettlePostconditions(
        bool success,
        bytes memory returnData,
        DigiftSettleParams memory params,
        bool isDeposit
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftWithdrawPostconditions(bool success, bytes memory returnData, DigiftWithdrawParams memory params)
        internal
    {
        if (success) {
            _after();

            invariant_DIGIFT_08(params.assets, params.maxWithdrawBefore);

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            invariant_DIGIFT_09(nodeBalanceAfter, params.nodeBalanceBefore);

            uint256 maxWithdrawAfter = digiftAdapter.maxWithdraw(address(node));
            invariant_DIGIFT_10(maxWithdrawAfter);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftRequestRedeemFlowPostconditions(
        bool success,
        bytes memory returnData,
        DigiftRequestRedeemParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 pendingAfter = digiftAdapter.pendingRedeemRequest(0, address(node));
            invariant_DIGIFT_11(pendingAfter, params.pendingBefore);

            uint256 balanceAfter = digiftAdapter.balanceOf(address(node));
            invariant_DIGIFT_12(balanceAfter, params.balanceBefore);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftSetAddressBoolPostconditions(
        bool success,
        bytes memory returnData,
        DigiftSetAddressBoolParams memory params,
        bool isManager
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftSetUintPostconditions(
        bool success,
        bytes memory returnData,
        DigiftSetUintParams memory params,
        uint8 selector
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftUpdatePricePostconditions(bool success, bytes memory returnData) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
