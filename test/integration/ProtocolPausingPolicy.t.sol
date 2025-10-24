// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {ProtocolPausingPolicy} from "src/policies/ProtocolPausingPolicy.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract ProtocolPausingPolicyTest is BaseTest {
    ProtocolPausingPolicy policy;

    function setUp() public override {
        super.setUp();

        policy = new ProtocolPausingPolicy(address(registry));

        bytes4[] memory sigs = new bytes4[](3);
        sigs[0] = IERC7575.deposit.selector;
        sigs[1] = IERC7575.mint.selector;
        sigs[2] = INode.requestRedeem.selector;
        address[] memory policies = new address[](3);
        policies[0] = address(policy);
        policies[1] = address(policy);
        policies[2] = address(policy);

        _addPolicies(sigs, policies);

        address[] memory operators = _toArray(owner);
        vm.prank(owner);
        policy.add(operators);
    }

    function test_addRemoveWhitelist() external {
        address[] memory users = _toArray(user);

        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        vm.prank(user);
        policy.add(users);

        vm.expectEmit(false, false, false, true);
        emit ProtocolPausingPolicy.WhitelistAdded(users);
        vm.prank(owner);
        policy.add(users);
        assertTrue(policy.whitelist(user));

        vm.expectEmit(false, false, false, true);
        emit ProtocolPausingPolicy.WhitelistRemoved(users);
        vm.prank(owner);
        policy.remove(users);
        assertFalse(policy.whitelist(user));
    }

    function test_globalPauseBlocksActions() external {
        uint256 amount = 10 ether;
        _userDeposits(user, amount);

        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        vm.prank(randomUser);
        policy.pauseGlobal();

        vm.expectEmit(false, false, false, true);
        emit ProtocolPausingPolicy.GlobalPaused();
        vm.prank(owner);
        policy.pauseGlobal();

        _userDepositsWithRevert(user, 1 ether, abi.encodeWithSelector(ProtocolPausingPolicy.GlobalPause.selector));

        vm.expectEmit(false, false, false, true);
        emit ProtocolPausingPolicy.GlobalUnpaused();
        vm.prank(owner);
        policy.unpauseGlobal();

        _userDeposits(user, 2 ether);
    }

    function test_selectorPauseBlocksOnlyTarget() external {
        uint256 amount = 5 ether;
        _addUserToWhitelist(user);

        _userDeposits(user, amount);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IERC7575.deposit.selector;

        vm.expectEmit(false, false, false, true);
        emit ProtocolPausingPolicy.SelectorsPaused(selectors);
        vm.prank(owner);
        policy.pauseSigs(selectors);

        _userDepositsWithRevert(
            user, amount, abi.encodeWithSelector(ProtocolPausingPolicy.SigPause.selector, IERC7575.deposit.selector)
        );

        vm.expectEmit(false, false, false, true);
        emit ProtocolPausingPolicy.SelectorsUnpaused(selectors);
        vm.prank(owner);
        policy.unpauseSigs(selectors);

        _userDeposits(user, amount);
    }

    function test_requestRedeemBlockedWhenSelectorPaused() external {
        _addUserToWhitelist(user);
        uint256 shares = _userDeposits(user, 20 ether);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = INode.requestRedeem.selector;

        vm.prank(owner);
        policy.pauseSigs(selectors);

        vm.startPrank(user);
        node.approve(address(node), shares);
        vm.expectRevert(abi.encodeWithSelector(ProtocolPausingPolicy.SigPause.selector, INode.requestRedeem.selector));
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(owner);
        policy.unpauseSigs(selectors);

        vm.startPrank(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();
    }

    function _addUserToWhitelist(address actor) internal {
        address[] memory actors = _toArray(actor);
        vm.prank(owner);
        policy.add(actors);
    }
}
