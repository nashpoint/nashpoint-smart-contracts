// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract ERC7540Tests is BaseTest {

    function testRequestDeposit() public {
        vm.startPrank(user1);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user1), address(user1));
        vm.stopPrank();

        // assert user1 pendingDeposits = deposited amount
        uint256 user1PendingDeposits = liquidityPool.pendingDepositRequest(0, address(user1));
        assertEq(DEPOSIT_10, user1PendingDeposits);

        vm.startPrank(user1);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user1), address(user1));
        vm.stopPrank();

        vm.startPrank(user2);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user2), address(user2));
        vm.stopPrank();

        user1PendingDeposits = liquidityPool.pendingDepositRequest(0, address(user1));
        assertEq(user1PendingDeposits, DEPOSIT_10 * 2);

        uint256 user2PendingDeposits = liquidityPool.pendingDepositRequest(0, address(user2));
        assertEq(user2PendingDeposits, DEPOSIT_10);
    }
}
