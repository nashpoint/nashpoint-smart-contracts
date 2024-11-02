// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NodeTest is BaseTest {
    Node public uninitializedNode;
    address public testComponent;
    ComponentAllocation public testAllocation;
    
    function setUp() public override {
        super.setUp();
        
        testComponent = makeAddr("component1");
        testAllocation = ComponentAllocation({
            minimumWeight: 0.3 ether,
            maximumWeight: 0.7 ether,
            targetWeight: 0.5 ether
        });

        // Deploy a fresh uninitialized node for initialization tests
        address[] memory components = new address[](1);
        components[0] = testComponent;
        
        ComponentAllocation[] memory allocations = new ComponentAllocation[](1);
        allocations[0] = testAllocation;

        uninitializedNode = new Node(
            address(registry),
            "Test Node",
            "TNODE",
            address(asset),
            address(quoter),
            owner,
            address(rebalancer),
            _toArray(address(router)),
            components,
            allocations,
            _defaultReserveAllocation()
        );
    }

    function test_constructor() public {
        address[] memory components = new address[](1);
        components[0] = testComponent;
        
        ComponentAllocation[] memory allocations = new ComponentAllocation[](1);
        allocations[0] = testAllocation;

        Node newNode = new Node(
            address(registry),
            "Test Node",
            "TNODE",
            address(asset),
            address(quoter),
            owner,
            address(rebalancer),
            _toArray(address(router)),
            components,
            allocations,
            _defaultReserveAllocation()
        );

        assertEq(address(newNode.registry()), address(registry));
        assertEq(address(newNode.asset()), address(asset));
        assertEq(address(newNode.share()), address(newNode));
        assertEq(address(newNode.quoter()), address(quoter));
        assertEq(newNode.rebalancer(), owner);
        assertTrue(newNode.isRouter(address(router)));
        assertEq(newNode.name(), "Test Node");
        assertEq(newNode.symbol(), "TNODE");
    }

    function test_constructor_RevertIf_ZeroRegistry() public {
        address[] memory components = new address[](1);
        components[0] = testComponent;
        
        ComponentAllocation[] memory allocations = new ComponentAllocation[](1);
        allocations[0] = testAllocation;

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(0),
            "Test Node",
            "TNODE",
            address(asset),
            address(quoter),
            owner,
            address(rebalancer),
            _toArray(address(router)),
            components,
            allocations,
            _defaultReserveAllocation()
        );
    }

    function test_constructor_RevertIf_ZeroAsset() public {
        address[] memory components = new address[](1);
        components[0] = testComponent;
        
        ComponentAllocation[] memory allocations = new ComponentAllocation[](1);
        allocations[0] = testAllocation;

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(registry),
            "Test Node",
            "TNODE",
            address(0),
            address(quoter),
            owner,
            address(rebalancer),
            _toArray(address(router)),
            components,
            allocations,
            _defaultReserveAllocation()
        );
    }

    function test_constructor_RevertIf_LengthMismatch() public {
        address[] memory components = new address[](2);
        components[0] = testComponent;
        components[1] = makeAddr("component2");
        
        ComponentAllocation[] memory allocations = new ComponentAllocation[](1);
        allocations[0] = testAllocation;

        vm.expectRevert(ErrorsLib.LengthMismatch.selector);
        new Node(
            address(registry),
            "Test Node",
            "TNODE",
            address(asset),
            address(quoter),
            owner,
            address(rebalancer),
            _toArray(address(router)),
            components,
            allocations,
            _defaultReserveAllocation()
        );
    }

    function test_initialize() public {
        vm.startPrank(owner);
        uninitializedNode.initialize(address(escrow), address(queueManager));
        vm.stopPrank();

        assertEq(address(uninitializedNode.escrow()), address(escrow));
        assertEq(address(uninitializedNode.manager()), address(queueManager));
        assertTrue(uninitializedNode.isInitialized());
    }

    function test_initialize_RevertIf_NotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert();
        uninitializedNode.initialize(address(escrow), address(queueManager));
    }

    function test_initialize_RevertIf_AlreadyInitialized() public {
        vm.startPrank(owner);
        uninitializedNode.initialize(address(escrow), address(queueManager));
        
        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        uninitializedNode.initialize(address(escrow), address(queueManager));
        vm.stopPrank();
    }

    function test_initialize_RevertIf_ZeroEscrow() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.initialize(address(0), address(queueManager));
    }

    function test_initialize_RevertIf_ZeroManager() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.initialize(address(escrow), address(0));
    }

    // Component Management Tests
    function test_addComponent() public {
        address newComponent = makeAddr("newComponent");
        ComponentAllocation memory allocation = ComponentAllocation({
            minimumWeight: 0.3 ether,
            maximumWeight: 0.7 ether,
            targetWeight: 0.5 ether
        });

        vm.prank(owner);
        uninitializedNode.addComponent(newComponent, allocation);

        assertTrue(uninitializedNode.isComponent(newComponent));
        (uint256 min, uint256 max, uint256 target) = uninitializedNode.componentAllocations(newComponent);
        assertEq(min, allocation.minimumWeight);
        assertEq(max, allocation.maximumWeight);
        assertEq(target, allocation.targetWeight);
    }

    function test_addComponent_RevertIf_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.addComponent(address(0), testAllocation);
    }

    function test_addComponent_RevertIf_AlreadySet() public {
        vm.startPrank(owner);
        uninitializedNode.addComponent(makeAddr("component"), testAllocation);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        uninitializedNode.addComponent(makeAddr("component"), testAllocation);
        vm.stopPrank();
    }

    function test_removeComponent_RevertIf_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        uninitializedNode.removeComponent(makeAddr("nonexistent"));
    }

    function test_removeComponent_RevertIf_NonZeroBalance() public {
        address component = address(new ERC20Mock("Test", "TEST"));
        
        vm.startPrank(owner);
        uninitializedNode.addComponent(component, testAllocation);
        
        // Mock balance
        vm.mockCall(
            component,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(uninitializedNode)),
            abi.encode(1)
        );
        
        vm.expectRevert(ErrorsLib.NonZeroBalance.selector);
        uninitializedNode.removeComponent(component);
        vm.stopPrank();
    }

    // Router Management Tests
    function test_addRouter() public {
        address newRouter = makeAddr("newRouter");
        
        vm.prank(owner);
        uninitializedNode.addRouter(newRouter);
        
        assertTrue(uninitializedNode.isRouter(newRouter));
    }

    function test_addRouter_RevertIf_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.addRouter(address(0));
    }

    function test_addRouter_RevertIf_AlreadySet() public {
        address newRouter = makeAddr("newRouter");
        
        vm.startPrank(owner);
        uninitializedNode.addRouter(newRouter);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        uninitializedNode.addRouter(newRouter);
        vm.stopPrank();
    }

    function test_removeRouter() public {
        address routerToRemove = makeAddr("router");
        
        vm.startPrank(owner);
        uninitializedNode.addRouter(routerToRemove);
        uninitializedNode.removeRouter(routerToRemove);
        vm.stopPrank();
        
        assertFalse(uninitializedNode.isRouter(routerToRemove));
    }

    function test_removeRouter_RevertIf_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        uninitializedNode.removeRouter(makeAddr("nonexistent"));
    }
}
