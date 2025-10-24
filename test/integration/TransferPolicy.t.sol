// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TransferPolicy} from "src/policies/TransferPolicy.sol";
import {WhitelistBase} from "src/policies/WhitelistBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract TransferPolicyTest is BaseTest {
    TransferPolicy policy;

    function setUp() public override {
        super.setUp();

        policy = new TransferPolicy(address(registry));

        bytes4[] memory sigs = new bytes4[](3);
        sigs[0] = IERC20.transfer.selector;
        sigs[1] = IERC20.approve.selector;
        sigs[2] = IERC20.transferFrom.selector;
        address[] memory policies = new address[](3);
        policies[0] = address(policy);
        policies[1] = address(policy);
        policies[2] = address(policy);

        _addPolicies(sigs, policies);
    }

    function test_manageWhitelist() external {
        address[] memory users = _toArray(user);

        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        policy.add(address(0x1234), users);

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.add(address(node), users);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit WhitelistBase.WhitelistAdded(address(node), users);
        policy.add(address(node), users);
        assertTrue(policy.whitelist(address(node), user));

        vm.expectEmit(true, true, true, true);
        emit WhitelistBase.WhitelistRemoved(address(node), users);
        policy.remove(address(node), users);
        assertFalse(policy.whitelist(address(node), user));
        vm.stopPrank();

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.remove(address(node), users);
    }

    function test_TransferPolicy_onCheck() external {
        uint256 depositAmount = 100e18;
        uint256 shares = _userDeposits(user, depositAmount);
        uint256 transferAmount = shares / 2;

        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        vm.prank(user);
        node.transfer(user2, transferAmount);

        address[] memory initialWhitelist = _toArrayTwo(user, user2);
        vm.prank(owner);
        policy.add(address(node), initialWhitelist);

        vm.prank(user);
        node.transfer(user2, transferAmount);

        assertEq(node.balanceOf(user), shares - transferAmount);
        assertEq(node.balanceOf(user2), transferAmount);

        uint256 approveAmount = transferAmount / 2;
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        vm.prank(user);
        node.approve(user3, approveAmount);

        address[] memory whitelistSpender = _toArray(user3);
        vm.prank(owner);
        policy.add(address(node), whitelistSpender);

        vm.prank(user);
        node.approve(user3, approveAmount);
        assertEq(node.allowance(user, user3), approveAmount);

        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        vm.prank(user3);
        node.transferFrom(user, randomUser, approveAmount);

        address[] memory whitelistReceiver = _toArray(randomUser);
        vm.prank(owner);
        policy.add(address(node), whitelistReceiver);

        vm.prank(user3);
        node.transferFrom(user, randomUser, approveAmount);

        assertEq(node.balanceOf(randomUser), approveAmount);
        assertEq(node.balanceOf(user), shares - transferAmount - approveAmount);
    }
}
