// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";

contract Properties_Digift is Properties_ERR {
    // ==============================================================
    // DIGIFT ADAPTER INVARIANTS
    // ==============================================================

    function invariant_DIGIFT_01(DigiftForwardRequestParams memory params) internal {
        // fl.eq(digiftAdapter.globalPendingDepositRequest(), forwardedDeposits, DIGIFT_01);
    }

    function invariant_DIGIFT_02(DigiftForwardRequestParams memory params) internal {
        // fl.eq(digiftAdapter.globalPendingRedeemRequest(), forwardedRedemptions, DIGIFT_02);
    }

    function invariant_DIGIFT_03() internal {
        // Settle deposit flow: no mintable shares remains unprocessed
        // fl.eq(remainingPending, 0, DIGIFT_03);
    }

    function invariant_DIGIFT_04() internal {
        // Settle redeem flow: no pending remains unprocessed
        // fl.eq(remainingPending, 0, DIGIFT_04);
    }

    function invariant_DIGIFT_05(DigiftAssetApprovalParams memory params) internal {
        uint256 allowance = asset.allowance(address(node), address(digiftAdapter));
        // fl.eq(allowance, params.amount, DIGIFT_05);
    }

    function invariant_DIGIFT_06(address owner, DigiftApproveParams memory params) internal {
        uint256 allowance = digiftAdapter.allowance(owner, params.spender);
        // fl.eq(allowance, params.amount, DIGIFT_06);
    }

    function invariant_DIGIFT_07(DigiftRequestParams memory params) internal {
        uint256 pending = digiftAdapter.pendingDepositRequest(0, address(node));
        // fl.eq(pending, params.amount, DIGIFT_07);
    }

    function invariant_DIGIFT_08(DigiftForwardParams memory params) internal {
        if (!params.expectDeposit) {
            // fl.eq(digiftAdapter.globalPendingDepositRequest(), 0, DIGIFT_08);
        }
    }

    function invariant_DIGIFT_09(DigiftForwardParams memory params) internal {
        if (!params.expectRedeem) {
            // fl.eq(digiftAdapter.globalPendingRedeemRequest(), 0, DIGIFT_09);
        }
    }

    function invariant_DIGIFT_10(bool isDeposit) internal {
        if (isDeposit) {
            // fl.eq(digiftAdapter.globalPendingDepositRequest(), 0, DIGIFT_10);
        } else {
            // fl.eq(digiftAdapter.globalPendingRedeemRequest(), 0, DIGIFT_10);
        }
    }

    function invariant_DIGIFT_11(DigiftWithdrawParams memory params) internal {
        // fl.eq(params.assets, params.maxWithdrawBefore, DIGIFT_11);
    }

    function invariant_DIGIFT_12(DigiftWithdrawParams memory params) internal {
        uint256 nodeBalanceAfter = asset.balanceOf(address(node));
        fl.t(nodeBalanceAfter >= params.nodeBalanceBefore, DIGIFT_12);
    }

    function invariant_DIGIFT_13() internal {
        uint256 maxWithdrawAfter = digiftAdapter.maxWithdraw(address(node));
        fl.eq(maxWithdrawAfter, 0, DIGIFT_13);
    }

    function invariant_DIGIFT_14(DigiftRequestRedeemParams memory params) internal {
        uint256 pendingAfter = digiftAdapter.pendingRedeemRequest(0, address(node));
        fl.gt(pendingAfter, params.pendingBefore, DIGIFT_14);
    }

    function invariant_DIGIFT_15(DigiftRequestRedeemParams memory params) internal {
        uint256 balanceAfter = digiftAdapter.balanceOf(address(node));
        fl.t(balanceAfter <= params.balanceBefore, DIGIFT_15);
    }

    function invariant_DIGIFT_16(DigiftSetAddressBoolParams memory params, bool isManager) internal {
        if (isManager) {
            // fl.eq(digiftAdapter.managerWhitelisted(params.target), params.status, DIGIFT_16);
        } else {
            // fl.eq(digiftAdapter.nodeWhitelisted(params.target), params.status, DIGIFT_16);
        }
    }

    function invariant_DIGIFT_17(DigiftSetUintParams memory params, uint8 selector) internal {
        // if (selector == 0) {
        //     fl.eq(digiftAdapter.minDepositAmount(), params.value, DIGIFT_17);
        // } else if (selector == 1) {
        //     fl.eq(digiftAdapter.minRedeemAmount(), params.value, DIGIFT_17);
        // } else if (selector == 2) {
        //     fl.eq(digiftAdapter.priceDeviation(), params.value, DIGIFT_17);
        // } else if (selector == 3) {
        //     fl.eq(digiftAdapter.settlementDeviation(), params.value, DIGIFT_17);
        // } else if (selector == 4) {
        //     fl.eq(digiftAdapter.priceUpdateDeviation(), params.value, DIGIFT_17);
        // }
    }

    function invariant_DIGIFT_18() internal {
        // fl.gt(digiftAdapter.lastPrice(), 0, DIGIFT_18);
    }

    // ==============================================================
    // DIGIFT EVENT VERIFIER INVARIANTS
    // ==============================================================

    function invariant_DIGIFT_VERIFIER_01(
        DigiftVerifierConfigureParams memory params,
        uint256 shares,
        uint256 assets
    ) internal {
        // fl.eq(shares, params.expectedShares, DIGIFT_VERIFIER_01);
        // fl.eq(assets, params.expectedAssets, DIGIFT_VERIFIER_01);
    }

    function invariant_DIGIFT_VERIFIER_02(DigiftVerifierWhitelistParams memory params, bool stored) internal {
        // fl.eq(stored, params.status, DIGIFT_VERIFIER_02);
    }

    function invariant_DIGIFT_VERIFIER_03(
        DigiftVerifierVerifyParams memory params,
        uint256 shares,
        uint256 assets
    ) internal {
        // fl.eq(shares, params.expectedShares, DIGIFT_VERIFIER_03);
        // fl.eq(assets, params.expectedAssets, DIGIFT_VERIFIER_03);
    }
}
