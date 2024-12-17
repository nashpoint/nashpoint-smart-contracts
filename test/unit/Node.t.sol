// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
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

    string constant TEST_NAME = "Test Node";
    string constant TEST_SYMBOL = "TNODE";

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

    function test_constructor() public view {
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
        vm.prank(owner);
        testNode.initialize(testEscrow);

        assertEq(address(testNode.escrow()), testEscrow);
        assertFalse(testNode.swingPricingEnabled());
        assertTrue(testNode.isInitialized());
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
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setQuoter(address(0));
    }

    function test_setQuoter_revert_AlreadySet() public {
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

    function test_execute() public {
        // Setup minimal test node with just a router
        address[] memory routers = new address[](1);
        routers[0] = testRouter;

        Node simpleNode = new Node(
            address(testRegistry),
            "Test Node",
            "TNODE",
            testAsset,
            testQuoter,
            owner,
            testRebalancer,
            routers,
            new address[](0), // no components
            new ComponentAllocation[](0), // no allocations
            ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0.01 ether})
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
        vm.expectRevert(ErrorsLib.NotRouter.selector);
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
            testQuoter,
            owner,
            testRebalancer,
            routers,
            new address[](0), // no components
            new ComponentAllocation[](0), // no allocations
            ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0.01 ether})
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

    /// @dev I did not write tests for requestRedeem()

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

    // Set Operator tests
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

    // Supports Interface tests
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
        assertEq(node.maxDeposit(user), type(uint256).max);

        vm.warp(block.timestamp + 25 hours);
        assertEq(node.maxDeposit(user), 0);
    }

    function test_deposit(uint256 assets) public {
        uint256 shares = node.convertToShares(assets);

        deal(address(asset), address(user), assets);
        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);
        vm.stopPrank();

        _verifySuccessfulEntry(user, assets, shares);
    }

    function test_maxMint() public {
        assertEq(node.maxMint(user), type(uint256).max);

        vm.warp(block.timestamp + 25 hours);
        assertEq(node.maxMint(user), 0);
    }

    function test_mint(uint256 assets) public {
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

    function test_RebalanceCooldown() public {
        _seedNode(100 ether);

        // Cast the interface back to the concrete implementation
        Node node = Node(address(node));

        assertEq(node.cooldownDuration(), 1 days);
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

    function test_cacheIsValid() public view {
        assertEq(block.timestamp, node.lastRebalance());

        assertEq(node.cacheIsValid(), true);
    }

    function test_cacheIsValid_isFalse() public {
        uint256 lastRebalance = node.lastRebalance();
        vm.warp(block.timestamp + lastRebalance + 1);
        assertFalse(node.cacheIsValid());
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

    function test_finalizeRedemption_decrements_cacheTotalAssest() public {
        // todo: write a unit test just for this operation
    }

    function test_redeem(uint256 assets) public {
        vm.assume(assets > 0);

        _seedNode(1);

        uint256 shares = node.convertToShares(assets);
        deal(address(asset), address(user), assets);

        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);

        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        node.redeem(shares, user, user);

        _verifySuccessfulExit(user, assets, 1);
    }

    function test_withdraw(uint256 assets) public {
        vm.assume(assets > 0);

        _seedNode(1);

        uint256 shares = node.convertToShares(assets);
        deal(address(asset), address(user), assets);

        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);

        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        node.withdraw(assets, user, user);

        _verifySuccessfulExit(user, assets, 1);
    }

    // Helper functions
    function _verifySuccessfulEntry(address user, uint256 assets, uint256 shares) internal view {
        assertEq(asset.balanceOf(address(node)), assets);
        assertEq(asset.balanceOf(user), 0);
        assertEq(node.balanceOf(user), shares);
        assertEq(asset.balanceOf(address(escrow)), 0);
    }

    function _verifySuccessfulExit(address user, uint256 assets, uint256 initialBalance) internal view {
        assertEq(asset.balanceOf(address(node)), initialBalance);
        assertEq(asset.balanceOf(user), assets);
        assertEq(node.balanceOf(user), 0);
        assertEq(asset.balanceOf(address(escrow)), 0);
    }
}
