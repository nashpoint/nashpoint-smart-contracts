// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";
import {INode} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RegistryAccessControlHarness is RegistryAccessControl {
    constructor(address registry_) RegistryAccessControl(registry_) {}

    function checkOnlyNodeRebalancer(address node) external onlyNodeRebalancer(node) {}

    function checkOnlyNode() external onlyNode {}

    function checkOnlyRegistryOwner() external onlyRegistryOwner {}

    function checkOnlyNodeComponent(address node, address component) external onlyNodeComponent(node, component) {}
}

contract RegistryAccessControlTest is Test {
    address registry = address(0x1);
    address node = address(0x2);
    address component = address(0x3);
    address registryOwner = address(0x4);
    address rebalancer = address(0x5);

    RegistryAccessControlHarness rac;

    function setUp() external {
        vm.mockCall(registry, abi.encodeWithSelector(Ownable.owner.selector), abi.encode(registryOwner));
        rac = new RegistryAccessControlHarness(registry);
    }

    function test_constructor_zeroAddress_revert() external {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new RegistryAccessControlHarness(address(0));
    }

    function test_onlyNodeRebalancer_revert_invalidNode() external {
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.isNode.selector, node), abi.encode(false));
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        rac.checkOnlyNodeRebalancer(node);
    }

    function test_onlyNodeRebalancer_revert_notRebalancer() external {
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.isNode.selector, node), abi.encode(true));
        vm.mockCall(node, abi.encodeWithSelector(INode.isRebalancer.selector, address(this)), abi.encode(false));

        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        rac.checkOnlyNodeRebalancer(node);
    }

    function test_onlyNodeRebalancer_success() external {
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.isNode.selector, node), abi.encode(true));
        vm.mockCall(node, abi.encodeWithSelector(INode.isRebalancer.selector, address(this)), abi.encode(true));

        rac.checkOnlyNodeRebalancer(node);
    }

    function test_onlyNode_revert_invalidNode() external {
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.isNode.selector, address(this)), abi.encode(false));
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        rac.checkOnlyNode();
    }

    function test_onlyNode_success() external {
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.isNode.selector, address(this)), abi.encode(true));
        rac.checkOnlyNode();
    }

    function test_onlyRegistryOwner_revert() external {
        vm.prank(address(0xbeef));
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        rac.checkOnlyRegistryOwner();
    }

    function test_onlyRegistryOwner_success() external {
        vm.prank(registryOwner);
        rac.checkOnlyRegistryOwner();
    }

    function test_onlyNodeComponent_revert_invalidComponent() external {
        vm.mockCall(node, abi.encodeWithSelector(INode.isComponent.selector, component), abi.encode(false));
        vm.expectRevert(ErrorsLib.InvalidComponent.selector);
        rac.checkOnlyNodeComponent(node, component);
    }

    function test_onlyNodeComponent_success() external {
        vm.mockCall(node, abi.encodeWithSelector(INode.isComponent.selector, component), abi.encode(true));
        rac.checkOnlyNodeComponent(node, component);
    }
}
