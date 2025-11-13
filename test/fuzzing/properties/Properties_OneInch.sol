// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";

contract Properties_OneInch is Properties_ERR {
    function invariant_ONEINCH_01() internal {
        uint256 balanceBefore = states[0].nodeAssetBalance;
        uint256 balanceAfter = states[1].nodeAssetBalance;

        fl.gt(balanceAfter, balanceBefore, ONEINCH_01);
    }

    function invariant_ONEINCH_02(OneInchSwapParams memory params) internal {
        uint256 incentiveBalanceBefore = params.incentiveBalanceBefore;
        uint256 incentiveBalanceAfter = IERC20(params.incentive).balanceOf(address(node));
        uint256 spentAmount = incentiveBalanceBefore - incentiveBalanceAfter;
        fl.eq(spentAmount, params.incentiveAmount, ONEINCH_02);
    }
}