// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_Digift.sol";

contract Properties_WT is Properties_Digift {
    // ==============================================================
    // WT ADAPTER INVARIANTS
    // ==============================================================

    function invariant_WT_01(uint256 globalPendingDeposit, uint256 forwardedDeposits) internal {
        fl.eq(globalPendingDeposit, forwardedDeposits, WT_01);
    }

    function invariant_WT_02(uint256 globalPendingRedeem, uint256 forwardedRedemptions) internal {
        fl.eq(globalPendingRedeem, forwardedRedemptions, WT_02);
    }

    function invariant_WT_03(uint256 remainingPending) internal {
        fl.eq(remainingPending, 0, WT_03);
    }

    function invariant_WT_04(uint256 remainingPending) internal {
        fl.eq(remainingPending, 0, WT_04);
    }

    function invariant_WT_05(uint256 maxMintable) internal {
        fl.t(maxMintable > 0, WT_05);
    }

    function invariant_WT_06(uint256 maxWithdrawable) internal {
        fl.t(maxWithdrawable > 0, WT_06);
    }

    function invariant_WT_07(uint256 totalMaxWithdrawable, uint256 assetsExpected) internal {
        fl.eq(totalMaxWithdrawable, assetsExpected, WT_07);
    }

    function invariant_WT_08(uint256 assets, uint256 maxWithdrawBefore) internal {
        fl.eq(assets, maxWithdrawBefore, WT_08);
    }

    function invariant_WT_09(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter >= nodeBalanceBefore, WT_09);
    }

    function invariant_WT_10(uint256 maxWithdrawAfter) internal {
        fl.eq(maxWithdrawAfter, 0, WT_10);
    }

    function invariant_WT_11(uint256 pendingAfter, uint256 pendingBefore) internal {
        fl.gt(pendingAfter, pendingBefore, WT_11);
    }

    function invariant_WT_12(uint256 balanceAfter, uint256 balanceBefore) internal {
        fl.t(balanceAfter <= balanceBefore, WT_12);
    }

    function invariant_WT_13(uint256 totalSupplyBefore, uint256 totalSupplyAfter, uint256 dividendAmount) internal {
        fl.t(totalSupplyAfter >= totalSupplyBefore, WT_13);
        fl.eq(totalSupplyAfter - totalSupplyBefore, dividendAmount, WT_13);
    }

    function invariant_WT_14(uint256 totalMintedToNodes, uint256 dividendAmount) internal {
        fl.eq(totalMintedToNodes, dividendAmount, WT_14);
    }
}
