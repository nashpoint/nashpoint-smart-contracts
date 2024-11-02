// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7540Deposit} from "src/interfaces/IERC7540.sol";
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
        assertEq(newNode.rebalancer(), rebalancer);
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

    // Rebalancer tests  
    function test_setRebalancer_RevertIf_AlreadySet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        uninitializedNode.setRebalancer(rebalancer); 
    }

    function test_setRebalancer_RevertIf_NotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.setRebalancer(makeAddr("newRebalancer"));
    }

    // execute tests
    function test_execute() public {
        // Setup a mock contract to call
        address target = makeAddr("target");
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("someFunction()");
        bytes memory expectedResult = abi.encode(true);
        
        // Mock the external call
        vm.mockCall(
            target,
            value,
            data,
            expectedResult
        );
        
        // Call execute as router
        vm.prank(address(router));
        bytes memory result = uninitializedNode.execute(target, value, data);
        
        // Verify the result
        assertEq(result, expectedResult);
    }

    function test_execute_RevertIf_NotRouter() public {
        address target = makeAddr("target");
        bytes memory data = abi.encodeWithSignature("someFunction()");
        
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRouter.selector);
        uninitializedNode.execute(target, 0, data);
    }

    function test_execute_RevertIf_ZeroAddress() public {
        bytes memory data = abi.encodeWithSignature("someFunction()");
        
        vm.prank(address(router));
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.execute(address(0), 0, data);
    }

    function test_execute_WithValue() public {
        // Setup a mock contract to call
        address target = makeAddr("target");
        uint256 value = 1 ether;
        bytes memory data = abi.encodeWithSignature("someFunction()");
        bytes memory expectedResult = abi.encode(true);
        
        // Fund the node contract
        vm.deal(address(uninitializedNode), value);
        
        // Mock the external call
        vm.mockCall(
            target,
            value,
            data,
            expectedResult
        );
        
        // Call execute as router
        vm.prank(address(router));
        bytes memory result = uninitializedNode.execute(target, value, data);
        
        // Verify the result
        assertEq(result, expectedResult);
    }

    function test_execute_RevertIf_CallFails() public {
        address target = makeAddr("target");
        bytes memory data = abi.encodeWithSignature("someFunction()");
        
        // Mock a failing call
        vm.mockCallRevert(
            target,
            0,
            data,
            "Address: low-level call failed"
        );
        
        vm.prank(address(router));
        vm.expectRevert("Address: low-level call failed");
        uninitializedNode.execute(target, 0, data);
    }

    function test_execute_EmitsEvent() public {
        address target = makeAddr("target");
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("someFunction()");
        bytes memory expectedResult = abi.encode(true);
        
        // Mock the external call
        vm.mockCall(
            target,
            value,
            data,
            expectedResult
        );
        
        // Expect the event
        vm.expectEmit(true, true, true, true);
        emit EventsLib.Execute(target, value, data, expectedResult);
        
        // Call execute as router
        vm.prank(address(router));
        uninitializedNode.execute(target, value, data);
    }

    // Escrow tests
    function test_setEscrow() public {
        vm.prank(owner);
        uninitializedNode.setEscrow(address(escrow));

        assertEq(address(uninitializedNode.escrow()), address(escrow));
    }       

    function test_setEscrow_RevertIf_ZeroAddress() public {
        address newEscrow = makeAddr("newEscrow");

        vm.prank(owner);        
        uninitializedNode.setEscrow(newEscrow);
       
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.setEscrow(address(0));
    }

    function test_setEscrow_RevertIf_AlreadySet() public {
        address newEscrow = makeAddr("newEscrow");

        vm.prank(owner);        
        uninitializedNode.setEscrow(newEscrow);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        uninitializedNode.setEscrow(newEscrow);
    }

    function test_setEscrow_RevertIf_NotOwner() public {
        address newEscrow = makeAddr("newEscrow");

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.setEscrow(newEscrow);
    }

    // Manager tests
    function test_setManager() public {
        address newManager = makeAddr("newManager");

        vm.prank(owner);
        uninitializedNode.setManager(newManager);

        assertEq(address(uninitializedNode.manager()), address(newManager));
    }

    function test_setManager_RevertIf_ZeroAddress() public {
        address newManager = makeAddr("newManager");

        vm.prank(owner);
        uninitializedNode.setManager(newManager);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.setManager(address(0));
    }

    function test_setManager_RevertIf_AlreadySet() public {
        address newManager = makeAddr("newManager");

        vm.prank(owner);
        uninitializedNode.setManager(newManager);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        uninitializedNode.setManager(newManager);
    }

    function test_setManager_RevertIf_NotOwner() public {
        address newManager = makeAddr("newManager");

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.setManager(newManager);
    }

    // Quoter tests
    function test_setQuoter() public {
        address newQuoter = makeAddr("newQuoter");

        vm.prank(owner);
        uninitializedNode.setQuoter(newQuoter);

        assertEq(address(uninitializedNode.quoter()), address(newQuoter));
    }

    function test_setQuoter_RevertIf_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.setQuoter(address(0));
    }

    function test_setQuoter_RevertIf_AlreadySet() public {
        address newQuoter = makeAddr("newQuoter");

        vm.prank(owner);
        uninitializedNode.setQuoter(newQuoter);
    }

    function test_setQuoter_RevertIf_NotOwner() public {
        address newQuoter = makeAddr("newQuoter");

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.setQuoter(newQuoter);
    }

    // Request Deposit tests
    function test_requestDeposit() public {
        deal(address(asset), owner, INITIAL_BALANCE);
        vm.startPrank(owner);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, address(queueManager), owner);
    }

    function test_requestDeposit_EmitsEvent() public {
        deal(address(asset), owner, INITIAL_BALANCE);
        vm.startPrank(owner);
        asset.approve(address(node), 1 ether); 
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(address(queueManager), owner, 0, owner, 1 ether);
        node.requestDeposit(1 ether, address(queueManager), owner);
    }
    
    function test_requestDeposit_RevertIf_InsufficientBalance() public {
        uint256 balance = asset.balanceOf(owner);
        
        vm.startPrank(owner);
        asset.approve(address(node), 1 ether);
        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);        
        node.requestDeposit(balance + 1, address(queueManager), owner);
    }

    function test_requestDeposit_RevertIf_InvalidOwner() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.InvalidOwner.selector);
        node.requestDeposit(1 ether, address(queueManager), randomUser);
    }

    function test_requestDeposit_RevertIf_RequestDepositFailed() public {
        // Setup: Give owner some assets and approve spending
        deal(address(asset), owner, INITIAL_BALANCE);
        vm.startPrank(owner);
        asset.approve(address(node), 1 ether);
        
        // Mock the queue manager to return false or revert
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.requestDeposit.selector),
            abi.encode(false)  // or use mockCallRevert for revert case
        );
        
        // Test
        vm.expectRevert(ErrorsLib.RequestDepositFailed.selector);
        node.requestDeposit(1 ether, address(queueManager), owner);
        vm.stopPrank();
    }

    // Pending Deposit Request tests
    function test_pendingDepositRequest() public {
        deal(address(asset), owner, INITIAL_BALANCE);
        vm.startPrank(owner);
        asset.approve(address(node), 1 ether);
        node.requestDeposit(1 ether, address(queueManager), owner);
        uint256 pending = node.pendingDepositRequest(0, address(queueManager));
        assertEq(pending, 1 ether);
    }

    
    // Claimable Deposit Request tests
    function test_claimableDepositRequest() public { 
        // Mock the queue manager to return claimable amount
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.maxDeposit.selector, address(queueManager)),
            abi.encode(1 ether)
        );        
        
        uint256 claimable = node.claimableDepositRequest(0, address(queueManager));
        assertEq(claimable, 1 ether);
        vm.stopPrank();    
    }   

}
