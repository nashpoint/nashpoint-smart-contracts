// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";

contract NodeFuzzTest is BaseTest {
    uint256 public maxDeposit;

    function setUp() public override {
        super.setUp();
        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.MAX_DEPOSIT();
    }

    function test_fuzz_node_large_deposit(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        seedAmount = bound(seedAmount, 1, 100);
        _seedNode(seedAmount);

        deal(address(asset), address(user), depositAmount);
        deal(address(asset), address(user2), depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 userAssets = node.convertToAssets(node.balanceOf(address(user)));
        assertEq(userAssets, depositAmount);

        vm.startPrank(user2);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user2);
        vm.stopPrank();

        uint256 user2Assets = node.convertToAssets(node.balanceOf(address(user2)));
        assertEq(user2Assets, depositAmount);

        assertEq(userAssets, user2Assets);
    }

    function test_fuzz_node_large_mint(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        seedAmount = bound(seedAmount, 1, 100);
        _seedNode(seedAmount);

        deal(address(asset), address(user), depositAmount);
        deal(address(asset), address(user2), depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.mint(node.convertToShares(depositAmount), user);
        vm.stopPrank();

        uint256 userShares = (node.balanceOf(address(user)));
        assertEq(userShares, node.convertToShares(depositAmount));

        vm.startPrank(user2);
        asset.approve(address(node), depositAmount);
        node.mint(node.convertToShares(depositAmount), user2);
        vm.stopPrank();

        uint256 user2Shares = (node.balanceOf(address(user2)));
        assertEq(user2Shares, node.convertToShares(depositAmount));

        assertEq(userShares, user2Shares);
    }

    function test_fuzz_node_requestRedeem_partial_redeem(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        deal(address(asset), address(user), depositAmount);

        seedAmount = bound(seedAmount, 1, 100);
        _seedNode(seedAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 userBalance = node.balanceOf(address(user));
        uint256 sharesToRedeem = bound(depositAmount, 1, userBalance - 1);

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);

        assertEq(node.pendingRedeemRequest(0, user), sharesToRedeem);

        vm.startPrank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableAssets = node.maxWithdraw(user);
        uint256 pendingAssets = node.convertToAssets(node.pendingRedeemRequest(0, user));
        uint256 userAssets = asset.balanceOf(address(user));
        uint256 userShares = node.balanceOf(address(user));

        assertEq(claimableAssets + pendingAssets + userAssets + node.convertToAssets(userShares), depositAmount);
    }

    function test_fuzz_node_requestRedeem_full(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        deal(address(asset), address(user), depositAmount);

        seedAmount = bound(seedAmount, 1, 100);
        _seedNode(seedAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 sharesToRedeem = node.balanceOf(address(user));

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);

        assertEq(node.pendingRedeemRequest(0, user), sharesToRedeem);

        vm.startPrank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableAssets = node.maxWithdraw(user);
        uint256 pendingAssets = node.convertToAssets(node.pendingRedeemRequest(0, user));
        uint256 userAssets = asset.balanceOf(address(user));
        uint256 userShares = node.balanceOf(address(user));

        assertEq(claimableAssets, depositAmount);
        assertEq(pendingAssets, 0);
        assertEq(userShares, 0);
        assertEq(userAssets, 0);
    }

    // todo:
    function test_fuzz_node_fulfillRedeem_invalid_inputs() public {}

    function test_fuzz_node_withdaw_large_amount() public {}

    function test_fuzz_node_withdraw_invalid_input() public {}

    function test_fuzz_node_redeem_large_amount() public {}

    function test_fuzz_node_redeem_invalid_input() public {}

    function test_fuzz_node_payManagementFees(uint256 annualFee, uint256 protocolFee, uint256 seedAmount) public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        annualFee = bound(annualFee, 0, 1e18);
        protocolFee = bound(protocolFee, 0, 1e18);
        seedAmount = bound(seedAmount, 1e18, 1e36);

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(annualFee);
        registry.setProtocolManagementFee(protocolFee);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(seedAmount);
        assertEq(node.totalAssets(), seedAmount);

        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        uint256 feeForPeriod = node.payManagementFees();
        uint256 expectedFee = annualFee * seedAmount / 1e18;

        assertEq(feeForPeriod, expectedFee);
        assertEq(
            asset.balanceOf(address(ownerFeesRecipient)) + asset.balanceOf(address(protocolFeesRecipient)), expectedFee
        );
        assertEq(node.totalAssets(), seedAmount - feeForPeriod);
    }

    // todo: management fees

    function test_fuzz_node_payManagementFees_different_durations() public {}

    // todo: totalAsset & updating cache

    function test_fuzz_node_component_earns_interest() public {}

    function test_fuzz_node_component_loses_values() public {}

    // todo: swing pricing

    function test_fuzz_node_random_swing_price() public {
        // make sure to check the preview functions here
    }

    function test_fuzz_node_vault_attack() public {}

    // todo: component management

    // figure out what to test here later
}
