// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";

import {CapPolicy} from "src/policies/CapPolicy.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract CapPolicyTest is BaseTest {
    CapPolicy policy;

    function setUp() public override {
        super.setUp();

        policy = new CapPolicy(address(registry));

        bytes4[] memory sigs = new bytes4[](2);
        sigs[0] = IERC7575.deposit.selector;
        sigs[1] = IERC7575.mint.selector;
        address[] memory policies = new address[](2);
        policies[0] = address(policy);
        policies[1] = address(policy);

        _addPolicies(sigs, policies);
    }

    function test_setCap() external {
        uint256 amount = 1000e18;

        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        policy.setCap(address(0x1234), amount);

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.setCap(address(node), amount);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit CapPolicy.CapChange(address(node), amount);
        policy.setCap(address(node), amount);

        assertEq(policy.nodeCap(address(node)), amount);
    }

    function test_CapPolicy_onCheck() external {
        uint256 cap = 1000e18;

        vm.prank(owner);
        policy.setCap(address(node), cap);

        _userDeposits(user, 100e18);

        _userDepositsWithRevert(user, 1100e18, abi.encodeWithSelector(CapPolicy.CapExceeded.selector, 200e18));
    }
}
