// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract EscrowTest is BaseTest {
    function testEscrowSetup() public {
        vm.startPrank(banker);
        bestia.setEscrow(address(escrow));
        vm.stopPrank();

        escrow.setBestia(address(bestia));

        // assert that both bestia and escrow are identifying each other correctly
        assertEq(address(bestia.escrow()), address(escrow));
        assertEq(address(escrow.bestia()), address(bestia));

        // revert: only bestia address can call deposit  
        vm.startPrank(user1);          
        vm.expectRevert();
        escrow.deposit(address(usdcMock), 1e6);        
        vm.stopPrank();
    }

    function testBestiaCanDepositToEscrow() public {
        seedBestia();

        // grab full balance of USDC tokens
        uint256 tokensToSend = usdcMock.balanceOf(address(bestia));

        // banker executes deposit to escrow
        vm.startPrank(banker);
        bestia.executeEscrowDeposit(address(usdcMock), tokensToSend);
        vm.stopPrank();

        // assert full balance of usdc tokens have been transferred to escrow
        assertEq(usdcMock.balanceOf(address(escrow)), tokensToSend);
        assertEq(usdcMock.balanceOf(address(bestia)), 0);
    }

    // TODO: write test to check user withdrawal
}
