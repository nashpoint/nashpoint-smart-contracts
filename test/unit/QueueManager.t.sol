// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {QueueManager} from "src/QueueManager.sol";
import {IQueueManager, QueueState} from "src/interfaces/IQueueManager.sol";
import {INode} from "src/interfaces/INode.sol";
import {Node} from "src/Node.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract QueueManagerHarness is QueueManager {
    constructor(address node_) QueueManager(node_) {}

    function calculatePrice(uint128 assets, uint128 shares) external view returns (uint256 price) {
        return _calculatePrice(assets, shares);
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

contract QueueManagerTest is BaseTest {
    QueueManager public manager;
    QueueManagerHarness public harness;
    MockQuoter public mockQuoter;
    address public controller;
    
    function setUp() public override {
        super.setUp();
        
        // Setup mock quoter
        mockQuoter = new MockQuoter(1 ether);
        controller = makeAddr("controller");

        // Deploy manager and harness
        manager = new QueueManager(address(node));
        harness = new QueueManagerHarness(address(node)); 
        
        vm.startPrank(owner);
        node.setQuoter(address(mockQuoter));
        node.setManager(address(manager));
        
        // Add necessary approvals
        escrow.approveMax(address(asset), address(node));
        escrow.approveMax(address(asset), address(queueManager));
        escrow.approveMax(address(node), address(queueManager));
        asset.approve(address(node), type(uint256).max);
        vm.stopPrank();      
        
        // Controller approves node to transfer asset
        vm.prank(controller);
        asset.approve(address(node), type(uint256).max);   

        // Escrow approve manager to transfer asset
        vm.prank(address(escrow));
        asset.approve(address(manager), type(uint256).max);  
        
        // Label addresses
        vm.label(address(manager), "QueueManager");
        vm.label(address(harness), "QueueManagerHarness");
        vm.label(address(mockQuoter), "MockQuoter");
        vm.label(controller, "Controller");

        deal(address(asset), controller, INITIAL_BALANCE);
    }

    function test_deployment() public {
        QueueManager newManager = new QueueManager(address(node));
        assertEq(address(newManager.node()), address(node));
    }

    function test_deployment_RevertIf_ZeroNode() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new QueueManager(address(0));
    }

    function testPrice() public {
        assertEq(harness.calculatePrice(1, 0), 0);
        assertEq(harness.calculatePrice(0, 1), 0);
        assertEq(harness.calculatePrice(1 ether, 1 ether), 1 ether);
        assertEq(harness.calculatePrice(2 ether, 1 ether), 2 ether);
        assertEq(harness.calculatePrice(1 ether, 2 ether), 0.5 ether);
    }

    function test_requestDeposit() public {
        vm.prank(address(node));
        assertTrue(manager.requestDeposit(100, controller));
        assertEq(manager.pendingDepositRequest(controller), 100);
    }

    function test_requestDeposit_revert_NotNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.requestDeposit(100, controller);
    }

    function test_requestDeposit_revert_ZeroAmount() public {
        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        manager.requestDeposit(0, controller);
    }

    function test_requestRedeem() public {
        vm.prank(address(node));
        assertTrue(manager.requestRedeem(100, controller));
        assertEq(manager.pendingRedeemRequest(controller), 100);
    }

    function test_requestRedeem_revert_NotNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.requestRedeem(100, controller);
    }

    function test_requestRedeem_revert_ZeroAmount() public {
        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        manager.requestRedeem(0, controller);
    }

    function test_fulfillDepositRequest() public {            
        // Setup initial request        
        vm.prank(controller);                
        node.requestDeposit(100, controller, controller);   

        // Test fulfillment
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 50, 50);

        // Verify state changes
        (
            uint128 maxMint,
            uint128 maxWithdraw,
            uint256 depositPrice,
            uint256 redeemPrice,
            uint128 pendingDepositRequest,
            uint128 pendingRedeemRequest
        ) = manager.queueStates(controller);

        assertEq(pendingDepositRequest, 50);
        assertEq(maxMint, 50);
        assertEq(depositPrice, 1 ether);
    }

    function test_fulfillDepositRequest_revert_NotRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.fulfillDepositRequest(controller, 50, 50);
    }

    function test_fulfillDepositRequest_revert_NoPendingRequest() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NoPendingDepositRequest.selector);
        manager.fulfillDepositRequest(controller, 50, 50);
    }

    function test_fulfillRedeemRequest_revert_NotRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.fulfillRedeemRequest(controller, 50, 50);
    }

    function test_fulfillRedeemRequest_revert_NoPendingRequest() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NoPendingRedeemRequest.selector);
        manager.fulfillRedeemRequest(controller, 50, 50);
    }

    function test_convertToShares() public {
        assertEq(manager.convertToShares(100 ether), 100 ether); // 1:1 price
        
        // Change price and test again
        mockQuoter.setPrice(2 ether);
        assertEq(manager.convertToShares(100 ether), 50 ether); // 2:1 price
    }

    function test_convertToAssets() public {
        assertEq(manager.convertToAssets(100 ether), 100 ether); // 1:1 price
        
        // Change price and test again
        mockQuoter.setPrice(2 ether);
        assertEq(manager.convertToAssets(100 ether), 200 ether); // 1:2 price
    }

    function test_maxDeposit() public {
        // Setup initial request
        vm.prank(controller);
        node.requestDeposit(100 ether, controller, controller);         

        // Setup state with deposit price
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 100 ether, 100 ether);

        assertEq(manager.maxDeposit(controller), 100 ether);
    }

    function test_maxMint() public {
        // Setup initial request
        vm.prank(controller);
        node.requestDeposit(100 ether, controller, controller);        

        // Setup state
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 100 ether, 100 ether);

        assertEq(manager.maxMint(controller), 100 ether);
    }
}
