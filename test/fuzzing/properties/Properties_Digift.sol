// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";

contract Properties_Digift is Properties_ERR {
    // ==============================================================
    // DIGIFT ADAPTER INVARIANTS
    // ==============================================================

    function invariant_DIGIFT_01(uint256 globalPendingDeposit, uint256 forwardedDeposits) internal {
        fl.eq(globalPendingDeposit, forwardedDeposits, DIGIFT_01);
    }

    function invariant_DIGIFT_02(uint256 globalPendingRedeem, uint256 forwardedRedemptions) internal {
        fl.eq(globalPendingRedeem, forwardedRedemptions, DIGIFT_02);
    }

    function invariant_DIGIFT_03(uint256 remainingPending) internal {
        // Settle deposit flow: no mintable shares remains unprocessed
        fl.eq(remainingPending, 0, DIGIFT_03);
    }

    function invariant_DIGIFT_04(uint256 remainingPending) internal {
        // Settle redeem flow: no pending remains unprocessed
        fl.eq(remainingPending, 0, DIGIFT_04);
    }

    function invariant_DIGIFT_05(uint256 maxMintable) internal {
        fl.t(maxMintable > 0, DIGIFT_05);
    }

    function invariant_DIGIFT_06(uint256 maxWithdrawable) internal {
        fl.t(maxWithdrawable > 0, DIGIFT_06);
    }

    function invariant_DIGIFT_07(uint256 totalMaxWithdrawable, uint256 assetsExpected) internal {
        fl.eq(totalMaxWithdrawable, assetsExpected, DIGIFT_07);
    }

    function invariant_DIGIFT_08(uint256 assets, uint256 maxWithdrawBefore) internal {
        fl.eq(assets, maxWithdrawBefore, DIGIFT_08);
    }

    function invariant_DIGIFT_09(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter >= nodeBalanceBefore, DIGIFT_09);
    }

    function invariant_DIGIFT_10(uint256 maxWithdrawAfter) internal {
        fl.eq(maxWithdrawAfter, 0, DIGIFT_10);
    }

    function invariant_DIGIFT_11(uint256 pendingAfter, uint256 pendingBefore) internal {
        fl.gt(pendingAfter, pendingBefore, DIGIFT_11);
    }

    function invariant_DIGIFT_12(uint256 balanceAfter, uint256 balanceBefore) internal {
        fl.t(balanceAfter <= balanceBefore, DIGIFT_12);
    }
}
