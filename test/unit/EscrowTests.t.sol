// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract EscrowTest is BaseTest {
    function testEscrowSetup() public {
        node.setEscrow(address(escrow));

        escrow.setNode(address(node));

        // assert that both node and escrow are identifying each other correctly
        assertEq(address(node.escrow()), address(escrow));
        assertEq(address(escrow.node()), address(node));

        // revert: only node address can call deposit
        vm.startPrank(user1);
        vm.expectRevert();
        escrow.deposit(address(usdcMock), 1e6);
        vm.stopPrank();
    }

    function testNodeCanDepositToEscrow() public {
        seedNode();

        // grab full balance of USDC tokens
        uint256 tokensToSend = usdcMock.balanceOf(address(node));

        // banker executes deposit to escrow
        vm.startPrank(banker);
        node.executeEscrowDeposit(address(usdcMock), tokensToSend);
        vm.stopPrank();

        // assert full balance of usdc tokens have been transferred to escrow
        assertEq(usdcMock.balanceOf(address(escrow)), tokensToSend);
        assertEq(usdcMock.balanceOf(address(node)), 0);
    }

    // TODO: write test to check user withdrawal
}
