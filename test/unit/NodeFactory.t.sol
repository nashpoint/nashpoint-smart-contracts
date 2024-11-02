// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseTest} from "../BaseTest.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";

contract NodeFactoryTest is BaseTest {
    NodeRegistry public testRegistry;
    NodeFactory public testFactory;

    address public testAsset;
    address public testQuoter;
    address public testRouter;
    address public testRebalancer;
    address public testComponent;

    string constant TEST_NAME = "Test Node";
    string constant TEST_SYMBOL = "TNODE";
    bytes32 constant TEST_SALT = bytes32(uint256(1));

    function getTestReserveAllocation() internal pure returns (ComponentAllocation memory) {
        return ComponentAllocation({
            minimumWeight: 0.3 ether,
            maximumWeight: 0.7 ether,
            targetWeight: 0.5 ether
        });
    }

    function getTestComponentAllocations(uint256 count) internal pure returns (ComponentAllocation[] memory allocations) {
        allocations = new ComponentAllocation[](count);
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = ComponentAllocation({
                minimumWeight: 0.3 ether,
                maximumWeight: 0.7 ether,
                targetWeight: 0.5 ether
            });
        }
    }

    function setUp() public override {
        super.setUp();
        
        testAsset = makeAddr("testAsset");
        testQuoter = makeAddr("testQuoter");
        testRouter = makeAddr("testRouter");
        testRebalancer = makeAddr("testRebalancer");
        testComponent = makeAddr("testComponent");
        
        testRegistry = new NodeRegistry(owner);
        testFactory = new NodeFactory(address(testRegistry));

        vm.startPrank(owner);
        testRegistry.initialize(
            _toArray(address(testFactory)),
            _toArray(testRouter),
            _toArray(testQuoter),
            _toArray(testRebalancer)
        );
        vm.stopPrank();

        vm.label(testAsset, "TestAsset");
        vm.label(testQuoter, "TestQuoter");
        vm.label(testRouter, "TestRouter");
        vm.label(testRebalancer, "TestRebalancer");
        vm.label(testComponent, "TestComponent");
        vm.label(address(testRegistry), "TestRegistry");
        vm.label(address(testFactory), "TestFactory");
    }

    function test_createNode() public {
        vm.expectEmit(false, true, true, true);
        emit EventsLib.CreateNode(
            address(0),
            testAsset,
            TEST_NAME,
            TEST_SYMBOL,
            owner,
            testRebalancer,
            TEST_SALT
        );

        INode node = testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            owner,
            testRebalancer,
            testQuoter,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );

        assertTrue(testRegistry.isNode(address(node)));
    }

    function test_deployFullNode() public {
        vm.expectEmit(false, true, true, true);
        emit EventsLib.CreateNode(
            address(0),
            testAsset,
            TEST_NAME,
            TEST_SYMBOL,
            address(testFactory), // owner is factory during creation
            testRebalancer,
            TEST_SALT
        );

        (INode node, IEscrow escrow, IQueueManager manager) = testFactory.deployFullNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            owner,
            testRebalancer,
            testQuoter,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );

        assertTrue(testRegistry.isNode(address(node)));
        assertEq(Ownable(address(node)).owner(), owner);
        assertEq(address(node.escrow()), address(escrow));
        assertEq(address(node.manager()), address(manager));
    }

    function test_createNode_revert_ZeroAddress() public {
        // Test zero asset address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            address(0),
            owner,
            testRebalancer,
            testQuoter,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );

        // Test zero owner address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            address(0),
            testRebalancer,
            testQuoter,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );

        // Test zero quoter address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            owner,
            address(0),
            testRebalancer,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );
    }

    function test_createNode_revert_InvalidName() public {
        vm.expectRevert(ErrorsLib.InvalidName.selector);
        testFactory.createNode(
            "", // empty name
            TEST_SYMBOL,
            testAsset,
            owner,
            testRebalancer,
            testQuoter,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );
    }

    function test_createNode_revert_InvalidSymbol() public {
        vm.expectRevert(ErrorsLib.InvalidSymbol.selector);
        testFactory.createNode(
            TEST_NAME,
            "", // empty symbol
            testAsset,
            owner,
            testRebalancer,
            testQuoter,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );
    }

    function test_createNode_revert_LengthMismatch() public {
        address[] memory components = new address[](2);
        components[0] = testComponent;
        components[1] = makeAddr("testComponent2");

        vm.expectRevert(ErrorsLib.LengthMismatch.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            owner,
            testRebalancer,
            testQuoter,
            _toArray(testRouter),
            components,
            getTestComponentAllocations(1), // Only 1 allocation for 2 components
            getTestReserveAllocation(),
            TEST_SALT
        );
    }

    function test_createNode_revert_NotRegistered() public {
        // Test unregistered router
        address unregisteredRouter = makeAddr("unregisteredRouter");
        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            owner,
            testRebalancer,
            testQuoter,
            _toArray(unregisteredRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );

        // Test unregistered quoter
        address unregisteredQuoter = makeAddr("unregisteredQuoter");
        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            owner,
            testRebalancer,
            unregisteredQuoter,
            _toArray(testRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );
    }
}
