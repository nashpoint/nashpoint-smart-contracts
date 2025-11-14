// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {GatePolicyBlacklist} from "src/policies/GatePolicyBlacklist.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract GatePolicyBlacklistTest is BaseTest {
    GatePolicyBlacklist policy;

    function setUp() public override {
        super.setUp();

        policy = new GatePolicyBlacklist(address(registry));

        bytes4[] memory sigs = new bytes4[](9);
        sigs[0] = IERC7575.deposit.selector;
        sigs[1] = IERC7575.mint.selector;
        sigs[2] = INode.requestRedeem.selector;
        sigs[3] = IERC7575.withdraw.selector;
        sigs[4] = IERC7575.redeem.selector;
        sigs[5] = IERC20.transfer.selector;
        sigs[6] = IERC20.approve.selector;
        sigs[7] = IERC20.transferFrom.selector;
        sigs[8] = INode.setOperator.selector;
        address[] memory policies = new address[](sigs.length);
        for (uint256 i; i < sigs.length; i++) {
            policies[i] = address(policy);
        }

        _addPolicies(sigs, policies);
    }

    function _blacklist(address actor) internal {
        vm.prank(owner);
        policy.add(address(node), _toArray(actor));
    }

    function _unblacklist(address actor) internal {
        vm.prank(owner);
        policy.remove(address(node), _toArray(actor));
    }

    function test_depositBlockedWhenSenderBlacklisted() external {
        uint256 amount = 100 ether;

        _blacklist(user);
        _userDepositsWithRevert(user, amount, abi.encodeWithSelector(ErrorsLib.Blacklisted.selector));

        _unblacklist(user);
        _userDeposits(user, amount);

        _blacklist(user);
        _userDepositsWithRevert(user, 1 ether, abi.encodeWithSelector(ErrorsLib.Blacklisted.selector));
    }

    function test_depositBlockedForBlacklistedReceiver() external {
        uint256 amount = 10 ether;

        _blacklist(user2);

        vm.startPrank(user);
        asset.approve(address(node), amount);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.deposit(amount, user2);
        vm.stopPrank();

        _unblacklist(user2);

        vm.startPrank(user);
        asset.approve(address(node), amount);
        node.deposit(amount, user2);
        vm.stopPrank();
    }

    function test_mintBlockedWhenCallerBlacklisted() external {
        uint256 shares = 25 ether;

        vm.startPrank(user);
        asset.approve(address(node), shares);
        node.mint(shares, user);
        vm.stopPrank();

        _blacklist(user);

        vm.startPrank(user);
        asset.approve(address(node), shares);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.mint(shares, user);
        vm.stopPrank();
    }

    function test_requestRedeemBlockedWhenOwnerBlacklisted() external {
        uint256 shares = _userDeposits(user, 50 ether);

        _blacklist(user);

        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        _unblacklist(user);

        vm.startPrank(user);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();
    }

    function test_requestRedeemBlockedWhenOperatorCallerBlacklisted() external {
        uint256 shares = _userDeposits(user, 60 ether);

        vm.prank(user);
        node.setOperator(user3, true);

        vm.prank(user3);
        node.requestRedeem(shares / 3, user, user);

        _blacklist(user3);

        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.requestRedeem(shares / 3, user, user);
        vm.stopPrank();
    }

    function test_withdrawBlockedWhenControllerOrReceiverBlacklisted() external {
        uint256 amount = 60 ether;
        uint256 shares = _userDeposits(user, amount);
        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        vm.prank(user);
        node.withdraw(5 ether, user, user);

        _blacklist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.withdraw(5 ether, user, user);
        vm.stopPrank();

        _unblacklist(user);
        _blacklist(randomUser);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.withdraw(5 ether, randomUser, user);
        vm.stopPrank();

        _unblacklist(randomUser);
        vm.prank(user);
        node.withdraw(5 ether, randomUser, user);
    }

    function test_withdrawBlockedWhenOperatorCallerBlacklisted() external {
        uint256 amount = 40 ether;
        uint256 shares = _userDeposits(user, amount);
        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        vm.prank(user);
        node.setOperator(user3, true);

        vm.prank(user3);
        node.withdraw(5 ether, user, user);

        _blacklist(user3);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.withdraw(1 ether, user, user);
        vm.stopPrank();
    }

    function test_redeemBlockedWhenControllerOrReceiverBlacklisted() external {
        uint256 amount = 40 ether;
        uint256 shares = _userDeposits(user, amount);

        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        _blacklist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.redeem(shares / 4, user, user);
        vm.stopPrank();

        _unblacklist(user);
        _blacklist(randomUser);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.redeem(shares / 4, randomUser, user);
        vm.stopPrank();

        _unblacklist(randomUser);
        vm.prank(user);
        node.redeem(shares / 4, randomUser, user);
    }

    function test_redeemBlockedWhenOperatorCallerBlacklisted() external {
        uint256 amount = 50 ether;
        uint256 shares = _userDeposits(user, amount);

        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        vm.prank(user);
        node.setOperator(user3, true);

        vm.prank(user3);
        node.redeem(shares / 5, user, user);

        _blacklist(user3);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.redeem(shares / 5, user, user);
        vm.stopPrank();
    }

    function test_transferBlockedWhenParticipantsBlacklisted() external {
        uint256 amount = 30 ether;
        uint256 shares = _userDeposits(user, amount);

        vm.prank(user);
        node.transfer(user2, shares / 2);

        _blacklist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.transfer(user2, shares / 2);
        vm.stopPrank();

        _unblacklist(user);
        _blacklist(user2);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.transfer(user2, shares / 2);
        vm.stopPrank();

        _unblacklist(user2);
        vm.prank(user);
        node.transfer(user2, shares / 2);
    }

    function test_approveBlockedWhenOwnerOrSpenderBlacklisted() external {
        uint256 amount = 20 ether;
        _userDeposits(user, amount);

        vm.prank(user);
        node.approve(user3, amount);

        _blacklist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.approve(user3, amount);
        vm.stopPrank();

        _unblacklist(user);
        _blacklist(user3);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.approve(user3, amount);
        vm.stopPrank();

        _unblacklist(user3);
        vm.prank(user);
        node.approve(user3, amount);
        assertEq(node.allowance(user, user3), amount);
    }

    function test_transferFromBlockedWhenAnyParticipantBlacklisted() external {
        uint256 amount = 80 ether;
        uint256 shares = _userDeposits(user, amount);

        vm.prank(user);
        node.approve(user3, shares);

        _blacklist(user3);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.transferFrom(user, randomUser, shares / 4);
        vm.stopPrank();

        _unblacklist(user3);
        _blacklist(user);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.transferFrom(user, randomUser, shares / 4);
        vm.stopPrank();

        _unblacklist(user);
        _blacklist(randomUser);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.transferFrom(user, randomUser, shares / 4);
        vm.stopPrank();

        _unblacklist(randomUser);
        vm.prank(user3);
        node.transferFrom(user, randomUser, shares / 4);
    }

    function test_setOperatorBlocksBlacklistedParticipants() external {
        address operator = user2;

        _blacklist(owner);
        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.setOperator(operator, true);
        vm.stopPrank();

        _unblacklist(owner);

        vm.prank(owner);
        assertTrue(node.setOperator(operator, true));
        assertTrue(node.isOperator(owner, operator));

        _blacklist(operator);

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        node.setOperator(operator, false);
        vm.stopPrank();

        _unblacklist(operator);

        vm.prank(owner);
        assertTrue(node.setOperator(operator, false));
        assertFalse(node.isOperator(owner, operator));
    }
}
