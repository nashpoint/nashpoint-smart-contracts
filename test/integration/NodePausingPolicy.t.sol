// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {NodePausingPolicy} from "src/policies/NodePausingPolicy.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract NodePausingPolicyTest is BaseTest {
    NodePausingPolicy policy;

    function setUp() public override {
        super.setUp();

        policy = new NodePausingPolicy(address(registry));

        bytes4[] memory sigs = new bytes4[](3);
        sigs[0] = IERC7575.deposit.selector;
        sigs[1] = IERC7575.mint.selector;
        sigs[2] = INode.requestRedeem.selector;
        address[] memory policies = new address[](3);
        policies[0] = address(policy);
        policies[1] = address(policy);
        policies[2] = address(policy);

        _addPolicies(sigs, policies);

        address[] memory actors = _toArray(owner);
        vm.prank(owner);
        policy.add(address(node), actors);
    }

    function test_pauseGlobalBlocksActions() external {
        uint256 amount = 10 ether;

        _userDeposits(user, amount);

        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        policy.pauseGlobal(address(node));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit NodePausingPolicy.GlobalPaused(address(node));
        policy.pauseGlobal(address(node));

        _userDepositsWithRevert(user, amount, abi.encodeWithSelector(NodePausingPolicy.GlobalPause.selector));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit NodePausingPolicy.GlobalUnpaused(address(node));
        policy.unpauseGlobal(address(node));

        _userDeposits(user, amount);
    }

    function test_pauseSelectorsBlocksSpecificAction() external {
        uint256 amount = 5 ether;

        _userDeposits(user, amount);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IERC7575.deposit.selector;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit NodePausingPolicy.SelectorsPaused(address(node), selectors);
        policy.pauseSigs(address(node), selectors);

        _userDepositsWithRevert(
            user, amount, abi.encodeWithSelector(NodePausingPolicy.SigPause.selector, IERC7575.deposit.selector)
        );

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit NodePausingPolicy.SelectorsUnpaused(address(node), selectors);
        policy.unpauseSigs(address(node), selectors);

        _userDeposits(user, amount);
    }

    function test_pauseRequestRedeem() external {
        uint256 shares = _userDeposits(user, 20 ether);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = INode.requestRedeem.selector;

        vm.prank(owner);
        policy.pauseSigs(address(node), selectors);

        vm.startPrank(user);
        node.approve(address(node), shares);
        vm.expectRevert(abi.encodeWithSelector(NodePausingPolicy.SigPause.selector, INode.requestRedeem.selector));
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(owner);
        policy.unpauseSigs(address(node), selectors);

        vm.startPrank(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();
    }
}
