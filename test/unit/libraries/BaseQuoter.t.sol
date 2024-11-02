// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {BaseQuoter} from "src/libraries/BaseQuoter.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestQuoter is BaseQuoter {
    constructor(address registry_) BaseQuoter(registry_) {}

    function testOnlyValidNode(address node) external onlyValidNode(node) {}

    function testOnlyRegistryOwner() external onlyRegistryOwner {}
}

contract BaseQuoterTest is BaseTest {
    NodeRegistry public testRegistry;
    TestQuoter public testQuoter;

    address public testNode;
    address public registryOwner;

    function setUp() public override {
        super.setUp();
        
        testNode = makeAddr("testNode");
        registryOwner = makeAddr("registryOwner");
        randomUser = makeAddr("randomUser");
        
        testRegistry = new NodeRegistry(registryOwner);
        testQuoter = new TestQuoter(address(testRegistry));

        vm.startPrank(registryOwner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0));
        testRegistry.addFactory(address(this));
        vm.stopPrank();

        testRegistry.addNode(testNode);

        vm.label(testNode, "TestNode");
        vm.label(registryOwner, "RegistryOwner");
        vm.label(randomUser, "RandomUser");
        vm.label(address(testRegistry), "TestRegistry");
        vm.label(address(testQuoter), "TestQuoter");
    }

    function test_constructor() public {
        assertEq(address(testQuoter.registry()), address(testRegistry));
    }

    function test_constructor_revert_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new TestQuoter(address(0));
    }

    function test_onlyValidNode() public {
        testQuoter.testOnlyValidNode(testNode);
    }

    function test_onlyValidNode_revert_NotRegistered() public {
        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        testQuoter.testOnlyValidNode(randomUser);
    }

    function test_onlyRegistryOwner() public {
        vm.prank(registryOwner);
        testQuoter.testOnlyRegistryOwner();
    }

    function test_onlyRegistryOwner_revert_NotRegistryOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        testQuoter.testOnlyRegistryOwner();
    }
}
