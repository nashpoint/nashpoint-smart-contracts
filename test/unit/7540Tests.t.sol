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
        uint256 user1PendingDeposits = liquidityPool.pendingDepositRequest(address(user1));
        assertEq(DEPOSIT_10, user1PendingDeposits);

        vm.startPrank(user1);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user1), address(user1));
        vm.stopPrank();

        vm.startPrank(user2);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user2), address(user2));
        vm.stopPrank();

        // basic math checks
        user1PendingDeposits = liquidityPool.pendingDepositRequest(address(user1));
        assertEq(user1PendingDeposits, DEPOSIT_10 * 2);

        uint256 user2PendingDeposits = liquidityPool.pendingDepositRequest(address(user2));
        assertEq(user2PendingDeposits, DEPOSIT_10);

        // assert user1 cannot claim yet
        uint256 user1ClaimableDeposits = liquidityPool.claimableDepositRequest(0, address(user1));
        assertEq(user1ClaimableDeposits, 0);
    }

    function testProcessPendingDeposits() public {
        vm.startPrank(user1);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user1), address(user1));
        vm.stopPrank();

        // get shares user should get after 4626 mint occurs
        uint256 sharesDue = liquidityPool.convertToShares(DEPOSIT_10);

        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // get shares made claimable to user after deposits processed
        uint256 sharesClaimable = liquidityPool.claimableDepositRequest(0, address(user1));

        // assert shares claimable are accurate to 0.01% margin of error
        assertApproxEqRel(sharesDue, sharesClaimable, 1e12);

        // assert any rounding is in favour of the vault
        assertGt(sharesDue, sharesClaimable);

        vm.startPrank(user2);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user2), address(user2));
        vm.stopPrank();

        vm.startPrank(user3);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user3), address(user3));
        vm.stopPrank();

        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // assert users in the same processPendingDeposits tx get the same shares
        uint256 user2sharesClaimable = liquidityPool.claimableDepositRequest(0, address(user2));
        uint256 user3sharesClaimable = liquidityPool.claimableDepositRequest(0, address(user3));
        assertEq(user2sharesClaimable, user3sharesClaimable);

        // show all pendingDeposits have been cleared
        vm.expectRevert();
        liquidityPool.pendingDepositRequest(address(user1));
        vm.expectRevert();
        liquidityPool.pendingDepositRequest(address(user2));
        vm.expectRevert();
        liquidityPool.pendingDepositRequest(address(user3));

        // assert controllerToIndex mapping has been cleared
        uint256 index1 = liquidityPool.controllerToIndex(address(user1));
        uint256 index2 = liquidityPool.controllerToIndex(address(user2));
        uint256 index3 = liquidityPool.controllerToIndex(address(user3));
        assertEq(index1, 0);
        assertEq(index2, 0);
        assertEq(index3, 0);

        // user1 mints all available share
        vm.startPrank(user1);
        liquidityPool.mint(sharesClaimable, address(user1));
        vm.stopPrank();

        // assert no shares left to be minted
        uint256 remainingShares = liquidityPool.claimableDepositRequest(0, address(user1));
        assertEq(remainingShares, 0);

        vm.startPrank(user2);
        // user2 mints half their available shares
        liquidityPool.mint(user2sharesClaimable / 2, (address(user2)));

        // expect revert: ExceedsPendingDeposit
        vm.expectRevert();
        liquidityPool.mint(user2sharesClaimable * 2, (address(user2)));

        // assert remaining shares are correct
        uint256 user2remainingShares = liquidityPool.claimableDepositRequest(0, address(user2));
        assertEq(user2sharesClaimable / 2, user2remainingShares);

        // mint remaining shares
        liquidityPool.mint(user2remainingShares, address(user2));

        vm.expectRevert();
        liquidityPool.mint(user2sharesClaimable, address(user2));
    }
}
