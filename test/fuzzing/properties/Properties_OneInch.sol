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

    function invariant_ONEINCH_03(uint256 assetGain, uint256 minAssetsOut) internal {
        fl.t(assetGain >= (minAssetsOut * 99) / 100, ONEINCH_03);
    }

    function invariant_ONEINCH_04(uint256 incentiveLoss, uint256 incentiveAmount) internal {
        fl.eq(incentiveLoss, incentiveAmount, ONEINCH_04);
    }

    function invariant_ONEINCH_05(uint256 executorIncentiveBalance, uint256 incentiveAmount) internal {
        fl.gte(executorIncentiveBalance, incentiveAmount, ONEINCH_05);
    }
}
