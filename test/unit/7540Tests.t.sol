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
        console2.log("user1PendingDeposits :", user1PendingDeposits);

        vm.startPrank(user1);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user1), address(user1));
        vm.stopPrank();

        vm.startPrank(user2);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user2), address(user2));
        vm.stopPrank();

        // basic math checks
        user1PendingDeposits = liquidityPool.pendingDepositRequest(address(user1));
        assertEq(user1PendingDeposits, DEPOSIT_10 * 2);
        console2.log("user1PendingDeposits :", user1PendingDeposits);

        uint256 user2PendingDeposits = liquidityPool.pendingDepositRequest(address(user2));
        assertEq(user2PendingDeposits, DEPOSIT_10);
        console2.log("user2PendingDeposits :", user2PendingDeposits);

        // assert user1 cannot claim yet
        uint256 user1ClaimableDeposits = liquidityPool.claimableDepositRequest(0, address(user1));
        assertEq(user1ClaimableDeposits, 0);
    }

    function testProcessPendingDeposits() public {
        // get shares user should get after 4626 mint occurs
        uint256 sharesDue = liquidityPool.convertToShares(DEPOSIT_10);

        vm.startPrank(user1);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user1), address(user1));
        vm.stopPrank();

        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // get shares made claimable to user after deposits processed
        uint256 sharesClaimable = liquidityPool.claimableDepositRequest(0, address(user1));

        // assert shares claimable are accurate to 0.01% margin of error
        assertApproxEqRel(sharesDue, sharesClaimable, 1e12);

        if ((sharesDue - sharesClaimable) > 0 || sharesClaimable - sharesDue > 0) {
            // assert any rounding is in favour of the vault
            assertGt(sharesDue, sharesClaimable);
        }

        // users 2 and 3 deposit and banker procesess deposits
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
        uint256 index1 = liquidityPool.controllerToDepositIndex(address(user1));
        uint256 index2 = liquidityPool.controllerToDepositIndex(address(user2));
        uint256 index3 = liquidityPool.controllerToDepositIndex(address(user3));
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

        // expect revert: NoPendingDepositAvailable
        vm.expectRevert();
        liquidityPool.mint(user2sharesClaimable, address(user2));
        vm.stopPrank();

        // Test that function correctly increments claimable deposits

        vm.startPrank(user4);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user4), address(user4));
        vm.stopPrank();

        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        uint256 user4sharesClaimable_A = liquidityPool.claimableDepositRequest(0, address(user4));

        vm.startPrank(user4);
        liquidityPool.requestDeposit(DEPOSIT_10, address(user4), address(user4));
        vm.stopPrank();

        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        uint256 user4sharesClaimable_B = liquidityPool.claimableDepositRequest(0, address(user4));

        // assert that claimableDepositRequests is incrementing processed requests
        assertGt(user4sharesClaimable_B, user4sharesClaimable_A);

    }

    function testRequestRedeem() public {
        userDepositsAndMints(user1, DEPOSIT_10);
        uint256 user1Shares = liquidityPool.balanceOf(address(user1));
        console2.log("user1Shares", user1Shares);

        vm.startPrank(user1);
        liquidityPool.requestRedeem(user1Shares, address(user1), address(user1));

        uint256 user1PendingRedemptions = liquidityPool.pendingRedeemRequest(address(user1));
        console2.log("user1PendingRedemptions", user1PendingRedemptions);

        // assert pendingRedemptions has all user shares
        assertEq(user1Shares, user1PendingRedemptions);

        // expectRevert: Insufficient shares
        vm.expectRevert();
        liquidityPool.requestRedeem(user1Shares, address(user1), address(user1));

        // assert user has transfered all their shares
        assertEq(0, liquidityPool.balanceOf(address(user1)));

        // expectRevert: Cannot request redeem of 0 shares
        vm.expectRevert();
        liquidityPool.requestRedeem(0, address(user1), address(user1));

        vm.stopPrank();
    }

    function testProcessPendingRememptions() public {
        uint256 depositedAssets = DEPOSIT_10;
        console2.log("depositedAssets :", depositedAssets);
        userDepositsAndMints(user1, depositedAssets);

        vm.startPrank(user1);
        uint256 user1Shares = liquidityPool.balanceOf(address(user1));
        liquidityPool.requestRedeem(user1Shares, address(user1), address(user1));
        vm.stopPrank();

        vm.startPrank(manager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();

        uint256 user1ClaimableAssets = liquidityPool.claimableRedeemRequest(0, address(user1));
        console2.log("user1ClaimableAssets :", user1ClaimableAssets);

        uint256 delta = depositedAssets - user1ClaimableAssets;
        console2.log("delta :", delta);
    }

    function testEndToEnd() public {
        address user = address(user1);
        uint256 amount = DEPOSIT_10;
        uint256 startingAssets = liquidityPool.totalAssets();
        uint256 managerShares = liquidityPool.balanceOf(address(manager));

        // assert the starting balance of the vault = shares held by manager 1:1
        assertEq(startingAssets, managerShares);

        vm.startPrank(user);
        liquidityPool.requestDeposit(amount, address(user), address(user));
        vm.stopPrank();

        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // get shares made claimable to user after deposits processed
        uint256 sharesClaimable = liquidityPool.claimableDepositRequest(0, address(user));
        console2.log("sharesClaimable :", sharesClaimable);

        // user mints all available share
        vm.startPrank(user);
        liquidityPool.mint(sharesClaimable, address(user));
        vm.stopPrank();

        // get the minted shares of user
        uint256 sharesReceived = liquidityPool.balanceOf(user);
        console2.log("sharesReceived :", sharesReceived);

        // convert minted shares to assets
        uint256 expectedReturnedAssets = liquidityPool.convertToAssets(sharesReceived);
        console2.log("expectedReturnedAssets :", expectedReturnedAssets);

        // get delta between assets deposited and assets available after mint
        uint256 delta = amount - expectedReturnedAssets;
        console2.log("delta :", delta);

        // assert any delta is only due to rounding
        assertApproxEqAbs(delta, 0, 10);

        vm.startPrank(user);
        liquidityPool.requestRedeem(sharesReceived, user, user);
        vm.stopPrank();

        uint256 assetsRequested = liquidityPool.pendingRedeemRequest(user);
        console2.log("assetsRequested :", assetsRequested);

        // assert any delta is due to rounding
        assertApproxEqAbs(assetsRequested, amount, 100);

        vm.startPrank(manager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();

        uint256 assetsClaimable = liquidityPool.claimableRedeemRequest(0, user);
        console2.log("assetsClaimable :", assetsClaimable);

        // assert any delta is due to rounding
        assertApproxEqAbs(assetsClaimable, amount, 100);
    }

    function testMultipleMints() public {
        uint256 amount = DEPOSIT_10 - 1;

        uint256 expectedShares = liquidityPool.convertToShares(amount);
        console2.log("expectedShares :", expectedShares);

        vm.startPrank(user1);
        liquidityPool.requestDeposit(amount, address(user1), address(user1));
        vm.stopPrank();

        uint256 depositedAssets = liquidityPool.pendingDepositRequest((address(user1)));
        console2.log("depositedAssets :", depositedAssets);

        managerProcessesDeposits();

        uint256 user1claimableShares = liquidityPool.claimableDepositRequest(0, address(user1));
        console2.log("user1claimableShares :", user1claimableShares);

        vm.startPrank(user1);
        liquidityPool.mint(user1claimableShares, address(user1));
        vm.stopPrank();

        uint256 user1shares = liquidityPool.balanceOf(address(user1));
        console2.log("user1shares :", user1shares);

        console2.log("liquidityPool.totalAssets() :", liquidityPool.totalAssets());
        console2.log("liquidityPool.totalSupply() :", liquidityPool.totalSupply());

        // assert shares and assets are 1:1
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());

        uint256 user2expectedShares = liquidityPool.convertToShares(amount);
        uint256 user3expectedShares = liquidityPool.convertToShares(amount);
        uint256 user4expectedShares = liquidityPool.convertToShares(amount);
        console2.log("expectedShares :", user2expectedShares);

        userRequestsDeposit(user2, amount);
        userRequestsDeposit(user3, amount);
        userRequestsDeposit(user4, amount);

        managerProcessesDeposits();

        uint256 user2claimableShares = liquidityPool.claimableDepositRequest(0, user2);
        uint256 user3claimableShares = liquidityPool.claimableDepositRequest(0, user3);
        uint256 user4claimableShares = liquidityPool.claimableDepositRequest(0, user4);
        console2.log("user2claimableShares :", user2claimableShares);
        console2.log("user3claimableShares :", user3claimableShares);
        console2.log("user4claimableShares :", user4claimableShares);

        assertEq(user2expectedShares, user2claimableShares);
        assertEq(user3expectedShares, user3claimableShares);
        assertEq(user4expectedShares, user4claimableShares);

        userMints(address(user2), user2claimableShares);
        userMints(address(user3), user3claimableShares);
        userMints(address(user4), user4claimableShares);

        console2.log("liquidityPool.totalAssets() :", liquidityPool.totalAssets());
        console2.log("liquidityPool.totalSupply() :", liquidityPool.totalSupply());

        // assert shares and assets are 1:1
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());
    }

    // Helper Functions
    function userDepositsAndMints(address user, uint256 amount) public {
        // user requests depost of amount
        vm.startPrank(user);
        liquidityPool.requestDeposit(amount, address(user), address(user));
        vm.stopPrank();

        // manager processes all pending deposits
        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // get shares made claimable to user after deposits processed
        uint256 sharesClaimable = liquidityPool.claimableDepositRequest(0, address(user));

        // user1 mints all available share
        vm.startPrank(user);
        liquidityPool.mint(sharesClaimable, address(user));
        vm.stopPrank();
    }

    function userRequestsDeposit(address user, uint256 amount) public {
        vm.startPrank(user);
        liquidityPool.requestDeposit(amount, address(user), address(user));
        vm.stopPrank();
    }

    function userMints(address user, uint256 amount) public {
        vm.startPrank(user);
        liquidityPool.mint(amount, address(user));
        vm.stopPrank();
    }

    function managerProcessesDeposits() public {
        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();
    }
}
