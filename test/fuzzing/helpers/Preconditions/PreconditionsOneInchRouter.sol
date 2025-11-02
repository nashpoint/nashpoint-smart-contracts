// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../../../mocks/ERC20Mock.sol";

contract PreconditionsOneInchRouter is PreconditionsBase {
    function oneInchSwapPreconditions(uint256 incentiveSeed, uint256 amountSeed, uint256 slippageSeed)
        internal
        returns (OneInchSwapParams memory params)
    {
        address incentive = _createIncentiveToken(incentiveSeed);
        params.incentive = incentive;
        params.executor = rebalancer;

        params.incentiveAmount = fl.clamp(amountSeed, 1e16, 1000e18);
        params.minAssetsOut = params.incentiveAmount - (params.incentiveAmount * (slippageSeed % 50)) / 1000;

        params.expectedReturn = params.minAssetsOut + ((params.incentiveAmount - params.minAssetsOut) / 2);
        params.swapCalldata = abi.encode(params.expectedReturn);
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.incentiveBalanceBefore = IERC20(incentive).balanceOf(address(node));

        if (params.incentiveBalanceBefore < params.incentiveAmount) {
            _mintIncentiveToNode(incentive, params.incentiveAmount * 2);
            params.incentiveBalanceBefore = IERC20(incentive).balanceOf(address(node));
        }

        params.shouldSucceed = true;

        vm.startPrank(owner);
        routerOneInch.setWhitelistStatus(address(node), true);
        routerOneInch.setWhitelistStatus(address(routerOneInch), true);
        routerOneInch.setIncentiveWhitelistStatus(incentive, true);
        routerOneInch.setExecutorWhitelistStatus(params.executor, true);
        vm.stopPrank();
    }

    function _createIncentiveToken(uint256 seed) internal returns (address token) {
        ERC20Mock incentive = new ERC20Mock(string(abi.encodePacked("INC", seed)), "INC");
        token = address(incentive);
    }

    function _mintIncentiveToNode(address incentive, uint256 amount) internal {
        ERC20Mock(incentive).mint(address(node), amount);
    }

    function oneInchSetIncentivePreconditions(uint256 seed, bool status)
        internal
        returns (OneInchStatusParams memory params)
    {
        params.target = _createIncentiveToken(seed + 1);
        params.status = status;
        params.shouldSucceed = true;
    }

    function oneInchSetExecutorPreconditions(uint256 seed, bool status)
        internal
        returns (OneInchStatusParams memory params)
    {
        params.target = USERS[seed % USERS.length];
        params.status = status;
        params.shouldSucceed = true;
    }
}
