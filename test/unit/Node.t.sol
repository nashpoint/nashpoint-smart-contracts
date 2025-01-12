// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {stdStorage, StdStorage, console2} from "forge-std/Test.sol";

import {Node} from "src/Node.sol";
import {INode, ComponentAllocation, Request} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";

contract NodeHarness is Node {
    constructor(
        address registry_,
        string memory name,
        string memory symbol,
        address asset_,
        address owner,
        address[] memory routers,
        address[] memory components_,
        ComponentAllocation[] memory componentAllocations_,
        ComponentAllocation memory reserveAllocation_
    ) Node(registry_, name, symbol, asset_, owner, routers, components_, componentAllocations_, reserveAllocation_) {}
}

contract NodeTest is BaseTest {
    using stdStorage for StdStorage;

    NodeRegistry public testRegistry;
    Node public testNode;
    address public testAsset;
    address public testQuoter;
    address public testRouter;
    address public testRebalancer;
    address public testComponent;
    address public testComponent2;
    address public testComponent3;
    address public testEscrow;
    ERC20Mock public testToken;
    ERC4626Mock public testVault;
    ERC4626Mock public testVault2;
    ERC4626Mock public testVault3;

    NodeHarness public nodeHarness;

    string constant TEST_NAME = "Test Node";
    string constant TEST_SYMBOL = "TNODE";

    uint256 public maxDeposit;
    uint256 public rebalanceCooldown;

    function setUp() public override {
        super.setUp();

        testToken = new ERC20Mock("Test Token", "TEST");
        testVault = new ERC4626Mock(address(testToken));
        testVault2 = new ERC4626Mock(address(testToken));
        testVault3 = new ERC4626Mock(address(testToken));
        testEscrow = makeAddr("testEscrow");

        testAsset = address(testToken);
        testQuoter = makeAddr("testQuoter");
        testRouter = makeAddr("testRouter");
        testRebalancer = makeAddr("testRebalancer");
        testComponent = address(testVault);
        testComponent2 = address(testVault2);
        testComponent3 = address(testVault3);

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
            owner,
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

        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.MAX_DEPOSIT();
        rebalanceCooldown = nodeImpl.rebalanceCooldown();

        nodeHarness = new NodeHarness(
            address(registry),
            "TEST_NAME",
            "TEST_SYMBOL",
            address(asset),
            address(owner),
            _toArray(address(router4626)),
            _toArray(address(asset)),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );
    }

    function test_constructor() public view {
        // Check immutables
        assertEq(address(testNode.registry()), address(testRegistry));
        assertEq(testNode.asset(), testAsset);
        assertEq(testNode.share(), address(testNode));

        // Check initial state
        assertEq(testNode.name(), TEST_NAME);
        assertEq(testNode.symbol(), TEST_SYMBOL);
        assertTrue(testNode.isRouter(testRouter));

        // Check components
        address[] memory nodeComponents = testNode.getComponents();
        assertEq(nodeComponents.length, 1);
        assertEq(nodeComponents[0], testComponent);

        // Check component allocation
        (uint256 componentWeight, uint256 maxDelta) = testNode.componentAllocations(testComponent);
        assertEq(componentWeight, 0.9 ether);
        assertEq(maxDelta, 0.01 ether);

        // Check reserve allocation
        (uint256 reserveWeight, uint256 reserveMaxDelta) = testNode.reserveAllocation();
        assertEq(reserveWeight, 0.1 ether);
        assertEq(reserveMaxDelta, 0.01 ether);

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
            owner,
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
            owner,
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
            owner,
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
            owner,
            _toArray(testRouter),
            components,
            _defaultComponentAllocations(1), // Only 1 allocation for 2 components
            _defaultReserveAllocation()
        );
    }

    function test_initialize() public {
        vm.prank(owner);
        testNode.initialize(testEscrow);

        assertEq(address(testNode.escrow()), testEscrow);
        assertFalse(testNode.swingPricingEnabled());
        assertTrue(testNode.isInitialized());
        assertEq(testNode.lastRebalance(), block.timestamp - testNode.rebalanceCooldown());
        assertEq(testNode.lastPayment(), block.timestamp);
    }

    function test_initialize_revert_AlreadyInitialized() public {
        vm.startPrank(owner);
        testNode.initialize(testEscrow);

        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        testNode.initialize(testEscrow);
        vm.stopPrank();
    }

    function test_initialize_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.initialize(address(0));
    }

    function test_addComponent() public {
        address newComponent = makeAddr("newComponent");
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.prank(owner);
        testNode.addComponent(newComponent, allocation);

        assertTrue(testNode.isComponent(newComponent));
        (uint256 componentWeight, uint256 maxDelta) = testNode.componentAllocations(newComponent);
        assertEq(componentWeight, allocation.targetWeight);
        assertEq(maxDelta, allocation.maxDelta);

        // Verify components array
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2); // Original + new component
        assertEq(components[1], newComponent);
    }

    function test_addComponent_revert_ZeroAddress() public {
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.addComponent(address(0), allocation);
    }

    function test_addComponent_revert_AlreadySet() public {
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.addComponent(testComponent, allocation);
    }

    function test_removeComponent() public {
        // Add a second component first
        address secondComponent = makeAddr("secondComponent");
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        testNode.addComponent(secondComponent, allocation);

        // Now remove the first component
        testNode.removeComponent(testComponent);
        vm.stopPrank();

        assertFalse(testNode.isComponent(testComponent));
        (uint256 componentWeight, uint256 maxDelta) = testNode.componentAllocations(testComponent);
        assertEq(componentWeight, 0);
        assertEq(maxDelta, 0);

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
        vm.mockCall(testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(1));

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NonZeroBalance.selector);
        testNode.removeComponent(testComponent);
    }

    function test_removeComponent_SingleComponent() public {
        // Mock zero balance first to avoid NonZeroBalance error
        vm.mockCall(testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));

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
        testNode.addComponent(component2, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));
        testNode.addComponent(component3, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));

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
        vm.mockCall(testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component2, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component3, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));

        vm.startPrank(owner);
        testNode.addComponent(component2, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));
        testNode.addComponent(component3, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));

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
        vm.mockCall(testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component2, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component3, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));

        vm.startPrank(owner);
        testNode.addComponent(component2, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));
        testNode.addComponent(component3, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));

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
        ComponentAllocation memory newAllocation = ComponentAllocation({targetWeight: 0.8 ether, maxDelta: 0.01 ether});

        vm.prank(owner);
        testNode.updateComponentAllocation(testComponent, newAllocation);

        (uint256 componentWeight, uint256 maxDelta) = testNode.componentAllocations(testComponent);
        assertEq(componentWeight, newAllocation.targetWeight);
        assertEq(maxDelta, newAllocation.maxDelta);
    }

    function test_updateComponentAllocation_revert_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.updateComponentAllocation(
            makeAddr("nonexistent"), ComponentAllocation({targetWeight: 0.8 ether, maxDelta: 0.01 ether})
        );
    }

    function test_updateReserveAllocation() public {
        ComponentAllocation memory newAllocation = ComponentAllocation({targetWeight: 0.3 ether, maxDelta: 0.01 ether});

        vm.prank(owner);
        testNode.updateReserveAllocation(newAllocation);

        (uint256 reserveWeight, uint256 reserveMaxDelta) = testNode.reserveAllocation();
        assertEq(reserveWeight, newAllocation.targetWeight);
        assertEq(reserveMaxDelta, newAllocation.maxDelta);
    }

    function test_addRouter() public {
        address newRouter = makeAddr("newRouter");

        vm.mockCall(
            address(testRegistry), abi.encodeWithSelector(INodeRegistry.isRouter.selector, newRouter), abi.encode(true)
        );

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

        vm.mockCall(
            address(testRegistry),
            abi.encodeWithSelector(INodeRegistry.isRebalancer.selector, newRebalancer),
            abi.encode(true)
        );

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
        testNode.addRebalancer(testRebalancer);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.addRebalancer(testRebalancer);
    }

    function test_removeRebalancer() public {
        vm.prank(owner);
        testNode.addRebalancer(testRebalancer);

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
        testNode.initialize(makeAddr("initialEscrow"));
        testNode.setEscrow(newEscrow);
        vm.stopPrank();

        assertEq(address(testNode.escrow()), newEscrow);
    }

    function test_setEscrow_revert_ZeroAddress() public {
        vm.startPrank(owner);
        // Initialize first to avoid AlreadySet error
        testNode.initialize(makeAddr("initialEscrow"));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setEscrow(address(0));
        vm.stopPrank();
    }

    function test_setEscrow_revert_AlreadySet() public {
        address escrowAddr = makeAddr("escrow");

        vm.startPrank(owner);
        testNode.initialize(escrowAddr);

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
        testNode.setQuoter(testQuoter);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setQuoter(address(0));
    }

    function test_setQuoter_revert_AlreadySet() public {
        vm.prank(owner);
        testNode.setQuoter(testQuoter);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.setQuoter(testQuoter);
    }

    function test_setLiquidationQueue() public {
        vm.startPrank(owner);
        testNode.addComponent(testComponent2, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));
        testNode.addComponent(testComponent3, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));

        address[] memory components = testNode.getComponents();
        assertEq(components.length, 3);
        assertEq(components[0], testComponent);
        assertEq(components[1], testComponent2);
        assertEq(components[2], testComponent3);

        testNode.setLiquidationQueue(components);
        vm.stopPrank();

        assertEq(testNode.liquidationsQueue(0), testComponent);
        assertEq(testNode.liquidationsQueue(1), testComponent2);
        assertEq(testNode.liquidationsQueue(2), testComponent3);
    }

    function test_setLiquidationQueue_revert_zeroAddress() public {
        address[] memory components = new address[](1);
        components[0] = address(0);
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setLiquidationQueue(components);
    }

    function test_setLiquidationQueue_revert_invalidComponent() public {
        address[] memory components = new address[](1);
        components[0] = makeAddr("invalidComponent");

        assertFalse(testNode.isComponent(components[0]));
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.InvalidComponent.selector);
        testNode.setLiquidationQueue(components);
    }

    function test_setRebalanceCooldown() public {
        uint256 newRebalanceCooldown = 1 days;
        vm.prank(owner);
        testNode.setRebalanceCooldown(newRebalanceCooldown);
        assertEq(testNode.rebalanceCooldown(), newRebalanceCooldown);
    }

    function test_setRebalanceCooldown_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setRebalanceCooldown(1 days);
    }

    function test_setRebalanceWindow() public {
        uint256 newRebalanceWindow = 1 hours;
        vm.prank(owner);
        testNode.setRebalanceWindow(newRebalanceWindow);
        assertEq(testNode.rebalanceWindow(), newRebalanceWindow);
    }

    function test_setRebalanceWindow_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setRebalanceWindow(1 hours);
    }

    function test_RebalanceCooldown() public {
        _seedNode(100 ether);

        // Cast the interface back to the concrete implementation
        Node node = Node(address(node));

        assertEq(node.rebalanceCooldown(), 1 days);
        assertEq(node.rebalanceWindow(), 1 hours);
        assertEq(node.lastRebalance(), 86401);

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault));

        // warp forward 30 mins so still inside rebalance window
        vm.warp(block.timestamp + 30 minutes);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault));

        // warp forward 30 mins so outside rebalance window
        vm.warp(block.timestamp + 31 minutes);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert();
        router4626.invest(address(node), address(vault));

        vm.prank(rebalancer);
        vm.expectRevert();
        node.startRebalance();

        // warp forward 1 day so cooldown is over
        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.RebalanceStarted(address(node), block.timestamp, node.rebalanceWindow());

        vm.prank(rebalancer);
        node.startRebalance();
    }

    function test_enableSwingPricing() public {
        uint256 newMaxSwingFactor = 0.1 ether;

        vm.prank(owner);
        testNode.enableSwingPricing(true, newMaxSwingFactor);

        assertTrue(testNode.swingPricingEnabled());
        assertEq(testNode.maxSwingFactor(), newMaxSwingFactor);
    }

    function test_enableSwingPricing_disable() public {
        uint256 newMaxSwingFactor = 0.1 ether;

        // Enable first
        vm.prank(owner);
        testNode.enableSwingPricing(true, newMaxSwingFactor);

        // Then disable
        vm.prank(owner);
        testNode.enableSwingPricing(false, 0);
        assertFalse(testNode.swingPricingEnabled());
        assertEq(testNode.maxSwingFactor(), 0);
    }

    function test_enableSwingPricing_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.enableSwingPricing(true, 0.1 ether);
    }

    function test_setNodeOwnerFeeAddress() public {
        address newNodeOwnerFeeAddress = makeAddr("newNodeOwnerFeeAddress");
        vm.prank(owner);
        testNode.setNodeOwnerFeeAddress(newNodeOwnerFeeAddress);
        assertEq(testNode.nodeOwnerFeeAddress(), newNodeOwnerFeeAddress);
    }

    function test_setNodeOwnerFeeAddress_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setNodeOwnerFeeAddress(makeAddr("newNodeOwnerFeeAddress"));
    }

    function test_setNodeOwnerFeeAddress_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setNodeOwnerFeeAddress(address(0));
    }

    function test_setNodeOwnerFeeAddress_revert_AlreadySet() public {
        address newNodeOwnerFeeAddress = makeAddr("newNodeOwnerFeeAddress");
        vm.prank(owner);
        testNode.setNodeOwnerFeeAddress(newNodeOwnerFeeAddress);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.setNodeOwnerFeeAddress(newNodeOwnerFeeAddress);
    }

    function test_setAnnualManagementFee() public {
        uint256 newAnnualManagementFee = 0.01 ether;
        vm.prank(owner);
        testNode.setAnnualManagementFee(newAnnualManagementFee);
        assertEq(testNode.annualManagementFee(), newAnnualManagementFee);
    }

    function test_setAnnualManagementFee_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setAnnualManagementFee(0.01 ether);
    }

    function test_startRebalance() public {
        _seedNode(100 ether);

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault));

        assertEq(node.totalAssets(), 100 ether);
        assertEq(vault.totalAssets(), 90 ether);
        assertEq(vault.convertToAssets(vault.balanceOf(address(node))), 90 ether);

        // increase asset holdings of vault to 100 units, node being the only shareholder
        deal(address(asset), address(vault), 100 ether);
        assertEq(vault.totalAssets(), 100 ether);

        uint256 lastRebalance = node.lastRebalance();
        vm.warp(block.timestamp + lastRebalance + 1);

        vm.prank(rebalancer);
        node.startRebalance();

        // assert that calling startRebalance() has updated the cache correctly
        assertEq(vault.convertToAssets(vault.balanceOf(address(node))), 100 ether - 1);
        assertEq(node.totalAssets(), 110 ether - 1);
    }

    function test_startRebalance_revert_CooldownActive() public {
        uint256 lastRebalance = node.lastRebalance();
        assertEq(lastRebalance, block.timestamp);
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.CooldownActive.selector);
        node.startRebalance();
    }

    function test_startRebalance_revert_InvalidComponentRatios() public {
        vm.warp(block.timestamp + 1 days);
        vm.prank(owner);
        node.addComponent(testComponent, ComponentAllocation({targetWeight: 1.2 ether, maxDelta: 0.01 ether}));

        vm.startPrank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidComponentRatios.selector);
        node.startRebalance();
    }

    function test_execute() public {
        // Setup minimal test node with just a router
        address[] memory routers = new address[](1);
        routers[0] = testRouter;

        Node simpleNode = new Node(
            address(testRegistry),
            "Test Node",
            "TNODE",
            testAsset,
            owner,
            _toArray(testRouter),
            _toArray(testComponent), // no components
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );

        // Mock the storage slot for lastRebalance to be current timestamp
        uint256 currentTime = block.timestamp;
        uint256 slot = stdstore.target(address(simpleNode)).sig("lastRebalance()").find();
        vm.store(address(simpleNode), bytes32(slot), bytes32(currentTime));
        vm.warp(currentTime + 1);

        // Setup simple transfer call
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, makeAddr("recipient"), 100);

        // Mock the transfer call to return true
        vm.mockCall(testAsset, 0, data, abi.encode(true));

        // Execute as router
        vm.prank(testRouter);
        bytes memory result = simpleNode.execute(testAsset, 0, data);

        // Verify the call succeeded
        assertEq(abi.decode(result, (bool)), true);
    }

    function test_execute_revert_NotRouter() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        testNode.execute(testAsset, 0, "");
    }

    function test_execute_revert_ZeroAddress() public {
        address[] memory routers = new address[](1);
        routers[0] = testRouter;

        Node simpleNode = new Node(
            address(testRegistry),
            "Test Node",
            "TNODE",
            testAsset,
            owner,
            _toArray(testRouter),
            _toArray(testComponent), // no components
            _defaultComponentAllocations(1),
            _defaultReserveAllocation()
        );

        // Mock the storage slot for lastRebalance to be current timestamp
        uint256 currentTime = block.timestamp;
        uint256 slot = stdstore.target(address(simpleNode)).sig("lastRebalance()").find();
        vm.store(address(simpleNode), bytes32(slot), bytes32(currentTime));

        vm.warp(currentTime + 1);

        vm.prank(testRouter);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        simpleNode.execute(address(0), 0, "");
    }

    function test_execute_revert_NotRebalancing() public {
        // Setup a valid router and target
        address target = makeAddr("target");
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, address(this), 100);

        // Mock successful call to avoid other reverts
        vm.mockCall(target, 0, data, abi.encode(true));
        vm.warp(block.timestamp + 2 hours);

        // Try to execute as router
        vm.prank(testRouter);
        vm.expectRevert(ErrorsLib.RebalanceWindowClosed.selector);
        testNode.execute(target, 0, data);
    }

    function test_payManagementFees() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // takes 1% of totalAssets
        registry.setProtocolManagementFee(0.2 ether); // takes 20% of annualManagementFee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);
        assertEq(node.totalAssets(), 100 ether);

        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        uint256 feeForPeriod = node.payManagementFees();

        assertEq(asset.balanceOf(address(ownerFeesRecipient)), 0.8 ether);
        assertEq(asset.balanceOf(address(protocolFeesRecipient)), 0.2 ether);
        assertEq(feeForPeriod, 1 ether);
        assertEq(node.totalAssets(), 100 ether - feeForPeriod);
    }

    function test_payManagementFees_zeroFees() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0);
        registry.setProtocolManagementFee(0);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);
        assertEq(node.totalAssets(), 100 ether);

        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        node.payManagementFees();

        assertEq(asset.balanceOf(address(ownerFeesRecipient)), 0);
        assertEq(asset.balanceOf(address(protocolFeesRecipient)), 0);
        assertEq(node.totalAssets(), 100 ether);
    }

    function test_payManagementFees_1Days() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // takes 1% of totalAssets
        registry.setProtocolManagementFee(0.2 ether); // takes 20% of annualManagementFee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);
        assertEq(node.totalAssets(), 100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.prank(owner);
        uint256 feeForPeriod = node.payManagementFees();

        assertApproxEqAbs(asset.balanceOf(address(ownerFeesRecipient)) * 365, 0.8 ether, 100);
        assertApproxEqAbs(asset.balanceOf(address(protocolFeesRecipient)) * 365, 0.2 ether, 100);
        assertEq(node.totalAssets(), 100 ether - feeForPeriod);
    }

    function test_payManagementFees_revert_NotEnoughAssets() public {
        _seedNode(100 ether);

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault));

        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        vm.startPrank(owner);
        node.setAnnualManagementFee(0.2e18);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.NotEnoughAssetsToPayFees.selector,
                20 ether, // expected fee amount
                10 ether // actual balance
            )
        );

        node.payManagementFees();
    }

    function test_payManagementFees_revert_NotOwnerOrRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(); // Will revert due to onlyOwnerOrRebalancer modifier
        node.payManagementFees();
    }

    function test_payManagementFees_revert_DuringRebalance() public {
        // Start a rebalance
        vm.warp(block.timestamp + 1 days);
        vm.prank(rebalancer);
        node.startRebalance();

        // Try to pay fees during rebalance
        vm.prank(owner);
        vm.expectRevert(); // Will revert due to onlyWhenNotRebalancing modifier
        node.payManagementFees();
    }

    function test_payManagementFees_NoFeesIfZeroAssets() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();
        // Ensure no assets in node
        assertEq(node.totalAssets(), 0);

        vm.warp(block.timestamp + 1 days);

        vm.prank(owner);
        uint256 feesPaid = node.payManagementFees();

        assertEq(feesPaid, 0);
    }

    function test_payManagementFees_PartialYear() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);

        // Warp 6 months into the future
        vm.warp(block.timestamp + 182.5 days);

        vm.prank(owner);
        uint256 feesPaid = node.payManagementFees();

        // Should be approximately 0.5 ether (half of 1% of 100 ether)
        assertApproxEqAbs(feesPaid, 0.5 ether, 0.01 ether);
        assertApproxEqAbs(asset.balanceOf(ownerFeesRecipient), 0.4 ether, 0.01 ether); // 80% of fees
        assertApproxEqAbs(asset.balanceOf(protocolFeesRecipient), 0.1 ether, 0.01 ether); // 20% of fees
    }

    function test_payManagementFees_MultiplePeriods() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);

        // First period - 6 months
        vm.warp(block.timestamp + 182.5 days);
        vm.prank(owner);
        uint256 firstFeesPaid = node.payManagementFees();

        // Second period - 3 months
        vm.warp(block.timestamp + 91.25 days);
        vm.prank(owner);
        uint256 secondFeesPaid = node.payManagementFees();

        // First period should be ~0.5 ether, second should be ~0.25 ether
        assertApproxEqAbs(firstFeesPaid, 0.5 ether, 0.01 ether);
        assertApproxEqAbs(secondFeesPaid, 0.25 ether, 0.01 ether);
    }

    function test_payManagementFees_UpdatesTotalAssets() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);
        uint256 initialTotalAssets = node.totalAssets();

        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        uint256 feesPaid = node.payManagementFees();

        assertEq(node.totalAssets(), initialTotalAssets - feesPaid);
    }

    function test_payManagementFees_revert_NoFeeAddressSet() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        node.payManagementFees();
    }

    function test_subtractProtocolExecutionFee() public {
        // Seed the node with initial assets
        _seedNode(100 ether);
        uint256 initialTotalAssets = node.totalAssets();
        uint256 executionFee = 0.1 ether;

        // Mock the protocol fee address
        address protocolFeeAddress = makeAddr("protocolFeeAddress");
        vm.prank(owner);
        registry.setProtocolFeeAddress(protocolFeeAddress);

        // Call subtractProtocolExecutionFee as router
        vm.prank(address(router4626));
        node.subtractProtocolExecutionFee(executionFee);

        // Verify fee was transferred and total assets was updated
        assertEq(asset.balanceOf(protocolFeeAddress), executionFee);
        assertEq(node.totalAssets(), initialTotalAssets - executionFee);
    }

    function test_subtractProtocolExecutionFee_revert_NotRouter() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.subtractProtocolExecutionFee(0.1 ether);
    }

    function test_updateTotalAssets() public {
        _seedNode(100 ether);

        // Mock quoter response
        uint256 expectedTotalAssets = 120 ether;
        vm.mockCall(
            address(quoter),
            abi.encodeWithSelector(IQuoter.getTotalAssets.selector, address(node)),
            abi.encode(expectedTotalAssets)
        );

        vm.prank(rebalancer);
        node.updateTotalAssets();

        assertEq(node.totalAssets(), expectedTotalAssets);
    }

    function test_updateTotalAssets_revert_NotRebalancer() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.updateTotalAssets();
    }

    function test_fulfillRedeemFromReserve() public {
        deal(address(asset), address(user), 100 ether);
        _userDeposits(user, 100 ether);

        _userRequestsRedeem(user, 50 ether);

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        assertEq(node.balanceOf(user), 50 ether);
        assertEq(node.totalAssets(), 50 ether);
        assertEq(node.totalSupply(), node.convertToShares(50 ether));

        assertEq(asset.balanceOf(address(escrow)), 50 ether);
        assertEq(node.claimableRedeemRequest(0, user), 50 ether);
    }

    function test_fulfillRedeemFromReserve_revert_NoPendingRedeemRequest() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NoPendingRedeemRequest.selector);
        node.fulfillRedeemFromReserve(user);
    }

    function test_fulfillRedeemFromReserve_revert_ExceedsAvailableReserve() public {
        deal(address(asset), address(user), 100 ether);
        _userDeposits(user, 100 ether);

        vm.prank(rebalancer);
        uint256 investedAssets = router4626.invest(address(node), address(vault));
        uint256 remainingReserve = node.totalAssets() - investedAssets;

        assertGt(50 ether, remainingReserve);

        _userRequestsRedeem(user, 50 ether);

        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.ExceedsAvailableReserve.selector);
        node.fulfillRedeemFromReserve(user);
    }

    function test_fulfillRedeemFromReserve_revert_onlyRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.fulfillRedeemFromReserve(user);
    }

    function test_fulfillRedeemFromReserve_revert_onlyWhenRebalancing() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.RebalanceWindowClosed.selector);
        node.fulfillRedeemFromReserve(user);
    }

    function test_fulfilRedeemBatch_fromReserve() public {
        _seedNode(1_000_000 ether);

        address[] memory components = node.getComponents();
        address[] memory users = new address[](2);
        users[0] = address(user);
        users[1] = address(user2);

        vm.prank(owner);
        node.setLiquidationQueue(components);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.startPrank(user2);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user2);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault));

        vm.startPrank(user);
        node.approve(address(node), node.balanceOf(user));
        node.requestRedeem(node.balanceOf(user), user, user);
        vm.stopPrank();

        vm.startPrank(user2);
        node.approve(address(node), node.balanceOf(user2));
        node.requestRedeem(node.balanceOf(user2), user2, user2);
        vm.stopPrank();

        console2.log(node.pendingRedeemRequest(0, user));
        console2.log(node.pendingRedeemRequest(0, user2));

        vm.startPrank(rebalancer);
        node.fulfillRedeemBatch(users);

        assertEq(node.balanceOf(user), 0);
        assertEq(node.balanceOf(user2), 0);

        assertEq(node.totalAssets(), 1_000_000 ether);
        assertEq(node.totalSupply(), node.convertToShares(1_000_000 ether));

        assertEq(asset.balanceOf(address(escrow)), 200 ether);
        assertEq(node.claimableRedeemRequest(0, user), 100 ether);
        assertEq(node.claimableRedeemRequest(0, user2), 100 ether);
    }

    function test_fulfilRedeemBatch_fromReserve_revert_onlyRebalancer() public {
        address[] memory users = new address[](2);
        users[0] = address(user);
        users[1] = address(user2);

        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.fulfillRedeemBatch(users);
    }

    function test_fulfilRedeemBatch_fromReserve_revert_onlyWhenRebalancing() public {
        address[] memory users = new address[](2);
        users[0] = address(user);
        users[1] = address(user2);
        vm.warp(block.timestamp + 1 days);

        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.RebalanceWindowClosed.selector);
        node.fulfillRedeemBatch(users);
    }

    function test_finalizeRedemption() public {
        _seedNode(100 ether);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 sharesToRedeem = node.convertToShares(50 ether);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        uint256 totalAssetsBefore = node.totalAssets();
        uint256 cacheTotalAssetsBefore = Node(address(node)).cacheTotalAssets();
        uint256 sharesAtEscowBefore = node.balanceOf(address(escrow));

        (uint256 pendingBefore, uint256 claimableBefore, uint256 claimableAssetsBefore, uint256 sharesAdjustedBefore) =
            node.getRequestState(user);

        vm.prank(address(router4626));
        node.finalizeRedemption(user, 50 ether, sharesToRedeem, sharesToRedeem);

        (uint256 pendingAfter, uint256 claimableAfter, uint256 claimableAssetsAfter, uint256 sharesAdjustedAfter) =
            node.getRequestState(user);

        // assert vault state and variables are correctly updated
        assertEq(node.sharesExiting(), 0);
        assertEq(node.totalAssets(), totalAssetsBefore - 50 ether);
        assertEq(Node(address(node)).cacheTotalAssets(), cacheTotalAssetsBefore - 50 ether);
        assertEq(node.balanceOf(address(escrow)), sharesAtEscowBefore - sharesToRedeem);

        // assert request state is correctly updated
        assertEq(pendingAfter, pendingBefore - sharesToRedeem);
        assertEq(claimableAfter, claimableBefore + sharesToRedeem);
        assertEq(claimableAssetsAfter, claimableAssetsBefore + 50 ether);
        assertEq(sharesAdjustedAfter, sharesAdjustedBefore - sharesToRedeem);
    }

    function test_finalizeRedemption_revert_onlyRouter() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.finalizeRedemption(user, 50 ether, 100, 100);
    }

    // ERC-7540 FUNCTIONS

    function test_requestRedeem() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        assertEq(node.pendingRedeemRequest(0, user), shares);
    }

    function test_requestRedeem_revert_InsufficientBalance() public {
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);
        node.requestRedeem(1 ether, user, user);
        vm.stopPrank();
    }

    function test_requestRedeem_revert_ZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        node.requestRedeem(0, user, user);
        vm.stopPrank();
    }

    function test_requestRedeem_updates_requestState() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;

        uint256 pending;
        uint256 claimable;
        uint256 claimableAssets;
        uint256 sharesAdjusted;

        (pending, claimable, claimableAssets, sharesAdjusted) = node.getRequestState(user);

        assertEq(pending, 0);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, 0);

        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        (pending, claimable, claimableAssets, sharesAdjusted) = node.getRequestState(user);

        assertEq(pending, shares);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, shares); // no swing factor applied
    }

    function test_pendingRedeemRequest() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        assertEq(node.pendingRedeemRequest(0, user), shares);
    }

    function test_pendingRedeemRequest_isZero() public view {
        assertEq(node.pendingRedeemRequest(0, user), 0);
    }

    function test_claimableRedeemRequest() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        assertEq(node.claimableRedeemRequest(0, user), shares);
    }

    function test_claimableRedeemRequest_isZero() public view {
        assertEq(node.claimableRedeemRequest(0, user), 0);
    }

    function test_setOperator() public {
        vm.prank(user);
        node.setOperator(address(rebalancer), true);
        assertTrue(node.isOperator(user, address(rebalancer)));
    }

    function test_setOperator_RevertIf_Self() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.CannotSetSelfAsOperator.selector);
        node.setOperator(user, true);
    }

    function test_setOperator_EmitEvent() public {
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Operator.OperatorSet(user, address(randomUser), true);
        node.setOperator(address(randomUser), true);
    }

    function test_supportsInterface() public view {
        assertTrue(node.supportsInterface(type(IERC7540Redeem).interfaceId));
        assertTrue(node.supportsInterface(type(IERC7540Operator).interfaceId));
        assertTrue(node.supportsInterface(type(IERC7575).interfaceId));
        assertTrue(node.supportsInterface(type(IERC165).interfaceId));
    }

    function test_supportsInterface_ReturnsFalseForUnsupportedInterface() public view {
        bytes4 unsupportedInterfaceId = 0xffffffff; // An example of an unsupported interface ID
        assertFalse(node.supportsInterface(unsupportedInterfaceId));
    }

    // ERC-4626 FUNCTIONS

    function test_deposit(uint256 assets) public {
        vm.assume(assets < maxDeposit);
        uint256 shares = node.convertToShares(assets);

        deal(address(asset), address(user), assets);
        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);
        vm.stopPrank();

        _verifySuccessfulEntry(user, assets, shares);
    }

    function test_mint(uint256 assets) public {
        vm.assume(assets < maxDeposit);

        uint256 shares = node.convertToShares(assets);
        uint256 expectedShares = node.previewDeposit(assets);
        assertEq(shares, expectedShares);

        deal(address(asset), address(user), assets);
        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.mint(shares, user);
        vm.stopPrank();

        _verifySuccessfulEntry(user, assets, shares);
    }

    function test_withdraw_base(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 maxWithdraw = node.maxWithdraw(user);
        uint256 maxRedeem = node.maxRedeem(user);

        vm.prank(user);
        uint256 withdrawShares = node.withdraw(maxWithdraw, user, user);

        assertEq(withdrawShares, maxRedeem);
        assertEq(asset.balanceOf(user), maxWithdraw);
        assertEq(node.maxWithdraw(user), 0);
        assertEq(node.maxRedeem(user), 0);

        (uint256 pending, uint256 claimable, uint256 claimableAssets, uint256 sharesAdjusted) =
            node.getRequestState(user);
        assertEq(pending, 0);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, 0);
    }

    function test_withdraw(uint256 depositAmount, uint256 seedAmount, uint256 amountToWithdraw) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        amountToWithdraw = bound(amountToWithdraw, 1, depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        uint256 shares = node.deposit(depositAmount, user);
        uint256 sharesToRedeem = node.convertToShares(amountToWithdraw);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        uint256 assetsReceived = node.withdraw(amountToWithdraw, user, user);

        assertEq(assetsReceived, amountToWithdraw);
        assertEq(node.balanceOf(user), shares - sharesToRedeem);
        assertEq(asset.balanceOf(user), amountToWithdraw);
    }

    function test_withdraw_edge_cases() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        node.withdraw(0, user, user);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.InvalidController.selector);
        node.withdraw(1 ether, user, randomUser);

        uint256 depositAmount = 1 ether;
        _seedNode(depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 maxWithdraw = node.maxWithdraw(user);

        // try to withdraw more than available
        vm.prank(user);
        vm.expectRevert(ErrorsLib.ExceedsMaxWithdraw.selector);
        node.withdraw(maxWithdraw + 1, user, user);
    }

    function test_redeem(uint256 depositAmount, uint256 sharesToRedeem, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        sharesToRedeem = bound(sharesToRedeem, 1, depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        uint256 expectedAssets = node.convertToAssets(sharesToRedeem);

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        uint256 assetsReceived = node.redeem(sharesToRedeem, user, user);

        assertEq(assetsReceived, expectedAssets);
        assertEq(node.balanceOf(user), shares - sharesToRedeem);
        assertEq(asset.balanceOf(user), expectedAssets);
    }

    function test_totalAssets(uint256 depositAmount, uint256 seedAmount, uint256 additionalDeposit) public {
        depositAmount = bound(depositAmount, 1, 1e30);
        additionalDeposit = bound(additionalDeposit, 1, 1e36 - depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);

        assertEq(node.totalAssets(), 0);

        _seedNode(seedAmount);

        assertEq(node.totalAssets(), seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount + additionalDeposit);
        asset.approve(address(node), type(uint256).max);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        assertEq(node.totalAssets(), depositAmount + seedAmount);

        vm.prank(rebalancer);
        node.updateTotalAssets();

        assertEq(node.totalAssets(), depositAmount + seedAmount);

        vm.prank(user);
        node.deposit(additionalDeposit, user);

        assertEq(node.totalAssets(), depositAmount + seedAmount + additionalDeposit);
    }

    function test_convertToShares() public {
        assertEq(node.totalAssets(), 0);
        assertEq(node.totalSupply(), 0);
        assertEq(node.convertToShares(1e18), 1e18);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        assertEq(node.convertToShares(1 ether), 1 ether);

        deal(address(asset), address(node), 200 ether);

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.convertToShares(2 ether), 1 ether);
    }

    function test_convertToAssets() public {
        assertEq(node.totalAssets(), 0);
        assertEq(node.totalSupply(), 0);
        assertEq(node.convertToAssets(1e18), 1e18);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        assertEq(node.convertToAssets(1 ether), 1 ether);

        deal(address(asset), address(node), 200 ether);
        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.convertToAssets(1 ether), 2 ether - 1); // minus 1 to account for rounding
    }

    function test_maxDeposit() public {
        assertEq(node.maxDeposit(user), maxDeposit);

        vm.warp(block.timestamp + 25 hours);
        assertEq(node.maxDeposit(user), 0);
    }

    function test_maxMint() public {
        assertEq(node.maxMint(user), maxDeposit);

        vm.warp(block.timestamp + 25 hours);
        assertEq(node.maxMint(user), 0);
    }

    function test_previewDeposit(uint256 amount) public view {
        assertEq(node.convertToShares(amount), node.previewDeposit(amount));
    }

    function test_previewMint(uint256 amount) public view {
        assertEq(node.convertToAssets(amount), node.previewMint(amount));
    }

    function test_previewWithdraw() public {
        vm.expectRevert();
        node.previewWithdraw(1);
    }

    function test_previewRedeem() public {
        vm.expectRevert();
        node.previewRedeem(1);
    }

    // VIEW FUNCTIONS

    function test_getRequestState(uint256 depositAmount, uint256 seedAmount, uint256 sharesToRedeem) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        sharesToRedeem = bound(depositAmount, 1, depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(depositAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        (uint256 pending, uint256 claimable, uint256 claimableAssets, uint256 sharesAdjusted) =
            node.getRequestState(user);
        assertEq(pending, sharesToRedeem);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, sharesToRedeem);

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        (pending, claimable, claimableAssets, sharesAdjusted) = node.getRequestState(user);
        assertEq(pending, 0);
        assertEq(claimable, sharesToRedeem);
        assertEq(claimableAssets, node.convertToAssets(sharesToRedeem));
        assertEq(sharesAdjusted, 0);
    }

    function test_getLiquidationsQueue() public {
        vm.warp(block.timestamp + 1 days);

        address component1 = makeAddr("component1");
        address component2 = makeAddr("component2");
        address component3 = makeAddr("component3");

        vm.startPrank(owner);
        node.addComponent(component3, ComponentAllocation({targetWeight: 0.3 ether, maxDelta: 0.01 ether}));
        node.addComponent(component2, ComponentAllocation({targetWeight: 0.3 ether, maxDelta: 0.01 ether}));
        node.addComponent(component1, ComponentAllocation({targetWeight: 0.4 ether, maxDelta: 0.01 ether}));
        vm.stopPrank();

        // incorrect component order on purpose
        address[] memory expectedQueue = new address[](3);
        expectedQueue[0] = component1;
        expectedQueue[1] = component3;
        expectedQueue[2] = component2;

        vm.prank(owner);
        node.setLiquidationQueue(expectedQueue);

        address[] memory liquidationQueue = node.getLiquidationsQueue();
        assertEq(liquidationQueue.length, expectedQueue.length);
        for (uint256 i = 0; i < expectedQueue.length; i++) {
            assertEq(liquidationQueue[i], expectedQueue[i]);
        }
    }

    // todo: fix this test
    function test_getSharesExiting(uint256 depositAmount, uint256 redeemAmount) public {
        _seedNode(100 ether);
        depositAmount = bound(depositAmount, 1 ether, 1e36);
        deal(address(asset), user, depositAmount);

        uint256 shares = _userDeposits(user, depositAmount);
        redeemAmount = bound(redeemAmount, 1, shares);

        if (redeemAmount > shares) {
            redeemAmount = shares;
        }
        uint256 sharesExiting = node.getSharesExiting();
        assertEq(sharesExiting, 0);

        vm.startPrank(user);
        node.approve(address(node), redeemAmount);
        node.requestRedeem(redeemAmount, user, user);
        vm.stopPrank();

        sharesExiting = node.getSharesExiting();
        assertEq(sharesExiting, redeemAmount);
    }

    function test_targetReserveRatio(uint256 targetWeight) public {
        targetWeight = bound(targetWeight, 0.01 ether, 0.99 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.updateReserveAllocation(ComponentAllocation({targetWeight: targetWeight, maxDelta: 0.01 ether}));
        node.updateComponentAllocation(
            address(vault), ComponentAllocation({targetWeight: 1e18 - targetWeight, maxDelta: 0.01 ether})
        );
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance(); // if this runs ratios are validated

        uint256 reserveRatio = node.targetReserveRatio();
        assertEq(reserveRatio, targetWeight);
    }

    function test_getComponents() public {
        vm.warp(block.timestamp + 1 days);

        address component1 = makeAddr("component1");
        address component2 = makeAddr("component2");

        vm.startPrank(owner);
        node.addComponent(component1, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));
        node.addComponent(component2, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));
        vm.stopPrank();

        address[] memory components = node.getComponents();
        assertEq(components.length, 3); // there's an extra component defined in the base test
        assertEq(components[1], component1);
        assertEq(components[2], component2);
    }

    function test_getComponentRatio(uint256 weight) public {
        vm.warp(block.timestamp + 1 days);

        address component = makeAddr("component");
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: weight, maxDelta: 0.01 ether});

        vm.prank(owner);
        node.addComponent(component, allocation);

        uint256 componentRatio = node.getComponentRatio(component);
        assertEq(componentRatio, allocation.targetWeight);
    }

    function test_isComponent() public {
        address randomAddress = makeAddr("random");
        assertFalse(node.isComponent(randomAddress));

        vm.warp(block.timestamp + 1 days);

        vm.prank(owner);
        node.addComponent(testComponent, ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether}));
        assertTrue(node.isComponent(testComponent));
    }

    function test_getMaxDelta(uint256 amount) public {
        vm.warp(block.timestamp + 2 days);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: amount});

        vm.prank(owner);
        node.addComponent(testComponent, allocation);

        uint256 maxDelta = node.getMaxDelta(testComponent);
        assertEq(maxDelta, amount);
        assertEq(maxDelta, allocation.maxDelta);
    }

    function test_isCacheValid() public view {
        assertEq(block.timestamp, node.lastRebalance());
        assertEq(node.isCacheValid(), true);
    }

    function test_isCacheValid_isFalse() public {
        uint256 lastRebalance = node.lastRebalance();
        vm.warp(block.timestamp + lastRebalance + 1);
        assertFalse(node.isCacheValid());
    }

    // INTERNAL FUNCTIONS
    // todo: test this function afer you finalize controller, operator, msg.sender functionality
    function test_validateController() public {}

    function test_setReserveAllocation() public {}

    function test_setRouters() public {}

    function test_componentAllocationAndValidation(uint64 comp1, uint64 comp2) public {
        vm.assume(uint256(comp1) + uint256(comp2) < 1e18);
        uint256 reserve = 1e18 - uint256(comp1) - uint256(comp2);
        ComponentAllocation[] memory allocations = new ComponentAllocation[](2);
        allocations[0] = ComponentAllocation({targetWeight: comp1, maxDelta: 0.01 ether});
        allocations[1] = ComponentAllocation({targetWeight: comp2, maxDelta: 0.01 ether});
        ComponentAllocation memory reserveAllocation =
            ComponentAllocation({targetWeight: reserve, maxDelta: 0.01 ether});

        address[] memory routers = new address[](1);
        routers[0] = testRouter;

        address[] memory components = new address[](2);
        components[0] = testComponent;
        components[1] = testComponent2;

        Node node = new Node(
            address(testRegistry),
            "Test Node",
            "TNODE",
            testAsset,
            owner,
            routers,
            components,
            allocations,
            reserveAllocation
        );
    }

    function test_validateComponentRatios_revert_invalidComponentRatios() public {
        ComponentAllocation[] memory invalidAllocation = new ComponentAllocation[](1);
        invalidAllocation[0] = ComponentAllocation({targetWeight: 0.2 ether, maxDelta: 0.01 ether});

        address[] memory routers = new address[](1);
        routers[0] = testRouter;

        vm.expectRevert(ErrorsLib.InvalidComponentRatios.selector);

        new Node(
            address(testRegistry),
            "Test Node",
            "TNODE",
            testAsset,
            owner,
            routers,
            _toArray(testComponent),
            invalidAllocation,
            ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0.01 ether})
        );

        invalidAllocation[0] = ComponentAllocation({targetWeight: 1.2 ether, maxDelta: 0.01 ether});

        vm.expectRevert(ErrorsLib.InvalidComponentRatios.selector);
        new Node(
            address(testRegistry),
            "Test Node",
            "TNODE",
            testAsset,
            owner,
            routers,
            _toArray(testComponent),
            invalidAllocation,
            ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0.01 ether})
        );
    }

    function test_onDepositClaimable(uint256 depositAmount) public {
        address controller = makeAddr("controller");
        uint256 sharesToMint = node.convertToShares(depositAmount);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.DepositClaimable(controller, 0, depositAmount, sharesToMint);
        node.onDepositClaimable(controller, depositAmount, sharesToMint);
    }

    function test_onRedeemClaimable(uint256 redeemAmount) public {
        address controller = makeAddr("controller");
        uint256 sharesToRedeem = node.convertToShares(redeemAmount);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.RedeemClaimable(controller, 0, redeemAmount, sharesToRedeem);
        node.onRedeemClaimable(controller, redeemAmount, sharesToRedeem);
    }

    // HELPER FUNCTIONS
    function _verifySuccessfulEntry(address user, uint256 assets, uint256 shares) internal view {
        assertEq(asset.balanceOf(address(node)), assets);
        assertEq(asset.balanceOf(user), 0);
        assertEq(node.balanceOf(user), shares);
        assertEq(asset.balanceOf(address(escrow)), 0);
    }
}
