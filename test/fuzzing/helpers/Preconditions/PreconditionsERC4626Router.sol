// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {ERC4626Router} from "../../../../src/routers/ERC4626Router.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreconditionsERC4626Router is PreconditionsBase {
    using Math for uint256;

    function router4626InvestPreconditions(uint256 componentSeed, uint256 amountSeed)
        internal
        returns (RouterInvestParams memory params)
    {
        address component = _selectERC4626Component(componentSeed);
        _ensureRouterWhitelist(component);

        uint256 boost = fl.clamp(amountSeed, 10e18, 500_000e18);
        _increaseNodeReserve(boost);

        params.component = component;
        params.minSharesOut = 0;
        params.shouldSucceed = component != address(0);
        params.sharesBefore = IERC20(component).balanceOf(address(node));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
    }

    function router4626LiquidatePreconditions(uint256 componentSeed, uint256 sharesSeed)
        internal
        returns (RouterLiquidateParams memory params)
    {
        address component = _selectERC4626Component(componentSeed);
        _ensureRouterWhitelist(component);

        uint256 sharesBalance = _ensureComponentLiquidity(component);
        if (sharesBalance == 0) {
            params.shouldSucceed = false;
            params.component = component;
            params.shares = 0;
            return params;
        }

        uint256 shares = fl.clamp(sharesSeed % sharesBalance + 1, 1, sharesBalance);

        params.component = component;
        params.shares = shares;
        params.minAssetsOut = 0;
        params.shouldSucceed = shares > 0;
        params.sharesBefore = sharesBalance;
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
    }

    function router4626FulfillPreconditions(uint256 controllerSeed, uint256 componentSeed)
        internal
        returns (RouterFulfillParams memory params)
    {
        address component = _selectERC4626Component(componentSeed);
        _ensureRouterWhitelist(component);

        address controller = USERS[controllerSeed % USERS.length];
        uint256 userAssets =
            fl.clamp(uint256(keccak256(abi.encodePacked(controllerSeed, componentSeed))), 100e18, 1_000e18);
        assetToken.mint(controller, userAssets);

        vm.startPrank(controller);
        asset.approve(address(node), type(uint256).max);
        node.deposit(userAssets, controller);
        uint256 redeemShares = Math.max(node.balanceOf(controller) / 2, 1);
        node.requestRedeem(redeemShares, controller, controller);
        vm.stopPrank();

        uint256 sharesBalance = _ensureComponentLiquidity(component);

        address[] memory queue = new address[](1);
        queue[0] = component;
        vm.startPrank(owner);
        node.setLiquidationQueue(queue);
        vm.stopPrank();

        (uint256 pending,,,) = node.requests(controller);
        if (sharesBalance == 0 || pending == 0) {
            params.shouldSucceed = false;
            params.component = component;
            params.controller = controller;
            return params;
        }

        params.controller = controller;
        params.component = component;
        params.minAssetsOut = 0;
        params.pendingBefore = pending;
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.shouldSucceed = pending > 0;
    }

    function router4626BatchWhitelistPreconditions(uint256 seed)
        internal
        returns (RouterBatchWhitelistParams memory params)
    {
        uint256 len = COMPONENTS_ERC4626.length;
        if (len == 0) {
            params.shouldSucceed = false;
            return params;
        }

        uint256 batchSize = Math.min(len, uint256(2));
        params.components = new address[](batchSize);
        params.statuses = new bool[](batchSize);

        for (uint256 i = 0; i < batchSize; ++i) {
            address component = COMPONENTS_ERC4626[(seed + i) % len];
            params.components[i] = component;
            params.statuses[i] = ((seed >> i) & 1) == 0;
        }

        params.shouldSucceed = true;
    }

    function router4626SingleWhitelistPreconditions(uint256 seed, bool status)
        internal
        returns (RouterSingleStatusParams memory params)
    {
        params.component = _selectERC4626Component(seed);
        params.status = status;
        params.shouldSucceed = params.component != address(0);
    }

    function router4626TolerancePreconditions(uint256 seed)
        internal
        pure
        returns (RouterToleranceParams memory params)
    {
        params.newTolerance = seed % 1_000_000e18;
        params.shouldSucceed = true;
    }

    function _selectERC4626Component(uint256 seed) internal view returns (address component) {
        if (COMPONENTS_ERC4626.length == 0) {
            return address(0);
        }
        component = COMPONENTS_ERC4626[seed % COMPONENTS_ERC4626.length];
    }

    function _ensureRouterWhitelist(address component) internal {
        if (component == address(0)) {
            return;
        }
        vm.startPrank(owner);
        router4626.setWhitelistStatus(component, true);
        router4626.setBlacklistStatus(component, false);
        vm.stopPrank();
    }

    function _increaseNodeReserve(uint256 extraAssets) internal {
        assetToken.mint(address(node), extraAssets);
        vm.startPrank(rebalancer);
        node.updateTotalAssets();
        vm.stopPrank();
    }

    function _ensureComponentLiquidity(address component) internal returns (uint256 sharesAfter) {
        if (component == address(0)) return 0;

        uint256 beforeShares = IERC20(component).balanceOf(address(node));
        if (beforeShares > 0) {
            return beforeShares;
        }

        _increaseNodeReserve(500_000e18);
        vm.startPrank(rebalancer);
        router4626.invest(address(node), component, 0);
        vm.stopPrank();
        sharesAfter = IERC20(component).balanceOf(address(node));
    }
}
