// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";
import {IQuoterV1} from "src/interfaces/IQuoterV1.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC7540Deposit, IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

contract NodeHarness is Node {
    constructor(
        address registry_,
        string memory name_,
        string memory symbol_,
        address asset_,
        address quoter_,
        address owner_,
        address rebalancer_,
        address[] memory routers_,
        address[] memory components_,
        ComponentAllocation[] memory allocations_,
        ComponentAllocation memory reserveAllocation_
    ) Node(
        registry_,
        name_,
        symbol_,
        asset_,
        quoter_,
        owner_,
        rebalancer_,
        routers_,
        components_,
        allocations_,
        reserveAllocation_
    ) {}

    function validateController(address controller) public view {
        _validateController(controller);
    }    
}

contract MockQuoter {
    uint128 public price;
    
    constructor(uint128 _price) {
        price = _price;
    }
    
    function getPrice(address) external view returns (uint128) {
        return price;
    }
    
    function setPrice(uint128 _price) external {
        price = _price;
    }
}

contract NodeTest is BaseTest {
    Node public uninitializedNode;    
    ComponentAllocation public testAllocation;
    NodeHarness public harness;
    MockQuoter public mockQuoter;
    address public testComponent;
    address public testComponent2;
    address public testComponent3;
    address public testOperator;
    address[] public emptyRouters;

    function setUp() public override {
        super.setUp();
        
        // Add necessary approvals
        vm.startPrank(owner);
        escrow.approveMax(address(asset), address(queueManager));
        escrow.approveMax(address(node), address(queueManager));
        node.approveQueueManager();
        vm.stopPrank();

        testOperator = makeAddr("testOperator");
        testComponent = makeAddr("component1");
        testComponent2 = makeAddr("component2");
        testComponent3 = makeAddr("component3");
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

        // Setup mock quoter
        mockQuoter = new MockQuoter(1 ether); // 1:1 initial price
        vm.prank(owner);
        node.setQuoter(address(mockQuoter));

        harness = new NodeHarness(
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

    function test_constructor_RevertIf_ZeroComponent() public {
        address[] memory components = new address[](2);
        components[0] = testComponent;
        components[1] = address(0); // Zero address component
        
        ComponentAllocation[] memory allocations = new ComponentAllocation[](2);
        allocations[0] = testAllocation;
        allocations[1] = testAllocation;

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
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

    function test_removeComponent() public {
        // Setup mock component with zero balance
        vm.mockCall(
            address(testComponent),  // The component address
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(uninitializedNode)),
            abi.encode(0)  // Return zero balance
        );

        vm.prank(owner);
        uninitializedNode.removeComponent(testComponent);
        assertFalse(uninitializedNode.isComponent(testComponent));
    }

    function test_removeComponent_emitsEvent() public {
        vm.mockCall(
            address(testComponent),  // The component address
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(uninitializedNode)),
            abi.encode(0)  // Return zero balance
        );

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit EventsLib.ComponentRemoved(address(uninitializedNode), testComponent);
        uninitializedNode.removeComponent(testComponent);
    }

    function test_removeComponent_revertIf_notOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.removeComponent(testComponent);
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

    // Update Component Allocation Tests
    function test_updateComponentAllocation() public {
        vm.prank(owner);
        uninitializedNode.updateComponentAllocation(testComponent, testAllocation); 

        (uint256 min, uint256 max, uint256 target) = uninitializedNode.componentAllocations(testComponent);
        assertEq(min, testAllocation.minimumWeight);
        assertEq(max, testAllocation.maximumWeight);
        assertEq(target, testAllocation.targetWeight);  
    }

    function test_updateComponentAllocation_RevertIf_NotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.updateComponentAllocation(testComponent, testAllocation);
    }   

    function test_updateComponentAllocation_RevertIf_NotComponent() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        uninitializedNode.updateComponentAllocation(makeAddr("nonexistent"), testAllocation);
    }

    // Update Reserve Allocation Tests
    function test_updateReserveAllocation() public {
        vm.prank(owner);
        uninitializedNode.updateReserveAllocation(testAllocation);

        (uint256 min, uint256 max, uint256 target) = uninitializedNode.reserveAllocation();
        assertEq(min, testAllocation.minimumWeight);
        assertEq(max, testAllocation.maximumWeight);
        assertEq(target, testAllocation.targetWeight);
    }

    function test_updateReserveAllocation_RevertIf_NotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.updateReserveAllocation(testAllocation);
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

    function test_setRebalancer() public {
        address newRebalancer = makeAddr("newRebalancer");

        vm.prank(owner);        
        uninitializedNode.setRebalancer(newRebalancer);

        assertEq(uninitializedNode.rebalancer(), newRebalancer);
    }

    function test_setRebalancer_EmitsEvent() public {
        address newRebalancer = makeAddr("newRebalancer");

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit EventsLib.SetRebalancer(newRebalancer);
        uninitializedNode.setRebalancer(newRebalancer);
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

    function test_setRebalancer_RevertIf_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        uninitializedNode.setRebalancer(address(0));
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

        vm.startPrank(owner);
        uninitializedNode.setQuoter(newQuoter);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        uninitializedNode.setQuoter(newQuoter);
        vm.stopPrank();
    }

    function test_setQuoter_RevertIf_NotOwner() public {
        address newQuoter = makeAddr("newQuoter");

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        uninitializedNode.setQuoter(newQuoter);
    }

    // Request Deposit tests
    function test_requestDeposit() public {
        deal(address(asset), user, INITIAL_BALANCE);
        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, user, user);

        assertEq(asset.balanceOf(address(escrow)), 1 ether);
        assertEq(node.pendingDepositRequest(0, user), 1 ether);
        assertEq(asset.balanceOf(user), INITIAL_BALANCE - 1 ether);        
    }

    function test_requestDeposit_EmitsEvent() public {
        deal(address(asset), user, INITIAL_BALANCE);
        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(address(queueManager), user, 0, user, 1 ether);
        node.requestDeposit(1 ether, address(queueManager), user);
    }
    
    function test_requestDeposit_RevertIf_InsufficientBalance() public {
        uint256 balance = asset.balanceOf(user);
        
        vm.startPrank(user);
        asset.approve(address(node), 1 ether);
        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);        
        node.requestDeposit(balance + 1, address(queueManager), user);
    }

    function test_requestDeposit_RevertIf_InvalidOwner() public {
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.InvalidOwner.selector);
        node.requestDeposit(1 ether, address(queueManager), randomUser);
    }

    function test_requestDeposit_RevertIf_RequestDepositFailed() public {
        // Setup: Give owner some assets and approve spending
        deal(address(asset), user, INITIAL_BALANCE);
        vm.startPrank(user);
        asset.approve(address(node), 1 ether);
        
        // Mock the queue manager to return false or revert
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.requestDeposit.selector),
            abi.encode(false)  // or use mockCallRevert for revert case
        );
        
        // Test
        vm.expectRevert(ErrorsLib.RequestDepositFailed.selector);
        node.requestDeposit(1 ether, address(queueManager), user);
        vm.stopPrank();
    }

    // Pending Deposit Request tests
    function test_pendingDepositRequest() public {
        deal(address(asset), user, INITIAL_BALANCE);
        vm.startPrank(user);
        asset.approve(address(node), 1 ether);
        node.requestDeposit(1 ether, address(queueManager), user);
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

    function test_claimableDepositRequest_noOperator() public { 
        // Mock the queue manager to return claimable amount
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.maxDeposit.selector, address(randomUser)),
            abi.encode(1 ether)
        );        
        
        uint256 claimable = node.claimableDepositRequest(0, address(randomUser));
        assertEq(claimable, 1 ether);
        vm.stopPrank();    
    }  

    // Request Redeem tests
    function test_requestRedeem() public {
        deal(address(asset), user, INITIAL_BALANCE);
        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user, 1 ether, 1 ether);

        vm.prank(owner);
        escrow.approveMax(address(node), address(queueManager));

        vm.startPrank(user);
        node.deposit(1 ether, user, user);
        node.approve(address(node), 1 ether); 
        uint256 requestId = node.requestRedeem(1 ether, user, user);
        assertEq(requestId, 0);
        vm.stopPrank();

        assertEq(node.pendingRedeemRequest(0, user), 1 ether);
        assertEq(node.balanceOf(user), 0);
        assertEq(node.balanceOf(address(escrow)), 1 ether);
    }

    function test_requestRedeem_RevertIf_InsufficientBalance() public { 
        deal(address(asset), user, INITIAL_BALANCE);
        userDeposits(user, 1 ether);

        vm.startPrank(user);
        node.transfer(randomUser, 0.5 ether);
        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);
        node.requestRedeem(1 ether, user, user);
        vm.stopPrank();
    }

    function test_requestRedeem_RevertIf_RequestRedeemFailed() public {
    // Setup: User has sufficient balance to redeem
    deal(address(asset), user, INITIAL_BALANCE);
        userDeposits(user, 1 ether);

        vm.startPrank(user);
        node.approve(address(node), 1 ether);

        // Mock the QueueManager to return false
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.requestRedeem.selector),
            abi.encode(false)
        );

        // Attempt to request redeem and expect revert
        vm.expectRevert(ErrorsLib.RequestRedeemFailed.selector);
        node.requestRedeem(1 ether, address(queueManager), user);
        vm.stopPrank();
    }

    function test_pendingRedeemRequest() public {
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.pendingRedeemRequest.selector, address(queueManager)),
            abi.encode(1 ether)
        );

        uint256 pending = node.pendingRedeemRequest(0, address(queueManager));
        assertEq(pending, 1 ether);
    }
    
    function test_claimableRedeemRequest() public {
        // Mock the queue manager to return claimable amount
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.maxRedeem.selector, address(queueManager)),
            abi.encode(1 ether)
        );

        uint256 claimable = node.claimableRedeemRequest(0, address(queueManager));
        assertEq(claimable, 1 ether);
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

    // Supports Interface tests
    function test_supportsInterface() public view {
        assertTrue(node.supportsInterface(type(IERC7540Deposit).interfaceId));
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
    function test_totalAssets() public {
        userDeposits(user, 1 ether);        
        uint256 totalAssets_ = 1 ether;
        assertEq(node.totalAssets(), totalAssets_);        
    }

    function test_convertToShares() public {
        userDeposits(user, 1 ether);
        uint256 shares = node.convertToShares(1 ether);
        assertEq(shares, 1 ether);
    }

    function test_convertToAssets() public {
        userDeposits(user, 1 ether);
        uint256 assets = node.convertToAssets(1 ether);
        assertEq(assets, 1 ether);
    }

    function test_maxDeposit() public {
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.maxDeposit.selector, user),
            abi.encode(1 ether)
        );
        assertEq(node.maxDeposit(user), 1 ether);
    }

    function test_deposit() public {
        vm.prank(user);
        node.setOperator(testOperator, true);

        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user, uint128(1 ether), uint128(1 ether));

        assertEq(node.balanceOf(address(escrow)), 1 ether);

        vm.prank(owner);
        escrow.approveMax(address(node), address(queueManager));

        vm.prank(testOperator);
        node.deposit(1 ether, user, user);

        assertEq(node.balanceOf(user), 1 ether);
        assertEq(asset.balanceOf(user), INITIAL_BALANCE - 1 ether);
        assertEq(node.balanceOf(address(escrow)), 0);
    }

    function test_deposit_noOperator() public {        
        // Setup deposit request and approval
        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user, uint128(1 ether), uint128(1 ether));

        vm.startPrank(owner);
        asset.approve(address(node), 1 ether);
        escrow.approveMax(address(node), address(queueManager));
        vm.stopPrank();        
        
        vm.expectEmit(true, true, true, true);
        emit IERC7575.Deposit(user, user, 1 ether, 1 ether);
        
        vm.prank(user);
        node.deposit(1 ether, user);
    }    

    function test_maxMint() public {
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.maxMint.selector, user),
            abi.encode(1 ether)
        );
        assertEq(node.maxMint(user), 1 ether);
    }

    function test_mint() public {
        vm.prank(user);
        node.setOperator(testOperator, true);

        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user, uint128(1 ether), uint128(1 ether));

        vm.prank(owner);
        escrow.approveMax(address(node), address(queueManager));

        vm.prank(testOperator);
        node.mint(1 ether, user, user);  

        assertEq(node.balanceOf(user), 1 ether);
        assertEq(asset.balanceOf(user), INITIAL_BALANCE - 1 ether);
        assertEq(node.balanceOf(address(escrow)), 0);
    }

    function test_mint_noOperator() public {
        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user, uint128(1 ether), uint128(1 ether));

        vm.startPrank(owner);
        asset.approve(address(node), 1 ether);
        escrow.approveMax(address(node), address(queueManager));
        vm.stopPrank();        
        
        vm.expectEmit(true, true, true, true);
        emit IERC7575.Deposit(user, user, 1 ether, 1 ether);
        
        vm.prank(user);
        node.mint(1 ether, user);
    }

    
    
     function test_maxWithdraw() public {
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.maxWithdraw.selector, user),
            abi.encode(1 ether)
        );
        assertEq(node.maxWithdraw(user), 1 ether);
    }

    function test_withdraw() public {
        vm.prank(user);
        node.setOperator(testOperator, true);

        userDeposits(user, 1 ether);
        uint256 assets = node.convertToAssets(node.balanceOf(user));

        vm.startPrank(user);
        node.approve(address(node), assets);
        node.requestRedeem(assets, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillRedeemRequest(user, uint128(assets), uint128(1 ether));

        vm.startPrank(owner);        
        escrow.approveMax(address(asset), address(queueManager));
        vm.stopPrank();
        vm.prank(testOperator);
        node.withdraw(assets, user, user);

        assertEq(node.balanceOf(user), 0);
        assertEq(asset.balanceOf(user), 1 ether);
        assertEq(node.balanceOf(address(escrow)), 0);
    }

    function test_withdraw_noOperator() public {
        userDeposits(user, 1 ether);
        uint256 assets = node.convertToAssets(node.balanceOf(user));

        vm.startPrank(user);
        node.approve(address(node), assets);
        node.requestRedeem(assets, user, user);
        vm.stopPrank();     

        vm.prank(rebalancer);
        queueManager.fulfillRedeemRequest(user, uint128(assets), uint128(1 ether));

        vm.startPrank(owner);        
        escrow.approveMax(address(asset), address(queueManager));
        vm.stopPrank();
        vm.prank(user);
        node.withdraw(assets, user, user);
    }

    function test_maxRedeem() public {
        vm.mockCall(
            address(queueManager),
            abi.encodeWithSelector(IQueueManager.maxRedeem.selector, user),
            abi.encode(1 ether)
        );
        assertEq(node.maxRedeem(user), 1 ether);
    }

    function test_redeem() public {
        vm.prank(user);
        node.setOperator(testOperator, true);

        userDeposits(user, 1 ether);
        uint256 shares = node.balanceOf(user);

        vm.startPrank(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillRedeemRequest(user, uint128(shares), uint128(1 ether));

        vm.startPrank(owner);        
        escrow.approveMax(address(asset), address(queueManager));
        vm.stopPrank();
        vm.prank(testOperator);
        node.redeem(shares, user, user);

        assertEq(node.balanceOf(user), 0);
        assertEq(asset.balanceOf(user), 1 ether);
        assertEq(node.balanceOf(address(escrow)), 0);
    }
    
    function test_redeem_noOperator() public {
        userDeposits(user, 1 ether);
        uint256 shares = node.balanceOf(user);

        vm.startPrank(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillRedeemRequest(user, uint128(shares), uint128(1 ether));

        vm.startPrank(owner);        
        escrow.approveMax(address(asset), address(queueManager));
        vm.stopPrank();
        vm.prank(user);
        node.redeem(shares, user, user);
    }


    // Preview Functions Revert
    function test_previewDeposit_Reverts() public {
        vm.expectRevert();
        node.previewDeposit(1 ether);
    }

    function test_previewMint_Reverts() public {
        vm.expectRevert();
        node.previewMint(1 ether);
    }

    function test_previewWithdraw_Reverts() public {
        vm.expectRevert();
        node.previewWithdraw(1 ether);
    }

    function test_previewRedeem_Reverts() public {
        vm.expectRevert();
        node.previewRedeem(1 ether);
    }

    function test_pricePerShare() public {        
        mockQuoter.setPrice(1 ether);
        assertEq(node.pricePerShare(), 1 ether);
        
        mockQuoter.setPrice(2 ether);
        assertEq(node.pricePerShare(), 2 ether);
        
        mockQuoter.setPrice(0.5 ether);
        assertEq(node.pricePerShare(), 0.5 ether);
        
        mockQuoter.setPrice(0);
        assertEq(node.pricePerShare(), 0);
    }

    function test_getComponents() public {
        address[] memory components = uninitializedNode.getComponents();
        assertEq(components.length, 1);
        assertEq(components[0], address(testComponent));

        vm.startPrank(owner);
        uninitializedNode.addComponent(address(testComponent2), testAllocation);
        uninitializedNode.addComponent(address(testComponent3), testAllocation);
        vm.stopPrank();

        components = uninitializedNode.getComponents();
        assertEq(components.length, 3);
        assertEq(components[0], address(testComponent));
        assertEq(components[1], address(testComponent2));
        assertEq(components[2], address(testComponent3));
    }
    

    function test_isComponent() public view {
        assertTrue(uninitializedNode.isComponent(address(testComponent)));        
    }

    function test_isComponent_false() public view {
        assertFalse(uninitializedNode.isComponent(address(0)));
    }

    function test_mint_onlyQueueManager() public {
        vm.prank(address(queueManager));
        node.mint(user, 1 ether);
        assertEq(node.balanceOf(user), 1 ether);
    } 

    function test_mint_revertNotQueueManager() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.mint(user, 1 ether);
    }

    function test_burn_onlyQueueManager() public {
        vm.prank(address(queueManager));
        node.mint(user, 1 ether);        
        
        vm.prank(address(queueManager));
        node.burn(user, 0.5 ether);
        
        assertEq(node.balanceOf(user), 0.5 ether);
    }

    function test_burn_revertNotQueueManager() public {
        vm.prank(address(queueManager));
        node.mint(user, 1 ether);
        
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.burn(user, 0.5 ether);
    }

    function test_onDepositClaimable() public {
        vm.expectEmit(true, true, true, true);
        emit EventsLib.DepositClaimable(user, 0, 1 ether, 1 ether);
        node.onDepositClaimable(user, 1 ether, 1 ether);
    }

    function test_onRedeemClaimable() public {
        vm.expectEmit(true, true, true, true);
        emit EventsLib.RedeemClaimable(user, 0, 1 ether, 1 ether);
        node.onRedeemClaimable(user, 1 ether, 1 ether);
    }

    function test_validateController() public {
        vm.prank(user);
        harness.setOperator(testOperator, true); 

        vm.prank(testOperator);
        harness.validateController(user);
    }

    function test_validateController_isUser() public {
        vm.prank(user);
        harness.validateController(user);        
    }

    function test_validateController_reverts_invalidController() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.InvalidController.selector);
        harness.validateController(randomUser);
    }   
    
    // Helper Functions
    function userDeposits(address user_, uint256 amount_) public {
        deal(address(asset), user_, amount_);
        
        vm.startPrank(user_);
        asset.approve(address(node), amount_);
        node.requestDeposit(amount_, user_, user_);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user_, uint128(amount_), uint128(amount_));

        vm.prank(user_);
        node.deposit(amount_, user_);
    }   

    function test_fulfillDepositRequest_transfersAssets() public {
        uint256 amount = 100 ether;
        deal(address(asset), user, amount);
        
        // Setup approvals
        vm.startPrank(user);
        asset.approve(address(node), amount);
        node.requestDeposit(amount, user, user);
        vm.stopPrank();

        assertEq(asset.balanceOf(address(escrow)), amount, "Assets should be in escrow initially");
        assertEq(asset.balanceOf(address(node)), 0, "Node should have no assets initially");

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user, uint128(amount), uint128(amount));

        assertEq(asset.balanceOf(address(escrow)), 0, "Escrow should have transferred all assets");
        assertEq(asset.balanceOf(address(node)), amount, "Node should have received the assets");
        assertEq(node.balanceOf(address(escrow)), amount, "Node should have received the assets");
    }

    function test_fulfillRedeemRequest_transfersAssets() public {
        // Controller approves node to transfer assets & shares
        vm.startPrank(user);
        asset.approve(address(node), type(uint256).max); 
        node.approve(address(node), type(uint256).max); 
        vm.stopPrank();

        // Escrow approve manager to transfer assets & shares
        vm.startPrank(address(escrow));
        asset.approve(address(queueManager), type(uint256).max);         
        node.approve(address(queueManager), type(uint256).max); 
        vm.stopPrank();

        // Node approves manager to transfer assets
        vm.prank(address(node));
        asset.approve(address(queueManager), type(uint256).max);

        // User deposits
        uint256 startingBalance = asset.balanceOf(address(user));
        vm.prank(user);                
        node.requestDeposit(100, user, user);

        // Queue Manager fulfills deposit request   
        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user, 100, 100);
        uint256 maxDeposit = node.maxDeposit(user);
        assertEq(maxDeposit, 100);        

        vm.prank(user);         
        node.deposit(maxDeposit, user, user); 

        // User requests redeem
        vm.prank(user);
        node.requestRedeem(100, user, user);

        assertEq(node.balanceOf(address(user)), 0, "User should have no shares");
        assertEq(node.balanceOf(address(escrow)), 100, "Escrow should have shares");                

        // Queue Manager fulfills redeem request
        vm.prank(rebalancer);
        queueManager.fulfillRedeemRequest(user, 100, 100);

        assertEq(node.maxWithdraw(user), 100, "User should have max withdraw");
        assertEq(node.balanceOf(address(escrow)), 0, "Escrow should have no shares");

        // User withdraws
        vm.prank(user);
        node.withdraw(100, user, user);

        assertEq(asset.balanceOf(address(user)), startingBalance, "User should have starting balance");        
    }
}