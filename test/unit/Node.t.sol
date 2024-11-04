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
    MockQuoter public mockQuoter;
    address public testComponent;
    address public testOperator;

    function setUp() public override {
        super.setUp(); 
        testOperator = makeAddr("testOperator");
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

        // Setup mock quoter
        mockQuoter = new MockQuoter(1 ether); // 1:1 initial price
        vm.prank(owner);
        node.setQuoter(address(mockQuoter));
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
        deal(address(asset), user, INITIAL_BALANCE);
        vm.startPrank(user);
        asset.approve(address(node), 1 ether); 
        node.requestDeposit(1 ether, user, user);

        assertEq(node.pendingDepositRequest(0, user), 1 ether);
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

        vm.prank(owner);
        escrow.approveMax(address(node), address(queueManager));

        vm.prank(testOperator);
        node.deposit(1 ether, user, user);    
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
        
        // Now expect the event right before the deposit
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
        queueManager.fulfillRedeemRequest(user, uint128(assets), uint128(assets));

        vm.startPrank(owner);        
        escrow.approveMax(address(asset), address(queueManager));
        vm.stopPrank();
        vm.prank(testOperator);
        node.withdraw(assets, user, user);
    }

    function test_withdraw_noOperator() public {
        userDeposits(user, 1 ether);
        uint256 assets = node.convertToAssets(node.balanceOf(user));

        vm.startPrank(user);
        node.approve(address(node), assets);
        node.requestRedeem(assets, user, user);
        vm.stopPrank();     

        vm.prank(rebalancer);
        queueManager.fulfillRedeemRequest(user, uint128(assets), uint128(assets));

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
        queueManager.fulfillRedeemRequest(user, uint128(shares), uint128(shares));

        vm.startPrank(owner);        
        escrow.approveMax(address(asset), address(queueManager));
        vm.stopPrank();
        vm.prank(testOperator);
        node.redeem(shares, user, user);

    }
    
    function test_redeem_noOperator() public {
        userDeposits(user, 1 ether);
        uint256 shares = node.balanceOf(user);

        vm.startPrank(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillRedeemRequest(user, uint128(shares), uint128(shares));

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

    // Uility Functions
    function userDeposits(address user_, uint256 amount_) public {        
        vm.startPrank(user_);
        asset.approve(address(node), amount_); 
        node.requestDeposit(amount_, user_, user_);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(user_, uint128(amount_), uint128(amount_));

        vm.prank(owner);
        escrow.approveMax(address(node), address(queueManager));
        
        vm.prank(user_);
        node.deposit(amount_, user_);               
    }
}
