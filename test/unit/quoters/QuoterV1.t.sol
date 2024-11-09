// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";

contract QuoterV1Test is BaseTest {
    QuoterV1 public quoterV1;

    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        // Add necessary approvals
        escrow.approveMax(address(asset), address(queueManager));
        escrow.approveMax(address(node), address(queueManager));
        node.approveQueueManager();
        vm.stopPrank();
        
        quoterV1 = QuoterV1(address(quoter)); // Use the quoter from BaseTest
    }

    function test_getPrice_WithReserveOnly() public {
        // Setup initial deposit
        deal(address(asset), owner, 100 ether);
        
        // Deposit flow
        vm.startPrank(owner);
        asset.approve(address(node), 100 ether);
        node.requestDeposit(100 ether, owner, owner);
        vm.stopPrank();

        // Fulfill deposit request as rebalancer
        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(owner, 100 ether, 100 ether);

        // Approve escrow and complete deposit
        vm.prank(owner);
        escrow.approveMax(address(node), address(queueManager));
        
        vm.prank(owner);
        node.deposit(100 ether, owner);

        assertEq(node.totalSupply(), 100 ether);

        // Test price (should be 1:1 since all assets are in reserve)
        uint256 price = quoterV1.getPrice(address(node));
        assertEq(price, 1 ether, "Price should be 1:1 with reserve only");
    }

    function test_getPrice_WithErc4626() public {
        deal(address(asset), owner, 100 ether);
        
        vm.startPrank(owner);
        asset.approve(address(node), 100 ether);
        node.requestDeposit(100 ether, owner, owner);
        vm.stopPrank();

        vm.prank(rebalancer);
        queueManager.fulfillDepositRequest(owner, 100 ether, 100 ether);

        vm.startPrank(owner);
        escrow.approveMax(address(node), address(queueManager));
        node.deposit(100 ether, owner);
        vm.stopPrank();

        // Rebalance 50% into ERC4626
        vm.startPrank(rebalancer);
        router.approve(address(node), address(asset), address(vault), 50 ether);
        router.mint(address(node), address(vault), 50 ether);
        vm.stopPrank();

        // Test price (should be 1.5x since half the assets appreciated 2x)
        uint256 price = quoterV1.getPrice(address(node));
        assertEq(price, 1.5 ether, "Price should reflect ERC4626 appreciation");
    }
}
