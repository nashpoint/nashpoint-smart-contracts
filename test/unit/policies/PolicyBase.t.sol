// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {INode} from "src/interfaces/INode.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

import {PolicyBase} from "src/policies/PolicyBase.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

bytes4 constant ACTION1 = IERC7575.deposit.selector;
bytes4 constant ACTION2 = INode.subtractProtocolExecutionFee.selector;
bytes4 constant ACTION3 = IERC7575.mint.selector;
bytes4 constant ACTION4 = INode.updateTotalAssets.selector;

contract PolicyBaseHarness is PolicyBase {
    constructor(address registry_) PolicyBase(registry_) {
        actions[ACTION1] = true;
        actions[ACTION2] = true;
    }

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view override {}

    function extract(bytes calldata data) external pure returns (bytes4 selector, bytes calldata payload) {
        return _extract(data);
    }

    function checkOnlyRegistryOwner() external view onlyRegistryOwner {}

    function checkOnlyNodeOwner(address node) external view onlyNodeOwner(node) {}

    function checkOnlyNode(address node) external view onlyNode(node) {}

    function checkAllowedAction(bytes4 selector) external view {
        _allowedAction(selector);
    }
}

contract PolicyBaseTest is Test {
    address registry = address(0x1);

    address node = address(0x2);
    address notNode = address(0x3);

    address nodeOwner = address(0x4);
    address notNodeOwner = address(0x5);

    address registryOwner = address(0x6);

    PolicyBaseHarness policy;

    function setUp() external {
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.isNode.selector, node), abi.encode(true));
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.isNode.selector, notNode), abi.encode(false));
        vm.mockCall(registry, abi.encodeWithSelector(Ownable.owner.selector), abi.encode(registryOwner));
        vm.mockCall(node, abi.encodeWithSelector(Ownable.owner.selector), abi.encode(nodeOwner));

        policy = new PolicyBaseHarness(registry);
    }

    function test_actions() external view {
        assertTrue(policy.actions(ACTION1));
        assertTrue(policy.actions(ACTION2));
        assertFalse(policy.actions(ACTION3));
    }

    function test_onlyRegistryOwner() external {
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        policy.checkOnlyRegistryOwner();

        vm.prank(registryOwner);
        policy.checkOnlyRegistryOwner();
    }

    function test_onlyNodeOwner() external {
        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        policy.checkOnlyNodeOwner(notNode);

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.checkOnlyNodeOwner(node);

        vm.prank(nodeOwner);
        policy.checkOnlyNodeOwner(node);
    }

    function test_onlyNode() external {
        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        policy.checkOnlyNode(notNode);

        policy.checkOnlyNode(node);
    }

    function test_allowedSelector() external {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotAllowedAction.selector, ACTION3));
        policy.checkAllowedAction(ACTION3);

        policy.checkAllowedAction(ACTION1);
        policy.checkAllowedAction(ACTION2);
    }

    function test_extract() external view {
        {
            bytes memory data = abi.encodeWithSelector(IERC7575.deposit.selector, 123, address(0xbeef));
            (bytes4 selector, bytes memory payload) = policy.extract(data);
            assertEq(selector, IERC7575.deposit.selector);
            assertEq(payload, abi.encode(123, address(0xbeef)));
        }
        {
            bytes memory data = abi.encodeWithSelector(INode.subtractProtocolExecutionFee.selector, 456);
            (bytes4 selector, bytes memory payload) = policy.extract(data);
            assertEq(selector, INode.subtractProtocolExecutionFee.selector);
            assertEq(payload, abi.encode(456));
        }
        {
            bytes memory data = abi.encodeWithSelector(INode.updateTotalAssets.selector);
            (bytes4 selector, bytes memory payload) = policy.extract(data);
            assertEq(selector, INode.updateTotalAssets.selector);
            assertEq(payload, "");
        }
    }

    function test_onCheck() external {
        {
            bytes memory data = abi.encodeWithSelector(IERC7575.deposit.selector, 123, address(0xbeef));
            vm.startPrank(notNode);
            vm.expectRevert(ErrorsLib.NotRegistered.selector);
            policy.onCheck(address(this), data);
            vm.stopPrank();
        }
        {
            bytes memory data = abi.encodeWithSelector(IERC7575.deposit.selector, 123, address(0xbeef));
            vm.startPrank(node);
            policy.onCheck(address(this), data);
            vm.stopPrank();
        }
        {
            bytes memory data = abi.encodeWithSelector(INode.updateTotalAssets.selector);
            vm.startPrank(node);
            vm.expectRevert(
                abi.encodeWithSelector(ErrorsLib.NotAllowedAction.selector, INode.updateTotalAssets.selector)
            );
            policy.onCheck(address(this), data);
            vm.stopPrank();
        }
    }
}
