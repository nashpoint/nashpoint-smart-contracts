// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";
import {ERC20Mock} from "../../../mocks/ERC20Mock.sol";

contract PreconditionsOneInch is PreconditionsBase {
    /**
     * @notice Preconditions for OneInch swap operation
     * @dev Sets up:
     *      1. Whitelists incentive token and executor
     *      2. Mints incentive tokens to node
     *      3. Encodes expected return in swapCalldata
     *      4. Ensures minAssetsOut is reasonable
     */
    function oneInchSwapPreconditions(uint256 seed) internal returns (OneInchSwapParams memory params) {
        // Create or use existing incentive token
        // For simplicity, create a new mock token as "incentive"
        ERC20Mock incentiveToken = new ERC20Mock("Incentive Token", "INCENT");
        params.incentive = address(incentiveToken);

        // Select executor from USERS
        params.executor = USERS[seed % USERS.length];
        if (params.executor == address(node) || params.executor == address(0)) {
            params.executor = rebalancer;
        }

        // Whitelist incentive and executor
        vm.startPrank(owner);
        routerOneInch.setIncentiveWhitelistStatus(params.incentive, true);
        routerOneInch.setExecutorWhitelistStatus(params.executor, true);
        vm.stopPrank();

        // Mint incentive tokens to node
        params.incentiveAmount = fl.clamp(seed + 1, 1e18, 1000e18);
        incentiveToken.mint(address(node), params.incentiveAmount);

        params.incentiveBalanceBefore = incentiveToken.balanceOf(address(node));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        // Calculate expected return (simulate 1:1 swap with small slippage)
        // In a real scenario, this would come from price oracle or DEX quote
        params.expectedReturn = params.incentiveAmount; // 1:1 for simplicity
        params.minAssetsOut = (params.expectedReturn * 95) / 100; // 5% slippage tolerance

        // Encode expected return in swapCalldata (mock expects this format)
        params.swapCalldata = abi.encode(params.expectedReturn);

        params.shouldSucceed = true;
    }
}
