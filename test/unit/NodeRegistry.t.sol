// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

contract NodeRegistryTest is BaseTest {
    NodeRegistry public testRegistry;

    // NodeRegistryTest specific deployment
    address public testFactory;
    address public testRouter;
    address public testQuoter;
    address public testNode;
    address public testRebalancer;

    function setUp() public override {
        super.setUp();
        
        testFactory = makeAddr("testFactory");
        testRouter = makeAddr("testRouter");
        testQuoter = makeAddr("testQuoter");
        testNode = makeAddr("testNode");
        testRebalancer = makeAddr("testRebalancer");

        // Uninitialized NodeRegistry for unit testing
        testRegistry = new NodeRegistry(owner);
    }

    function test_constructor() public {
        assertEq(testRegistry.owner(), owner);
        assertFalse(testRegistry.isInitialized());
    }

    function test_initialize() public {
        address[] memory factories = new address[](1);
        factories[0] = testFactory;
        address[] memory routers = new address[](1);
        routers[0] = testRouter;
        address[] memory quoters = new address[](1);
        quoters[0] = testQuoter;
        address[] memory rebalancers = new address[](1);
        rebalancers[0] = testRebalancer;

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.FactoryAdded(testFactory);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RouterAdded(testRouter);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.QuoterAdded(testQuoter);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RebalancerAdded(testRebalancer);
        testRegistry.initialize(factories, routers, quoters, rebalancers);
        vm.stopPrank();

        assertTrue(testRegistry.isFactory(testFactory));
        assertTrue(testRegistry.isRouter(testRouter));
        assertTrue(testRegistry.isQuoter(testQuoter));
        assertTrue(testRegistry.isRebalancer(testRebalancer));
        assertTrue(testRegistry.isInitialized());
    }

    function test_initialize_revert_AlreadyInitialized() public {
        address[] memory empty = new address[](0);
        vm.startPrank(owner);
        testRegistry.initialize(empty, empty, empty, empty);

        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        testRegistry.initialize(empty, empty, empty, empty);
        vm.stopPrank();
    }

    function test_addNode() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addFactory(testFactory);
        vm.stopPrank();

        vm.prank(testFactory);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.NodeAdded(testNode);
        testRegistry.addNode(testNode);

        assertTrue(testRegistry.isNode(testNode));
    }

    function test_addFactory() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        
        vm.expectEmit(true, false, false, false);
        emit EventsLib.FactoryAdded(testFactory);
        testRegistry.addFactory(testFactory);
        vm.stopPrank();

        assertTrue(testRegistry.isFactory(testFactory));
    }

    function test_addFactory_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addFactory(testFactory);
        
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.addFactory(testFactory);
        vm.stopPrank();
    }

    function test_isSystemContract() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            _toArray(testFactory),
            _toArray(testRouter),
            _toArray(testQuoter),
            _toArray(testRebalancer)
        );
        vm.stopPrank();

        vm.prank(testFactory);
        testRegistry.addNode(testNode);

        assertTrue(testRegistry.isSystemContract(testNode));
        assertTrue(testRegistry.isSystemContract(testFactory));
        assertTrue(testRegistry.isSystemContract(testRouter));
        assertTrue(testRegistry.isSystemContract(testQuoter));
        assertTrue(testRegistry.isSystemContract(address(testRegistry)));
        assertFalse(testRegistry.isSystemContract(address(1)));
    }

    function test_initialize_revert_ZeroAddress() public {
        address[] memory factories = new address[](1);
        factories[0] = address(0);
        address[] memory empty = new address[](0);

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(factories, empty, empty, empty);

        address[] memory routers = new address[](1);
        routers[0] = address(0);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(empty, routers, empty, empty);

        address[] memory quoters = new address[](1);
        quoters[0] = address(0);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(empty, empty, quoters, empty);
        vm.stopPrank();
    }

    function test_addNode_revert_NotInitialized() public {
        vm.prank(testFactory);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.addNode(testNode);
    }

    function test_addNode_revert_NotFactory() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        vm.stopPrank();

        vm.prank(address(1));
        vm.expectRevert(ErrorsLib.NotFactory.selector);
        testRegistry.addNode(testNode);
    }

    function test_addNode_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addFactory(testFactory);
        vm.stopPrank();

        vm.startPrank(testFactory);
        testRegistry.addNode(testNode);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.addNode(testNode);
        vm.stopPrank();
    }

    function test_addFactory_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.addFactory(testFactory);
    }

    function test_removeFactory() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addFactory(testFactory);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.FactoryRemoved(testFactory);
        testRegistry.removeFactory(testFactory);
        vm.stopPrank();

        assertFalse(testRegistry.isFactory(testFactory));
    }

    function test_removeFactory_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.removeFactory(testFactory);
    }

    function test_removeFactory_revert_NotSet() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testRegistry.removeFactory(testFactory);
        vm.stopPrank();
    }

    // Router tests
    function test_addRouter() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RouterAdded(testRouter);
        testRegistry.addRouter(testRouter);
        vm.stopPrank();

        assertTrue(testRegistry.isRouter(testRouter));
    }

    function test_addRouter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.addRouter(testRouter);
    }

    function test_addRouter_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addRouter(testRouter);
        
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.addRouter(testRouter);
        vm.stopPrank();
    }

    function test_removeRouter() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addRouter(testRouter);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RouterRemoved(testRouter);
        testRegistry.removeRouter(testRouter);
        vm.stopPrank();

        assertFalse(testRegistry.isRouter(testRouter));
    }

    function test_removeRouter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.removeRouter(testRouter);
    }

    function test_removeRouter_revert_NotSet() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testRegistry.removeRouter(testRouter);
        vm.stopPrank();
    }

    // Quoter tests
    function test_addQuoter() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        
        vm.expectEmit(true, false, false, false);
        emit EventsLib.QuoterAdded(testQuoter);
        testRegistry.addQuoter(testQuoter);
        vm.stopPrank();

        assertTrue(testRegistry.isQuoter(testQuoter));
    }

    function test_addQuoter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.addQuoter(testQuoter);
    }

    function test_addQuoter_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addQuoter(testQuoter);
        
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.addQuoter(testQuoter);
        vm.stopPrank();
    }

    function test_removeQuoter() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0));
        testRegistry.addQuoter(testQuoter);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.QuoterRemoved(testQuoter);
        testRegistry.removeQuoter(testQuoter);
        vm.stopPrank();

        assertFalse(testRegistry.isQuoter(testQuoter));
    }

    function test_removeQuoter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.removeQuoter(testQuoter);
    }

    function test_removeQuoter_revert_NotSet() public {
        vm.startPrank(owner);
        testRegistry.initialize(new address[](0), new address[](0), new address[](0), new address[](0)  );
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testRegistry.removeQuoter(testQuoter);
        vm.stopPrank();
    }
}
