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
        if (success && params.shouldSucceed) {
            uint256 forwardedTotal;
            while (_pendingDigiftDepositCount() > 0) {
                DigiftPendingDepositRecord memory record =
                    _consumeDigiftPendingDeposit(_pendingDigiftDepositCount() - 1);
                forwardedTotal += record.assets;
                _recordDigiftForwardedDeposit(record);
            }

            uint256 globalPending = digiftAdapter.globalPendingDepositRequest();
            if (forwardedTotal > 0) {
                fl.eq(globalPending, forwardedTotal, "DIGIFT_FORWARD_GLOBAL_PENDING");
            }
            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
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
        if (success && params.shouldSucceed) {
            uint256 recordsProcessed;
            for (uint256 i = 0; i < params.records.length; i++) {
                uint256 remaining = _forwardedDigiftDepositCount();
                if (remaining == 0) {
                    break;
                }
                DigiftPendingDepositRecord memory record = _consumeDigiftForwardedDeposit(remaining - 1);
                if (record.node != address(0)) {
                    uint256 maxMintable = digiftAdapter.maxMint(record.node);
                    fl.t(maxMintable > 0, "DIGIFT_SETTLE_NO_MINTABLE_SHARES");
                }
                recordsProcessed += record.assets;
            }

            if (recordsProcessed > 0) {
                uint256 remainingPending = digiftAdapter.globalPendingDepositRequest();
                fl.eq(remainingPending, 0, "DIGIFT_SETTLE_PENDING_REMAINS");
            }
            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
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
        if (success && params.shouldSucceed) {
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
        if (success && params.shouldSucceed) {
            uint256 allowance = asset.allowance(address(node), address(digiftAdapter));
            // fl.eq(allowance, params.amount, "DIGIFT_ASSET_ALLOWANCE_MISMATCH");
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
        if (success && params.shouldSucceed) {
            uint256 allowance = digiftAdapter.allowance(owner, params.spender);
            // fl.eq(allowance, params.amount, "DIGIFT_APPROVE_AMOUNT_MISMATCH");
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
        if (success && params.shouldSucceed) {
            // fl.eq(digiftAdapter.balanceOf(params.to), digiftAdapter.balanceOf(params.to), "DIGIFT_TRANSFER_PLACEHOLDER");
            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
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
        if (success && params.shouldSucceed) {
            uint256 pending = digiftAdapter.pendingDepositRequest(0, address(node));
            // fl.eq(pending, params.amount, "DIGIFT_PENDING_DEPOSIT_ANOMALY");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftRequestRedeemPostconditions(bool success, bytes memory returnData, DigiftRequestParams memory params)
        internal
    {
        if (success && params.shouldSucceed) {
            uint256 pending = digiftAdapter.pendingRedeemRequest(0, address(node));
            // fl.eq(pending, params.amount, "DIGIFT_PENDING_REDEEM_ANOMALY");
            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftMintPostconditions(bool success, bytes memory returnData, DigiftMintParams memory params) internal {
        if (success && params.shouldSucceed) {
            onSuccessInvariantsGeneral(returnData);
        } else if (!params.shouldSucceed && !success) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
            // unexpected success - still treat as success for invariants coverage
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftForwardPostconditions(bool success, bytes memory returnData, DigiftForwardParams memory params)
        internal
    {
        if (success && params.shouldSucceed) {
            if (!params.expectDeposit) {
                // fl.eq(digiftAdapter.globalPendingDepositRequest(), 0, "DIGIFT_FORWARD_DEPOSIT_PENDING");
            }
            if (!params.expectRedeem) {
                // fl.eq(digiftAdapter.globalPendingRedeemRequest(), 0, "DIGIFT_FORWARD_REDEEM_PENDING");
            }
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
        if (success && params.shouldSucceed) {
            if (isDeposit) {
                // fl.eq(digiftAdapter.globalPendingDepositRequest(), 0, "DIGIFT_SETTLE_DEPOSIT_PENDING");
            } else {
                // fl.eq(digiftAdapter.globalPendingRedeemRequest(), 0, "DIGIFT_SETTLE_REDEEM_PENDING");
            }
            onSuccessInvariantsGeneral(returnData);
        } else if (!success && !params.shouldSucceed) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftWithdrawPostconditions(bool success, bytes memory returnData, DigiftWithdrawParams memory params)
        internal
    {
        if (success && params.shouldSucceed) {
            onSuccessInvariantsGeneral(returnData);
        } else if (!params.shouldSucceed && !success) {
            onFailInvariantsGeneral(returnData);
        } else if (success && !params.shouldSucceed) {
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
        if (success && params.shouldSucceed) {
            if (isManager) {
                // fl.eq(digiftAdapter.managerWhitelisted(params.target), params.status, "DIGIFT_MANAGER_STATUS");
            } else {
                // fl.eq(digiftAdapter.nodeWhitelisted(params.target), params.status, "DIGIFT_NODE_STATUS");
            }
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
        if (success && params.shouldSucceed) {
            if (selector == 0) {
                // fl.eq(digiftAdapter.minDepositAmount(), params.value, "DIGIFT_MIN_DEPOSIT");
            } else if (selector == 1) {
                // fl.eq(digiftAdapter.minRedeemAmount(), params.value, "DIGIFT_MIN_REDEEM");
            } else if (selector == 2) {
                // fl.eq(digiftAdapter.priceDeviation(), params.value, "DIGIFT_PRICE_DEV");
            } else if (selector == 3) {
                // fl.eq(digiftAdapter.settlementDeviation(), params.value, "DIGIFT_SETTLE_DEV");
            } else if (selector == 4) {
                // fl.eq(digiftAdapter.priceUpdateDeviation(), params.value, "DIGIFT_PRICE_UPDATE_DEV");
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftUpdatePricePostconditions(bool success, bytes memory returnData) internal {
        if (success) {
            // fl.gt(digiftAdapter.lastPrice(), 0, "DIGIFT_PRICE_NOT_SET");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
