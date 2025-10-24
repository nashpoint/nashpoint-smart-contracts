// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {GatePolicy} from "src/policies/GatePolicy.sol";
import {WhitelistBase} from "src/policies/WhitelistBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract GatePolicyHarness is GatePolicy {
    constructor(address registry_) GatePolicy(registry_) {}

    function exposedGetLeaf(address actor) external pure returns (bytes32) {
        return _getLeaf(actor);
    }

    function getProof(address node, address actor) external view returns (bytes32[] memory) {
        return proofs[node][actor];
    }
}

contract GatePolicyTest is BaseTest {
    GatePolicyHarness policy;

    function setUp() public override {
        super.setUp();

        policy = new GatePolicyHarness(address(registry));

        bytes4[] memory sigs = new bytes4[](3);
        sigs[0] = IERC7575.deposit.selector;
        sigs[1] = IERC7575.mint.selector;
        sigs[2] = INode.requestRedeem.selector;
        address[] memory policies = new address[](3);
        policies[0] = address(policy);
        policies[1] = address(policy);
        policies[2] = address(policy);

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
        node.approve(address(node), shares);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        _addToWhitelist(user);

        vm.startPrank(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();
    }
}
