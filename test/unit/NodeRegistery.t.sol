// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
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

    function test_constructor() public view {
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
        emit EventsLib.RoleSet(testFactory, RegistryType.FACTORY, true);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRouter, RegistryType.ROUTER, true);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testQuoter, RegistryType.QUOTER, true);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRebalancer, RegistryType.REBALANCER, true);
        testRegistry.initialize(factories, routers, quoters, rebalancers, protocolFeesAddress, 0, 0, 0.99 ether);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testFactory, RegistryType.FACTORY));
        assertTrue(testRegistry.isRegistryType(testRouter, RegistryType.ROUTER));
        assertTrue(testRegistry.isRegistryType(testQuoter, RegistryType.QUOTER));
        assertTrue(testRegistry.isRegistryType(testRebalancer, RegistryType.REBALANCER));
        assertTrue(testRegistry.isInitialized());
    }

    function test_initialize_revert_AlreadyInitialized() public {
        address[] memory empty = new address[](0);
        vm.startPrank(owner);
        testRegistry.initialize(empty, empty, empty, empty, protocolFeesAddress, 0, 0, 0.99 ether);

        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        testRegistry.initialize(empty, empty, empty, empty, protocolFeesAddress, 0, 0, 0.99 ether);
        vm.stopPrank();
    }

    function test_addNode() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
        vm.stopPrank();

        vm.prank(testFactory);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.NodeAdded(testNode);
        testRegistry.addNode(testNode);

        assertTrue(testRegistry.isNode(testNode));
    }

    function test_addFactory() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testFactory, RegistryType.FACTORY, true);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testFactory, RegistryType.FACTORY));
    }

    function test_addFactory_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
        vm.stopPrank();
    }

    function test_initialize_revert_ZeroAddress() public {
        address[] memory factories = new address[](1);
        factories[0] = address(0);
        address[] memory empty = new address[](0);

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(factories, empty, empty, empty, protocolFeesAddress, 0, 0, 0.99 ether);

        address[] memory routers = new address[](1);
        routers[0] = address(0);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(empty, routers, empty, empty, protocolFeesAddress, 0, 0, 0.99 ether);

        address[] memory quoters = new address[](1);
        quoters[0] = address(0);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(empty, empty, quoters, empty, protocolFeesAddress, 0, 0, 0.99 ether);

        address[] memory rebalancers = new address[](1);
        rebalancers[0] = address(0);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(empty, empty, empty, rebalancers, protocolFeesAddress, 0, 0, 0.99 ether);

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.initialize(empty, empty, empty, empty, address(0), 0, 0, 0.99 ether);

        vm.stopPrank();
    }

    function test_addNode_revert_NotInitialized() public {
        vm.prank(testFactory);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.addNode(testNode);
    }

    function test_addNode_revert_NotFactory() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        vm.stopPrank();

        vm.prank(address(1));
        vm.expectRevert(ErrorsLib.NotFactory.selector);
        testRegistry.addNode(testNode);
    }

    function test_addNode_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
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
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
    }

    function test_removeFactory() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testFactory, RegistryType.FACTORY, false);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, false);
        vm.stopPrank();

        assertFalse(testRegistry.isRegistryType(testFactory, RegistryType.FACTORY));
    }

    function test_removeFactory_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, false);
    }

    // Router tests
    function test_addRouter() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRouter, RegistryType.ROUTER, true);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testRouter, RegistryType.ROUTER));
    }

    function test_addRouter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);
    }

    function test_addRouter_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);
        vm.stopPrank();
    }

    function test_removeRouter() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRouter, RegistryType.ROUTER, false);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, false);
        vm.stopPrank();

        assertFalse(testRegistry.isRegistryType(testRouter, RegistryType.ROUTER));
    }

    function test_removeRouter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, false);
    }

    // Quoter tests
    function test_addQuoter() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testQuoter, RegistryType.QUOTER, true);
        testRegistry.setRegistryType(testQuoter, RegistryType.QUOTER, true);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testQuoter, RegistryType.QUOTER));
    }

    function test_addQuoter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.setRegistryType(testQuoter, RegistryType.QUOTER, true);
    }

    function test_addQuoter_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testQuoter, RegistryType.QUOTER, true);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setRegistryType(testQuoter, RegistryType.QUOTER, true);
        vm.stopPrank();
    }

    function test_removeQuoter() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testQuoter, RegistryType.QUOTER, true);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testQuoter, RegistryType.QUOTER, false);
        testRegistry.setRegistryType(testQuoter, RegistryType.QUOTER, false);
        vm.stopPrank();

        assertFalse(testRegistry.isRegistryType(testQuoter, RegistryType.QUOTER));
    }

    function test_removeQuoter_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.setRegistryType(testQuoter, RegistryType.QUOTER, false);
    }

    // Rebalancer tests
    function test_addRebalancer() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRebalancer, RegistryType.REBALANCER, true);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testRebalancer, RegistryType.REBALANCER));
    }

    function test_addRebalancer_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);
    }

    function test_addRebalancer_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);
        vm.stopPrank();
    }

    function test_removeRebalancer() public {
        vm.startPrank(owner);
        testRegistry.initialize(
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRebalancer, RegistryType.REBALANCER, false);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, false);
        vm.stopPrank();

        assertFalse(testRegistry.isRegistryType(testRebalancer, RegistryType.REBALANCER));
    }

    function test_removeRebalancer_revert_NotInitialized() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotInitialized.selector);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, false);
    }
}
