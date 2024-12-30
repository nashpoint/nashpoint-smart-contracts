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
    function test_fuzz_node_large_deposit(uint256 depositAmount, uint256 seedAmount) public {
        Node nodeImpl = Node(address(node));
        uint256 maxDeposit = nodeImpl.MAX_DEPOSIT();

        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        vm.assume(seedAmount < 10);
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
        Node nodeImpl = Node(address(node));
        uint256 maxDeposit = nodeImpl.MAX_DEPOSIT();

        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        vm.assume(seedAmount < 10);
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
}
