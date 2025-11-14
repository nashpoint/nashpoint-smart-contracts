// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {GatePolicyWhitelist} from "src/policies/GatePolicyWhitelist.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract GatePolicyWhitelistTest is BaseTest {
    GatePolicyWhitelist policy;

    function setUp() public override {
        super.setUp();

        policy = new GatePolicyWhitelist(address(registry));

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

    function _addToWhitelist(address actor) internal {
        address[] memory actors = _toArray(actor);
        vm.prank(owner);
        policy.add(address(node), actors);
    }

    function _removeFromWhitelist(address actor) internal {
        address[] memory actors = _toArray(actor);
        vm.prank(owner);
        policy.remove(address(node), actors);
    }

    function test_depositEnforcesWhitelist() external {
        uint256 amount = 100 ether;

        _userDepositsWithRevert(user, amount, abi.encodeWithSelector(ErrorsLib.NotWhitelisted.selector));

        _addToWhitelist(user);
        _userDeposits(user, amount);

        vm.prank(owner);
        policy.remove(address(node), _toArray(user));

        _userDepositsWithRevert(user, 1 ether, abi.encodeWithSelector(ErrorsLib.NotWhitelisted.selector));
    }

    function test_depositRequiresWhitelistedReceiver() external {
        uint256 amount = 10 ether;
        _addToWhitelist(user);

        vm.startPrank(user);
        asset.approve(address(node), amount);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.deposit(amount, user2);
        vm.stopPrank();

        _addToWhitelist(user2);

        vm.startPrank(user);
        asset.approve(address(node), amount);
        node.deposit(amount, user2);
        vm.stopPrank();
    }

    function test_mintRequiresWhitelist() external {
        uint256 shares = 25 ether;

        vm.startPrank(user);
        asset.approve(address(node), shares);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.mint(shares, user);
        vm.stopPrank();

        _addToWhitelist(user);

        vm.startPrank(user);
        asset.approve(address(node), shares);
        node.mint(shares, user);
        vm.stopPrank();
    }

    function test_requestRedeemRequiresOwnerWhitelisted() external {
        _addToWhitelist(user);
        uint256 shares = _userDeposits(user, 50 ether);

        _removeFromWhitelist(user);

        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        _addToWhitelist(user);

        vm.startPrank(user);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();
    }

    function test_requestRedeemRequiresOperatorCallerWhitelisted() external {
        _addToWhitelist(user);
        _addToWhitelist(user3);
        uint256 shares = _userDeposits(user, 60 ether);

        vm.prank(user);
        node.setOperator(user3, true);

        vm.prank(user3);
        node.requestRedeem(shares / 3, user, user);

        _removeFromWhitelist(user3);

        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.requestRedeem(shares / 3, user, user);
        vm.stopPrank();
    }

    function test_withdrawRequiresWhitelistedReceiverAndController() external {
        uint256 amount = 60 ether;
        _addToWhitelist(user);
        uint256 shares = _userDeposits(user, amount);

        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        _removeFromWhitelist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.withdraw(10 ether, user, user);
        vm.stopPrank();

        _addToWhitelist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.withdraw(5 ether, randomUser, user);
        vm.stopPrank();

        _addToWhitelist(randomUser);
        vm.prank(user);
        node.withdraw(5 ether, randomUser, user);
    }

    function test_withdrawRequiresOperatorCallerWhitelisted() external {
        uint256 amount = 40 ether;
        _addToWhitelist(user);
        _addToWhitelist(user3);
        _addToWhitelist(randomUser);
        uint256 shares = _userDeposits(user, amount);

        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        vm.prank(user);
        node.setOperator(user3, true);

        vm.prank(user3);
        node.withdraw(5 ether, randomUser, user);

        _removeFromWhitelist(user3);

        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.withdraw(1 ether, randomUser, user);
        vm.stopPrank();
    }

    function test_redeemRequiresWhitelistedReceiverAndController() external {
        uint256 amount = 40 ether;
        _addToWhitelist(user);
        uint256 shares = _userDeposits(user, amount);

        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        _removeFromWhitelist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.redeem(shares / 4, user, user);
        vm.stopPrank();

        _addToWhitelist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.redeem(shares / 4, randomUser, user);
        vm.stopPrank();

        _addToWhitelist(randomUser);
        vm.prank(user);
        node.redeem(shares / 4, randomUser, user);
    }

    function test_redeemRequiresOperatorCallerWhitelisted() external {
        uint256 amount = 50 ether;
        _addToWhitelist(user);
        _addToWhitelist(user3);
        _addToWhitelist(randomUser);
        uint256 shares = _userDeposits(user, amount);

        _userRequestsRedeem(user, shares);
        _fullfilFromReserve(user);

        vm.prank(user);
        node.setOperator(user3, true);

        vm.prank(user3);
        node.redeem(shares / 5, randomUser, user);

        _removeFromWhitelist(user3);

        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.redeem(shares / 5, randomUser, user);
        vm.stopPrank();
    }

    function test_transferRequiresWhitelistedSenderAndReceiver() external {
        uint256 amount = 30 ether;
        _addToWhitelist(user);
        _addToWhitelist(user2);
        uint256 shares = _userDeposits(user, amount);

        _removeFromWhitelist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.transfer(user2, shares / 2);
        vm.stopPrank();

        _addToWhitelist(user);
        _removeFromWhitelist(user2);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.transfer(user2, shares / 2);
        vm.stopPrank();

        _addToWhitelist(user2);
        vm.prank(user);
        node.transfer(user2, shares / 2);
    }

    function test_approveRequiresWhitelistedOwnerAndSpender() external {
        uint256 amount = 20 ether;
        _addToWhitelist(user);
        _addToWhitelist(user3);
        _userDeposits(user, amount);

        _removeFromWhitelist(user);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.approve(user3, amount);
        vm.stopPrank();

        _addToWhitelist(user);
        _removeFromWhitelist(user3);
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.approve(user3, amount);
        vm.stopPrank();

        _addToWhitelist(user3);
        vm.prank(user);
        node.approve(user3, amount);
        assertEq(node.allowance(user, user3), amount);
    }

    function test_transferFromRequiresAllParticipantsWhitelisted() external {
        uint256 amount = 80 ether;
        _addToWhitelist(user);
        _addToWhitelist(user3);
        _addToWhitelist(randomUser);
        uint256 shares = _userDeposits(user, amount);

        vm.prank(user);
        node.approve(user3, shares);

        _removeFromWhitelist(user3);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.transferFrom(user, randomUser, shares / 4);
        vm.stopPrank();

        _addToWhitelist(user3);
        _removeFromWhitelist(user);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.transferFrom(user, randomUser, shares / 4);
        vm.stopPrank();

        _addToWhitelist(user);
        _removeFromWhitelist(randomUser);
        vm.startPrank(user3);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.transferFrom(user, randomUser, shares / 4);
        vm.stopPrank();

        _addToWhitelist(randomUser);
        vm.prank(user3);
        node.transferFrom(user, randomUser, shares / 4);
    }

    function test_setOperatorRequiresWhitelistedParticipants() external {
        address operator = user2;

        _addToWhitelist(owner);

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.setOperator(operator, true);
        vm.stopPrank();

        _addToWhitelist(operator);

        vm.prank(owner);
        assertTrue(node.setOperator(operator, true));
        assertTrue(node.isOperator(owner, operator));

        _removeFromWhitelist(owner);
        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.setOperator(operator, false);
        vm.stopPrank();

        _addToWhitelist(owner);
        _removeFromWhitelist(operator);
        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.setOperator(operator, false);
        vm.stopPrank();

        _addToWhitelist(operator);
        vm.prank(owner);
        assertTrue(node.setOperator(operator, false));
        assertFalse(node.isOperator(owner, operator));
    }
}
