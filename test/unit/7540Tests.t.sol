// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract ERC7540Tests is BaseTest {
    function testDepositAndMintFlow() public {
        address user = address(user1);
        address notController = address(user2);
        uint256 amount = DEPOSIT_10;

        // get shares due after 4626 mint occurs
        uint256 sharesDue = liquidityPool.convertToShares(amount);

        // assert shares = assets 1:1
        assertEq(liquidityPool.totalSupply(), liquidityPool.totalAssets());

        // user1 requests a deposit to liquidity pool
        userRequestsDeposit(user, amount);

        // Revert: Cannot request deposit of 0 assets
        vm.expectRevert();
        userRequestsDeposit(user, 0);

        // Revert: Not authorised
        vm.startPrank(user);
        vm.expectRevert();
        liquidityPool.requestDeposit(amount, user, notController);
        vm.stopPrank();

        // assert user1 pendingDeposits = deposited amount
        uint256 pendingDeposits = liquidityPool.pendingDepositRequest(user);
        assertEq(amount, pendingDeposits);

        // assert user1 cannot claim yet
        uint256 claimableDeposits = liquidityPool.claimableDepositRequest(0, user);
        assertEq(claimableDeposits, 0);

        managerProcessesDeposits();

        // assert claimable shares match deposited assets 1:1
        uint256 sharesClaimable = liquidityPool.claimableDepositRequest(0, user);

        // assert shares claimable are accurate to 0.01% margin of error
        assertApproxEqRel(sharesDue, sharesClaimable, 1e12);

        if ((sharesDue - sharesClaimable) > 0 || sharesClaimable - sharesDue > 0) {
            // assert any rounding is in favour of the vault
            assertGt(sharesDue, sharesClaimable);
        }

        // show pendingDeposits have been cleared
        vm.expectRevert();
        liquidityPool.pendingDepositRequest(user);

        // assert controllerToIndex mapping has been cleared
        uint256 index1 = liquidityPool.controllerToDepositIndex(user);
        assertEq(index1, 0);

        // assert user receives correct shares
        userMints(user, sharesClaimable);
        assertApproxEqRel(liquidityPool.balanceOf(user), amount, 1e12);

        // assert no claimable shares remain and user cannot mint
        vm.expectRevert();
        userMints(user, amount);

        // assert claimable deposits have been cleared for user
        claimableDeposits = liquidityPool.claimableDepositRequest(0, user);
        assertEq(claimableDeposits, 0);

        // assert shares = assets 1:1
        assertEq(liquidityPool.totalSupply(), liquidityPool.totalAssets());

        // user deposits and manager process pending deposits
        userRequestsDeposit(user, amount);
        managerProcessesDeposits();

        // assert mint execeeds claimable amount
        vm.expectRevert();
        userMints(user, amount * 2);

        // user makes second depositRequest without claiming
        uint256 claimableDepositsA = liquidityPool.claimableDepositRequest(0, user);
        userRequestsDeposit(user, amount);
        managerProcessesDeposits();
        uint256 claimableDepositsB = liquidityPool.claimableDepositRequest(0, user);

        // assert that claimableDeposits are incrementing correctly
        assertGt(claimableDepositsB, claimableDepositsA);

        // assert correct shares are being issued
        assertEq(claimableDepositsB, claimableDepositsA * 2);

        // user mints all available shares
        userMints(user, claimableDepositsB);

        // assert user has correct number of shares for 3 deposits
        assertEq(liquidityPool.balanceOf(user), amount * 3);

        // assert shares = assets 1:1
        assertEq(liquidityPool.totalSupply(), liquidityPool.totalAssets());
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
        // user deposits and mints 10 units
        uint256 depositedAssets = DEPOSIT_10;
        userDepositsAndMints(user1, depositedAssets);
        console2.log("depositedAssets :", depositedAssets);

        // get full balance of user and request redeem
        vm.startPrank(user1);
        uint256 user1Shares = liquidityPool.balanceOf(address(user1));
        liquidityPool.requestRedeem(user1Shares, address(user1), address(user1));
        vm.stopPrank();

        // manager processes pending redemptions
        vm.startPrank(manager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();

        // get claimable assets
        uint256 claimableAssets = liquidityPool.claimableRedeemRequest(0, address(user1));
        console2.log("user1ClaimableAssets :", claimableAssets);

        // assert the user assets that can be withdrawn == user assets deposited
        assertEq(depositedAssets, claimableAssets);

        vm.startPrank(user1);
        liquidityPool.withdraw(claimableAssets, address(user1));
        vm.stopPrank();
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
