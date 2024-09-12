// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract ERC7540Tests is BaseTest {
    // TODO: Go through this test and identify any incorrect logic or checks
    // TODO: use logs, and use maxMint
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
        uint256 pendingDeposits = liquidityPool.pendingDepositRequest(0, user);
        assertEq(amount, pendingDeposits);

        // assert user1 cannot claim yet
        uint256 claimableDeposits = liquidityPool.claimableDepositRequest(0, user);
        assertEq(claimableDeposits, 0);

        managerProcessesDeposits();

        // assert claimable shares match deposited assets 1:1
        // BUG:THESE SHOULD NOT BE SHARES
        uint256 sharesClaimable = liquidityPool.maxMint(user);

        // assert shares claimable are accurate to 0.01% margin of error
        assertApproxEqRel(sharesDue, sharesClaimable, 1e12);

        if ((sharesDue - sharesClaimable) > 0 || sharesClaimable - sharesDue > 0) {
            // assert any rounding is in favour of the vault
            assertGt(sharesDue, sharesClaimable);
        }

        // show pendingDeposits have been cleared
        vm.expectRevert();
        liquidityPool.pendingDepositRequest(0, user);

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

    function testRedeemAndWithdrawFlow() public {
        address user = address(user1);
        address notController = address(user2);
        uint256 amount = DEPOSIT_10;
        uint256 startingBalance = START_BALANCE_1000;

        // user deposts and mints to set up the test
        userDepositsAndMints(user, amount);
        uint256 user1Shares = liquidityPool.balanceOf(user);

        // user requests redeem
        userRequestsRedeem(user, user1Shares);

        uint256 pendingRedemptions = liquidityPool.pendingRedeemRequest(0, user);

        // assert pendingRedemptions has all user shares
        assertEq(user1Shares, pendingRedemptions);

        vm.startPrank(user);

        // expectRevert: Insufficient shares
        vm.expectRevert();
        liquidityPool.requestRedeem(user1Shares, user, user);

        // assert user has transfered all their shares
        assertEq(0, liquidityPool.balanceOf(user));

        // expectRevert: Cannot request redeem of 0 shares
        vm.expectRevert();
        liquidityPool.requestRedeem(0, user, user);

        // expectRevert: Not Authorized
        vm.expectRevert();
        liquidityPool.requestRedeem(0, user, notController);

        vm.stopPrank();

        managerProcessesRedemptions();

        // get claimable assets
        uint256 claimableAssets = liquidityPool.claimableRedeemRequest(0, address(user1));

        // assert the user assets that can be withdrawn == user assets deposited
        assertEq(amount, claimableAssets);

        // user withdraws
        userWithdraws(user, claimableAssets);

        // assert user has full starting balance of asset again
        assertEq(usdcMock.balanceOf(user), startingBalance);

        // assert the vault is back in sync, shares == assets
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());

        // user deposits and mints 3 x amount
        userDepositsAndMints(user, amount * 3);

        // assert the vault is back in sync, shares == assets
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());

        // user requestsRedeem and manager processes
        userRequestsRedeem(user, amount);
        managerProcessesRedemptions();

        // assert the vault is back in sync, shares == assets
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());

        // user requestsRedeem and manager processes
        userRequestsRedeem(user, amount);
        managerProcessesRedemptions();

        // assert the vault is back in sync, shares == assets
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());

        // get claimable assets for user and assert they are right
        claimableAssets = liquidityPool.claimableRedeemRequest(0, user);
        assertEq(claimableAssets, amount * 2);

        // user withdraws
        userWithdraws(user, claimableAssets);

        // assert the vault is back in sync, shares == assets
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());

        // user requestsRedeem and manager processes
        userRequestsRedeem(user, amount);
        managerProcessesRedemptions();

        // user withdraws
        userWithdraws(user, amount);

        // assert user has correct starting balance
        assertEq(usdcMock.balanceOf(user), startingBalance);

        // assert the vault is back in sync, shares == assets
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());
    }

    function testMultipleMints() public {
        uint256 amount = DEPOSIT_10;
        uint256 startingAssets = DEPOSIT_100;
        address[3] memory users = [user2, user3, user4];

        // Initial deposit and mint for user1
        userDepositsAndMints(user1, amount);

        // Multiple users deposit
        for (uint256 i = 0; i < users.length; i++) {
            userRequestsDeposit(users[i], amount);
        }

        managerProcessesDeposits();

        // Check and mint for multiple users
        for (uint256 i = 0; i < users.length; i++) {
            uint256 claimableShares = liquidityPool.claimableDepositRequest(0, users[i]);
            userMints(users[i], claimableShares);
            assertEq(liquidityPool.balanceOf(users[i]), claimableShares);
        }

        // Final assertions
        assertEq(liquidityPool.totalAssets(), liquidityPool.totalSupply());
        assertEq(liquidityPool.totalSupply(), amount * 4 + startingAssets); // 1 initial + 3 additional users
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

    function userRequestsRedeem(address user, uint256 amount) public {
        vm.startPrank(user);
        liquidityPool.requestRedeem(amount, user, user);
        vm.stopPrank();
    }

    function userWithdraws(address user, uint256 amount) public {
        vm.startPrank(user);
        liquidityPool.withdraw(amount, address(user), address(user));
        vm.stopPrank();
    }

    function managerProcessesDeposits() public {
        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();
    }

    function managerProcessesRedemptions() public {
        vm.startPrank(manager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();
    }

    function managerSeedsVault() public {
        vm.startPrank(manager);
        liquidityPool.requestDeposit(DEPOSIT_100, manager, manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();
    }
}
