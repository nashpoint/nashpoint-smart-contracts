// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NodeTest is BaseTest {
    NodeRegistry public testRegistry;
    Node public testNode;
    
    address public testAsset;
    address public testQuoter;
    address public testRouter;
    address public testRebalancer;
    address public testComponent;
    ERC20Mock public testToken;
    ERC4626Mock public testVault;

    string constant TEST_NAME = "Test Node";
    string constant TEST_SYMBOL = "TNODE";

    function setUp() public override {
        super.setUp();

        testToken = new ERC20Mock("Test Token", "TEST");
        testVault = new ERC4626Mock(address(testToken));
        
        testAsset = address(testToken);
        testQuoter = makeAddr("testQuoter");
        testRouter = makeAddr("testRouter");
        testRebalancer = makeAddr("testRebalancer");
        testComponent = address(testVault);

        testRegistry = new NodeRegistry(owner);

        vm.startPrank(owner);
        testRegistry.initialize(
            _toArray(address(this)), // factory
            _toArray(testRouter),
            _toArray(testQuoter),
            _toArray(testRebalancer)
        );

        testNode = new Node(
            address(testRegistry),
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            testQuoter,
            owner,
            testRebalancer,
            _toArray(testRouter),
            _toArray(testComponent),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );
        vm.stopPrank();

        vm.label(testAsset, "TestAsset");
        vm.label(testQuoter, "TestQuoter");
        vm.label(testRouter, "TestRouter");
        vm.label(testRebalancer, "TestRebalancer");
        vm.label(testComponent, "TestComponent");
        vm.label(address(testRegistry), "TestRegistry");
        vm.label(address(testNode), "TestNode");
    }

    function test_constructor() public {
        // Check immutables
        assertEq(address(testNode.registry()), address(testRegistry));
        assertEq(testNode.asset(), testAsset);
        assertEq(testNode.share(), address(testNode));
        
        // Check initial state
        assertEq(address(testNode.quoter()), testQuoter);
        assertEq(testNode.name(), TEST_NAME);
        assertEq(testNode.symbol(), TEST_SYMBOL);
        assertTrue(testNode.isRebalancer(testRebalancer));
        assertTrue(testNode.isRouter(testRouter));
        
        // Check components
        address[] memory nodeComponents = testNode.getComponents();
        assertEq(nodeComponents.length, 1);
        assertEq(nodeComponents[0], testComponent);
        
        // Check component allocation
        uint256 componentWeight = testNode.componentAllocations(testComponent);
        assertEq(componentWeight, 0.9 ether);
        
        // Check reserve allocation
        uint256 reserveWeight = testNode.reserveAllocation();
        assertEq(reserveWeight, 0.1 ether);

        // Check ownership
        assertEq(testNode.owner(), owner);
    }

    function test_constructor_revert_ZeroAddress() public {
        // Test zero registry address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(0),
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            testQuoter,
            owner,
            testRebalancer,
            _toArray(testRouter),
            _toArray(testComponent),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );

        // Test zero asset address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(testRegistry),
            TEST_NAME,
            TEST_SYMBOL,
            address(0),
            testQuoter,
            owner,
            testRebalancer,
            _toArray(testRouter),
            _toArray(testComponent),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );

        // Test zero quoter address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(testRegistry),
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            address(0),
            owner,
            testRebalancer,
            _toArray(testRouter),
            _toArray(testComponent),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );

        // Test zero component address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(testRegistry),
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            testQuoter,
            owner,
            testRebalancer,
            _toArray(testRouter),
            _toArray(address(0)),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );
    }

    function test_constructor_revert_LengthMismatch() public {
        address[] memory components = new address[](2);
        components[0] = testComponent;
        components[1] = makeAddr("testComponent2");

        vm.expectRevert(ErrorsLib.LengthMismatch.selector);
        new Node(
            address(testRegistry),
            TEST_NAME,
            TEST_SYMBOL,
            testAsset,
            testQuoter,
            owner,
            testRebalancer,
            _toArray(testRouter),
            components,
            _defaultComponentAllocations(1), // Only 1 allocation for 2 components
            _defaultReserveAllocation()
        );
    }

    function test_initialize() public {
        address testEscrow = makeAddr("testEscrow");
        uint256 testMaxAssetDelta = 1000;

        vm.prank(owner);
        testNode.initialize(testEscrow, testMaxAssetDelta);

        assertEq(address(testNode.escrow()), testEscrow);
        assertEq(testNode.maxAssetDelta(), testMaxAssetDelta);
        assertFalse(testNode.swingPricingEnabled());
        assertTrue(testNode.isInitialized());
    }

    function test_initialize_revert_AlreadyInitialized() public {
        address testEscrow = makeAddr("testEscrow");
        
        vm.startPrank(owner);
        testNode.initialize(testEscrow, 1000);
        
        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        testNode.initialize(testEscrow, 1000);
        vm.stopPrank();
    }

    function test_initialize_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.initialize(address(0), 1000);
    }

    function test_addComponent() public {
        address newComponent = makeAddr("newComponent");
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether
        });

        vm.prank(owner);
        testNode.addComponent(newComponent, allocation);

        assertTrue(testNode.isComponent(newComponent));
        assertEq(testNode.componentAllocations(newComponent), allocation.targetWeight);
        
        // Verify components array
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2); // Original + new component
        assertEq(components[1], newComponent);
    }

    function test_addComponent_revert_ZeroAddress() public {
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether
        });

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.addComponent(address(0), allocation);
    }

    function test_addComponent_revert_AlreadySet() public {
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether
        });

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.addComponent(testComponent, allocation);
    }

    function test_removeComponent() public {
        // Add a second component first
        address secondComponent = makeAddr("secondComponent");
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether
        });

        vm.startPrank(owner);
        testNode.addComponent(secondComponent, allocation);
        
        // Now remove the first component
        testNode.removeComponent(testComponent);
        vm.stopPrank();

        assertFalse(testNode.isComponent(testComponent));
        assertEq(testNode.componentAllocations(testComponent), 0);
        
        // Verify components array
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 1);
        assertEq(components[0], secondComponent);
    }

    function test_removeComponent_revert_NotSet() public {
        address nonExistentComponent = makeAddr("nonExistentComponent");

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.removeComponent(nonExistentComponent);
    }

    function test_removeComponent_revert_NonZeroBalance() public {
        // Mock non-zero balance
        vm.mockCall(
            testComponent,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(1)
        );

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NonZeroBalance.selector);
        testNode.removeComponent(testComponent);
    }

    function test_removeComponent_SingleComponent() public {
        // Mock zero balance first to avoid NonZeroBalance error
        vm.mockCall(
            testComponent,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(0)
        );

        vm.prank(owner);
        testNode.removeComponent(testComponent);

        address[] memory components = testNode.getComponents();
        assertEq(components.length, 0);
        assertFalse(testNode.isComponent(testComponent));
    }

    function test_removeComponent_FirstOfMany() public {
        address component2 = makeAddr("component2");
        address component3 = makeAddr("component3");
        
        vm.startPrank(owner);
        testNode.addComponent(component2, ComponentAllocation({targetWeight: 0.5 ether}));
        testNode.addComponent(component3, ComponentAllocation({targetWeight: 0.5 ether}));
        
        // Remove first component
        testNode.removeComponent(testComponent);
        vm.stopPrank();

        // Verify array state
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2);
        assertTrue(components[0] == component2 || components[0] == component3);
        assertTrue(components[1] == component2 || components[1] == component3);
        assertFalse(components[0] == components[1]);
        assertFalse(testNode.isComponent(testComponent));
    }

    function test_removeComponent_MiddleOfMany() public {
        address component2 = makeAddr("component2");
        address component3 = makeAddr("component3");
        
        // Mock zero balances for all components
        vm.mockCall(
            testComponent,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(0)
        );
        vm.mockCall(
            component2,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(0)
        );
        vm.mockCall(
            component3,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(0)
        );
        
        vm.startPrank(owner);
        testNode.addComponent(component2, ComponentAllocation({targetWeight: 0.5 ether}));
        testNode.addComponent(component3, ComponentAllocation({targetWeight: 0.5 ether}));
        
        // Remove middle component
        testNode.removeComponent(component2);
        vm.stopPrank();

        // Verify array state
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2);
        assertEq(components[0], testComponent);
        assertEq(components[1], component3);
        assertFalse(testNode.isComponent(component2));
    }

    function test_removeComponent_LastOfMany() public {
        address component2 = makeAddr("component2");
        address component3 = makeAddr("component3");
        
        // Mock zero balances for all components
        vm.mockCall(
            testComponent,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(0)
        );
        vm.mockCall(
            component2,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(0)
        );
        vm.mockCall(
            component3,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)),
            abi.encode(0)
        );
        
        vm.startPrank(owner);
        testNode.addComponent(component2, ComponentAllocation({targetWeight: 0.5 ether}));
        testNode.addComponent(component3, ComponentAllocation({targetWeight: 0.5 ether}));
        
        // Remove last component
        testNode.removeComponent(component3);
        vm.stopPrank();

        // Verify array state
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2);
        assertEq(components[0], testComponent);
        assertEq(components[1], component2);
        assertFalse(testNode.isComponent(component3));
    }

    function test_updateComponentAllocation() public {
        ComponentAllocation memory newAllocation = ComponentAllocation({
            targetWeight: 0.8 ether
        });

        vm.prank(owner);
        testNode.updateComponentAllocation(testComponent, newAllocation);

        assertEq(testNode.componentAllocations(testComponent), newAllocation.targetWeight);
    }

    function test_updateComponentAllocation_revert_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.updateComponentAllocation(
            makeAddr("nonexistent"), 
            ComponentAllocation({targetWeight: 0.8 ether})
        );
    }

    function test_updateReserveAllocation() public {
        ComponentAllocation memory newAllocation = ComponentAllocation({
            targetWeight: 0.3 ether
        });

        vm.prank(owner);
        testNode.updateReserveAllocation(newAllocation);

        assertEq(testNode.reserveAllocation(), newAllocation.targetWeight);
    }

    function test_addRouter() public {
        address newRouter = makeAddr("newRouter");

        vm.prank(owner);
        testNode.addRouter(newRouter);

        assertTrue(testNode.isRouter(newRouter));
    }

    function test_addRouter_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.addRouter(address(0));
    }

    function test_addRouter_revert_AlreadySet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.addRouter(testRouter);
    }

    function test_removeRouter() public {
        vm.prank(owner);
        testNode.removeRouter(testRouter);

        assertFalse(testNode.isRouter(testRouter));
    }

    function test_removeRouter_revert_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.removeRouter(makeAddr("nonexistent"));
    }

    function test_addRebalancer() public {
        address newRebalancer = makeAddr("newRebalancer");

        vm.prank(owner);
        testNode.addRebalancer(newRebalancer);

        assertTrue(testNode.isRebalancer(newRebalancer));
    }

    function test_addRebalancer_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.addRebalancer(address(0));
    }

    function test_addRebalancer_revert_AlreadySet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.addRebalancer(testRebalancer);
    }

    function test_removeRebalancer() public {
        vm.prank(owner);
        testNode.removeRebalancer(testRebalancer);

        assertFalse(testNode.isRebalancer(testRebalancer));
    }

    function test_removeRebalancer_revert_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.removeRebalancer(makeAddr("nonexistent"));
    }

    function test_setEscrow() public {
        address newEscrow = makeAddr("newEscrow");
        
        vm.startPrank(owner);
        testNode.initialize(makeAddr("initialEscrow"), 1000);
        testNode.setEscrow(newEscrow);
        vm.stopPrank();

        assertEq(address(testNode.escrow()), newEscrow);
    }

    function test_setEscrow_revert_ZeroAddress() public {
        vm.startPrank(owner);
        // Initialize first to avoid AlreadySet error
        testNode.initialize(makeAddr("initialEscrow"), 1000);
        
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setEscrow(address(0));
        vm.stopPrank();
    }

    function test_setEscrow_revert_AlreadySet() public {
        address escrowAddr = makeAddr("escrow");
        
        vm.startPrank(owner);
        testNode.initialize(escrowAddr, 1000);
        
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.setEscrow(escrowAddr);
        vm.stopPrank();
    }

    function test_setQuoter() public {
        address newQuoter = makeAddr("newQuoter");

        vm.prank(owner);
        testNode.setQuoter(newQuoter);

        assertEq(address(testNode.quoter()), newQuoter);
    }

    function test_setQuoter_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setQuoter(address(0));
    }

    function test_setQuoter_revert_AlreadySet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.setQuoter(testQuoter);
    }

    function test_enableSwingPricing() public {
        address newPricer = makeAddr("newPricer");
        uint256 newMaxSwingFactor = 0.1 ether;

        testNode.enableSwingPricing(true, newPricer, newMaxSwingFactor);

        assertTrue(testNode.swingPricingEnabled());
        assertEq(address(testNode.pricer()), newPricer);
        assertEq(testNode.maxSwingFactor(), newMaxSwingFactor);
    }

    function test_enableSwingPricing_disable() public {
        address newPricer = makeAddr("newPricer");
        uint256 newMaxSwingFactor = 0.1 ether;

        // Enable first
        testNode.enableSwingPricing(true, newPricer, newMaxSwingFactor);
        
        // Then disable
        testNode.enableSwingPricing(false, newPricer, newMaxSwingFactor);

        assertFalse(testNode.swingPricingEnabled());
        assertEq(address(testNode.pricer()), newPricer);
        assertEq(testNode.maxSwingFactor(), newMaxSwingFactor);
    }
} 