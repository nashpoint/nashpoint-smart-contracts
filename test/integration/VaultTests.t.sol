// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {Node, ComponentAllocation} from "src/Node.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract VaultTests is BaseTest {
    ERC20Mock internal mockAsset;

    function setUp() public override {
        super.setUp();
        mockAsset = ERC20Mock(address(asset));
    }

    function test_VaultTests_depositAndWithdraw() public {
        _seedNode(1000 ether);
        uint256 startingBalance = asset.balanceOf(address(user));
        uint256 expectedShares = node.previewDeposit(100 ether);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether); // @note this approval ok
        node.deposit(100 ether, user);
        vm.stopPrank();

        // check user got the right shares
        uint256 userShares = node.balanceOf(address(user));
        assertEq(userShares, expectedShares);

        // check accounts ended up with the correct balances
        assertEq(node.totalAssets(), 100 ether + 1000 ether);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        // check convertToAssets & convertToShares work properly
        assertEq(asset.balanceOf(address(node)) - 1000 ether, node.convertToAssets(userShares));
        assertEq(userShares, node.convertToShares(asset.balanceOf(address(node)) - 1000 ether));

        // start redemption flow
        vm.startPrank(user);
        node.approve(address(node), userShares);
        node.requestRedeem(userShares, user, user); // @note this approval ok
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), userShares);
        assertEq(node.balanceOf(address(user)), 0);
        assertEq(node.totalAssets(), 1000 ether + 100 ether);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        uint256 pendingRedeemRequest = node.pendingRedeemRequest(0, user);
        assertEq(pendingRedeemRequest, node.convertToShares(100 ether));

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableRedeemRequest = node.claimableRedeemRequest(0, user);
        assertEq(claimableRedeemRequest, node.convertToShares(100 ether));

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));
        assertEq(asset.balanceOf(address(escrow)), 100 ether);

        vm.prank(user);
        node.withdraw(100 ether, user, user);

        assertEq(asset.balanceOf(address(user)), startingBalance);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(node.totalAssets(), 1000 ether);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));

        uint256 claimableAssets;

        (pendingRedeemRequest, claimableRedeemRequest, claimableAssets) = node.requests(user);
        assertEq(pendingRedeemRequest, 0);
        assertEq(claimableRedeemRequest, 0);
        assertEq(claimableAssets, 0);
    }

    function test_VaultTests_mintAndRedeem() public {
        _seedNode(1000 ether);
        uint256 startingBalance = asset.balanceOf(address(user));
        uint256 expectedAssets = node.previewMint(100 ether);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether); // @note this approval ok
        node.mint(100 ether, user);
        vm.stopPrank();

        // check user got the right shares
        uint256 userBalance = node.convertToAssets(node.balanceOf(address(user)));
        assertEq(userBalance, expectedAssets);

        // check accounts ended up with the correct balances
        assertEq(node.totalAssets(), 100 ether + 1000 ether);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        // check convertToShares work properly
        assertEq(node.totalSupply(), node.convertToShares(expectedAssets + 1000 ether));
        assertEq(node.totalAssets(), expectedAssets + 1000 ether);

        // start redemption flow
        vm.startPrank(user);
        node.approve(address(node), type(uint256).max);
        node.requestRedeem(node.balanceOf(user), user, user);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), node.convertToShares(expectedAssets));
        assertEq(node.balanceOf(address(user)), 0);
        assertEq(node.totalAssets(), 1000 ether + 100 ether);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        uint256 pendingRedeemRequest = node.pendingRedeemRequest(0, user);
        assertEq(pendingRedeemRequest, node.convertToShares(100 ether));

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableRedeemRequest = node.claimableRedeemRequest(0, user);
        assertEq(claimableRedeemRequest, expectedAssets);

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));
        assertEq(asset.balanceOf(address(escrow)), 100 ether);

        vm.prank(user);
        node.redeem(100 ether, user, user);

        assertEq(asset.balanceOf(address(user)), startingBalance);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(node.totalAssets(), 1000 ether);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));

        uint256 claimableAssets;

        (pendingRedeemRequest, claimableRedeemRequest, claimableAssets) = node.requests(user);
        assertEq(pendingRedeemRequest, 0);
        assertEq(claimableRedeemRequest, 0);
        assertEq(claimableAssets, 0);
    }

    function test_VaultTests_investsToVault() public {
        _seedNode(100 ether);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        assertEq(vault.balanceOf(address(node)), 90 ether);
        assertEq(asset.balanceOf(address(vault)), 90 ether);
        assertEq(asset.balanceOf(address(node)), 10 ether);
        assertEq(node.balanceOf(address(vault)), 0);
        assertEq(node.totalAssets(), 10 ether + 90 ether);
    }

    function test_fulfilRedeemRequest_4626Router() public {
        address[] memory components = node.getComponents();

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.setLiquidationQueue(components);
        node.updateTargetReserveRatio(0);
        node.updateComponentAllocation(address(vault), 1 ether, 0, address(router4626));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        assertEq(asset.balanceOf(address(node)), 0);
        assertEq(asset.balanceOf(address(vault)), 100 ether);
        assertEq(node.balanceOf(user), 100 ether);
        assertEq(node.totalAssets(), 100 ether);
        assertEq(node.balanceOf(address(escrow)), 0);

        vm.startPrank(user);
        node.approve(address(node), 50 ether);
        node.requestRedeem(50 ether, user, user);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), 50 ether);
        assertEq(node.balanceOf(user), 50 ether);
        assertEq(node.totalAssets(), 100 ether);
        assertEq(node.totalSupply(), 100 ether);
        assertEq(asset.balanceOf(address(vault)), 100 ether);

        (uint256 sharesPending,,) = node.requests(user);

        assertEq(sharesPending, 50 ether);

        vm.startPrank(rebalancer);
        router4626.fulfillRedeemRequest(address(node), user, address(vault), 0);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.claimableRedeemRequest(0, user), 50 ether);
        assertEq(asset.balanceOf(address(vault)), 50 ether);
        assertEq(asset.balanceOf(address(escrow)), 50 ether);
        assertEq(asset.balanceOf(address(node)), 0);
        assertEq(node.totalAssets(), 50 ether);
        assertEq(node.totalSupply(), 50 ether);

        (sharesPending,,) = node.requests(user);
        assertEq(sharesPending, 0);

        vm.startPrank(user);
        node.approve(address(node), 50 ether);
        node.requestRedeem(50 ether, user, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.fulfillRedeemRequest(address(node), user, address(vault), 0);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.claimableRedeemRequest(0, user), 100 ether);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(address(escrow)), 100 ether);
        assertEq(asset.balanceOf(address(node)), 0);
        assertEq(node.totalAssets(), 0);
        assertEq(node.totalSupply(), 0);

        (sharesPending,,) = node.requests(user);
        assertEq(sharesPending, 0);
    }
}
