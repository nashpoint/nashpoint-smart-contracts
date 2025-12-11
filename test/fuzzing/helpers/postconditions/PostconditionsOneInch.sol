// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PostconditionsOneInch is PostconditionsBase {
    /**
     * @notice Postconditions for OneInch swap operation
     * @dev Verifies:
     *      1. Swap succeeded/failed as expected
     *      2. Incentive tokens were transferred from node to executor
     *      3. Asset tokens were received by node
     *      4. Asset amount accounts for execution fee subtraction
     */
    function oneInchSwapPostconditions(bool success, bytes memory returnData, OneInchSwapParams memory params)
        internal
    {
        if (success) {
            _after();

            address nodeAddr = address(node);
            address executorAddr = params.executor;

            // Node should have received assets
            uint256 nodeAssetBalanceAfter = asset.balanceOf(nodeAddr);
            uint256 assetGain = nodeAssetBalanceAfter - params.nodeAssetBalanceBefore;

            // Assets should be at least minAssetsOut (after fee)
            // Fee is subtracted by _subtractExecutionFee, so actual amount might be slightly less
            invariant_ONEINCH_03(assetGain, params.minAssetsOut);

            // Incentive tokens should be transferred from node
            uint256 incentiveBalanceAfter = IERC20(params.incentive).balanceOf(nodeAddr);
            uint256 incentiveLoss = params.incentiveBalanceBefore - incentiveBalanceAfter;
            invariant_ONEINCH_04(incentiveLoss, params.incentiveAmount);

            // Executor should have received incentive tokens
            uint256 executorIncentiveBalance = IERC20(params.incentive).balanceOf(executorAddr);
            invariant_ONEINCH_05(executorIncentiveBalance, params.incentiveAmount);

            invariant_ONEINCH_01();
            invariant_ONEINCH_02(params);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
