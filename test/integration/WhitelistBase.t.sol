// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WhitelistBase} from "src/policies/WhitelistBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract WhitelistBaseHarness is WhitelistBase {
    constructor(address registry_) WhitelistBase(registry_) {}

    function checkIsWhitelistedOne(address node) external view onlyWhitelisted(node, msg.sender) {}

    function checkIsWhitelistedTwo(address user) external view onlyWhitelisted(msg.sender, user) {}

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view override {}
}

contract WhitelistBaseTest is BaseTest {
    WhitelistBaseHarness policy;

    function setUp() public override {
        super.setUp();

        policy = new WhitelistBaseHarness(address(registry));

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

        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        policy.checkIsWhitelistedOne(address(node));
        vm.stopPrank();

        vm.startPrank(address(node));
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        policy.checkIsWhitelistedTwo(user);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit WhitelistBase.WhitelistAdded(address(node), users);
        policy.add(address(node), users);
        assertTrue(policy.whitelist(address(node), user));
        vm.stopPrank();

        vm.startPrank(user);
        policy.checkIsWhitelistedOne(address(node));
        vm.stopPrank();

        vm.startPrank(address(node));
        policy.checkIsWhitelistedTwo(user);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit WhitelistBase.WhitelistRemoved(address(node), users);
        policy.remove(address(node), users);
        assertFalse(policy.whitelist(address(node), user));
        vm.stopPrank();

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.remove(address(node), users);
    }
}
