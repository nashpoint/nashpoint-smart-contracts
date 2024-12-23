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
import {DeployParams} from "src/interfaces/INodeFactory.sol";

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
        return ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});
    }

    function getTestComponentAllocations(uint256 count)
        internal
        pure
        returns (ComponentAllocation[] memory allocations)
    {
        allocations = new ComponentAllocation[](count);
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});
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
            _toArray(address(testFactory)), _toArray(testRouter), _toArray(testQuoter), _toArray(testRebalancer)
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
        emit EventsLib.CreateNode(address(0), testAsset, TEST_NAME, TEST_SYMBOL, owner, TEST_SALT);

        INode node = testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            owner,
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
            TEST_SALT
        );

        DeployParams memory params = DeployParams({
            name: TEST_NAME,
            symbol: TEST_SYMBOL,
            asset: testAsset,
            owner: owner,
            rebalancer: testRebalancer,
            quoter: testQuoter,
            routers: _toArray(testRouter),
            components: _toArray(testComponent),
            componentAllocations: getTestComponentAllocations(1),
            reserveAllocation: getTestReserveAllocation(),
            salt: TEST_SALT
        });

        (INode node, IEscrow escrow) = testFactory.deployFullNode(params);

        assertTrue(testRegistry.isNode(address(node)));
        assertEq(Ownable(address(node)).owner(), owner);
        assertEq(address(node.escrow()), address(escrow));
    }

    function test_constructor_revert_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new NodeFactory(address(0));
    }

    function test_createNode_revert_ZeroAddress() public {
        // Test zero asset address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            address(0),
            owner,
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
            _toArray(unregisteredRouter),
            _toArray(testComponent),
            getTestComponentAllocations(1),
            getTestReserveAllocation(),
            TEST_SALT
        );
    }
}
