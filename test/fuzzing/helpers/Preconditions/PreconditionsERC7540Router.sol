// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {ERC7540Router} from "../../../../src/routers/ERC7540Router.sol";
import {ERC7540Mock} from "../../../mocks/ERC7540Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7575} from "../../../../src/interfaces/IERC7575.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreconditionsERC7540Router is PreconditionsBase {
    function router7540InvestPreconditions(uint256 componentSeed, uint256 amountSeed)
        internal
        returns (RouterAsyncInvestParams memory params)
    {
        address component = _selectERC7540Component(componentSeed);
        _ensureRouter7540Whitelist(component);

        params.component = component;
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.pendingDepositBefore = _pendingDeposit(component);
        params.shouldSucceed = component != address(0);

        uint256 extraAssets = fl.clamp(amountSeed, 100e18, 1_000_000e18);
        _increaseNodeReserve7540(extraAssets);

        return params;
    }

    function router7540MintClaimablePreconditions(uint256 componentSeed)
        internal
        returns (RouterMintClaimableParams memory params)
    {
        address component = _selectERC7540Component(componentSeed);
        _ensureRouter7540Whitelist(component);

        params.component = component;

        uint256 claimableBefore = _prepareClaimableDeposits(component);
        params.claimableAssetsBefore = claimableBefore;
        params.shareBalanceBefore = IERC20(component).balanceOf(address(node));
        params.shouldSucceed = claimableBefore > 0;
    }

    function router7540RequestWithdrawalPreconditions(uint256 componentSeed, uint256 shareSeed)
        internal
        returns (RouterRequestAsyncWithdrawalParams memory params)
    {
        address component = _selectERC7540Component(componentSeed);
        _ensureRouter7540Whitelist(component);

        uint256 shareBalance = _ensureNodeAsyncShares(component);
        uint256 shares = shareBalance == 0 ? 0 : fl.clamp((shareSeed % shareBalance) + 1, 1, shareBalance);

        params.component = component;
        params.shares = shares;
        params.shareBalanceBefore = shareBalance;
        params.pendingRedeemBefore = _pendingRedeem(component);
        params.shouldSucceed = shares > 0;
    }

    function router7540ExecuteWithdrawalPreconditions(uint256 componentSeed, uint256 assetsSeed)
        internal
        returns (RouterExecuteAsyncWithdrawalParams memory params)
    {
        address component = _selectERC7540Component(componentSeed);
        _ensureRouter7540Whitelist(component);

        uint256 claimableAssets = _prepareClaimableRedeems(component);
        uint256 assets = claimableAssets == 0 ? 0 : fl.clamp((assetsSeed % claimableAssets) + 1, 1, claimableAssets);

        params.component = component;
        params.assets = assets;
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.claimableAssetsBefore = claimableAssets;
        params.shouldSucceed = assets > 0;
    }

    function router7540FulfillPreconditions(uint256 controllerSeed, uint256 componentSeed)
        internal
        returns (RouterFulfillAsyncParams memory params)
    {
        address component = _selectERC7540Component(componentSeed);
        _ensureRouter7540Whitelist(component);

        address controller = USERS[controllerSeed % USERS.length];

        // Prepare user redeem request on node
        uint256 userAssets = fl.clamp(uint256(keccak256(abi.encodePacked(controller, componentSeed))), 200e18, 1_000e18);
        assetToken.mint(controller, userAssets);

        vm.startPrank(controller);
        asset.approve(address(node), type(uint256).max);
        node.deposit(userAssets, controller);
        node.requestRedeem(Math.max(node.balanceOf(controller) / 2, 1), controller, controller);
        vm.stopPrank();

        // Ensure liquidation queue prioritises component
        address[] memory queue = new address[](1);
        queue[0] = component;
        vm.startPrank(owner);
        node.setLiquidationQueue(queue);
        vm.stopPrank();

        uint256 claimableAssets = _prepareClaimableRedeems(component);
        (uint256 pending,,,) = node.requests(controller);

        params.controller = controller;
        params.component = component;
        params.pendingBefore = pending;
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));
        params.claimableAssetsBefore = claimableAssets;
        params.shouldSucceed = pending > 0 && claimableAssets > 0;
    }

    function router7540BatchWhitelistPreconditions(uint256 seed)
        internal
        returns (RouterBatchWhitelistParams memory params)
    {
        uint256 len = COMPONENTS_ERC7540.length;
        uint256 batch = len > 2 ? 2 : len;
        params.components = new address[](batch);
        params.statuses = new bool[](batch);

        for (uint256 i = 0; i < batch; ++i) {
            params.components[i] = COMPONENTS_ERC7540[(seed + i) % len];
            params.statuses[i] = ((seed >> i) & 1) == 0;
        }
        params.shouldSucceed = batch > 0;
    }

    function router7540SingleStatusPreconditions(uint256 seed, bool status)
        internal
        returns (RouterSingleStatusParams memory params)
    {
        params.component = _selectERC7540Component(seed);
        params.status = status;
        params.shouldSucceed = params.component != address(0);
    }

    function router7540TolerancePreconditions(uint256 seed)
        internal
        pure
        returns (RouterToleranceParams memory params)
    {
        params.newTolerance = seed % 1_000_000e18;
        params.shouldSucceed = true;
    }

    // =============================================================
    // INTERNAL HELPERS
    // =============================================================

    function _selectERC7540Component(uint256 seed) internal view returns (address component) {
        if (COMPONENTS_ERC7540.length == 0) {
            return address(0);
        }
        component = COMPONENTS_ERC7540[seed % COMPONENTS_ERC7540.length];
    }

    function _ensureRouter7540Whitelist(address component) internal {
        if (component == address(0)) return;
        vm.startPrank(owner);
        router7540.setWhitelistStatus(component, true);
        router7540.setBlacklistStatus(component, false);
        vm.stopPrank();
    }

    function _increaseNodeReserve7540(uint256 extraAssets) internal {
        assetToken.mint(address(node), extraAssets);
        vm.startPrank(rebalancer);
        node.updateTotalAssets();
        vm.stopPrank();
    }

    function _pendingDeposit(address component) internal view returns (uint256) {
        return ERC7540Mock(component).pendingDepositRequest(0, address(node));
    }

    function _pendingRedeem(address component) internal view returns (uint256) {
        return ERC7540Mock(component).pendingRedeemRequest(0, address(node));
    }

    function _prepareClaimableDeposits(address component) internal returns (uint256 claimableAssets) {
        if (component == address(0)) return 0;

        uint256 before = ERC7540Mock(component).claimableDepositRequest(0, address(node));
        if (before > 0) {
            return before;
        }

        _increaseNodeReserve7540(500_000e18);

        vm.startPrank(rebalancer);
        router7540.investInAsyncComponent(address(node), component);
        vm.stopPrank();

        vm.startPrank(poolManager);
        ERC7540Mock(component).processPendingDeposits();
        vm.stopPrank();

        claimableAssets = ERC7540Mock(component).claimableDepositRequest(0, address(node));
    }

    function _ensureNodeAsyncShares(address component) internal returns (uint256 shareBalance) {
        if (component == address(0)) return 0;

        shareBalance = IERC20(component).balanceOf(address(node));
        if (shareBalance > 0) {
            return shareBalance;
        }

        uint256 claimableAssets = _prepareClaimableDeposits(component);
        if (claimableAssets == 0) return 0;

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), component);
        vm.stopPrank();

        shareBalance = IERC20(component).balanceOf(address(node));
    }

    function _prepareClaimableRedeems(address component) internal returns (uint256 claimableAssets) {
        if (component == address(0)) return 0;

        claimableAssets = IERC7575(component).maxWithdraw(address(node));
        if (claimableAssets > 0) {
            return claimableAssets;
        }

        uint256 shareBalance = _ensureNodeAsyncShares(component);
        if (shareBalance == 0) return 0;

        uint256 sharesToRequest = shareBalance / 2 == 0 ? shareBalance : shareBalance / 2;
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), component, sharesToRequest);
        vm.stopPrank();

        vm.startPrank(poolManager);
        ERC7540Mock(component).processPendingRedemptions();
        vm.stopPrank();

        claimableAssets = IERC7575(component).maxWithdraw(address(node));
    }
}
