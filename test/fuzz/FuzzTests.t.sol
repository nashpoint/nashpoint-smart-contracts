// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";

contract FuzzTests is BaseTest {
    function test_redeem(uint256 assets) public {
        vm.assume(assets > 0);

        _seedNode(1);

        uint256 shares = node.convertToShares(assets);
        deal(address(asset), address(user), assets);

        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);

        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        node.redeem(shares, user, user);

        _verifySuccessfulExit(user, assets, 1);
    }

    function test_withdraw(uint256 assets) public {
        vm.assume(assets > 0);

        _seedNode(1);

        uint256 shares = node.convertToShares(assets);
        deal(address(asset), address(user), assets);

        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);

        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        node.withdraw(assets, user, user);

        _verifySuccessfulExit(user, assets, 1);
    }

    // Helper functions
    function _verifySuccessfulEntry(address user, uint256 assets, uint256 shares) internal view {
        assertEq(asset.balanceOf(address(node)), assets);
        assertEq(asset.balanceOf(user), 0);
        assertEq(node.balanceOf(user), shares);
        assertEq(asset.balanceOf(address(escrow)), 0);
    }

    function _verifySuccessfulExit(address user, uint256 assets, uint256 initialBalance) internal view {
        assertEq(asset.balanceOf(address(node)), initialBalance);
        assertEq(asset.balanceOf(user), assets);
        assertEq(node.balanceOf(user), 0);
        assertEq(asset.balanceOf(address(escrow)), 0);
    }
}
