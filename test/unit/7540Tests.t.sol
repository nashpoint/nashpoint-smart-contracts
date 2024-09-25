// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

// TODO: Write a test for yield distribution and complex withdrawal. Vault might not be fair
contract ERC7540Tests is BaseTest {
    /*//////////////////////////////////////////////////////////////
                            MOCK 7540 TESTS
    ////////////////////////////////////////////////////////////////*/
    function testDepositAndMintFlow() public {
        address user = address(user1);
        address notController = address(user2);
        uint256 amount = DEPOSIT_10;

        // get shares due after 4626 mint occurs
        uint256 sharesDue = liquidityPool.convertToShares(amount);

        // assert shares = assets 1:1
        assertEq(liquidityPool.totalSupply(), liquidityPool.totalAssets());

        // user1 requests a deposit to liquidity pool
        userRequestsDeposit(user, DEPOSIT_10);

        // Revert: Cannot request deposit of 0 assets
        vm.expectRevert();
        userRequestsDeposit(user, 0);

        // Revert: Not authorised
        vm.startPrank(user);
        vm.expectRevert();
        liquidityPool.requestDeposit(DEPOSIT_10, user, notController);
        vm.stopPrank();

        // assert user1 pendingDeposits = deposited amount
        uint256 pendingDeposits = liquidityPool.pendingDepositRequest(0, user);
        assertEq(DEPOSIT_10, pendingDeposits);

        // assert user1 cannot claim yet
        uint256 claimableDeposits = liquidityPool.claimableDepositRequest(0, user);
        assertEq(claimableDeposits, 0);

        managerProcessesDeposits();

        // assert claimable shares match deposited assets 1:1
        // BUG:THESE SHOULD NOT BE SHARES
        uint256 sharesClaimable = liquidityPool.maxMint(user);

        claimableDeposits = liquidityPool.claimableDepositRequest(0, user);

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

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                            MAIN CONTRACT TESTS
    ////////////////////////////////////////////////////////////////*/

    function testBestiaRequestRedeem() public {
        seedBestia();
        uint256 userShares = bestia.balanceOf(address(user1));
        uint256 sharesToRedeem = bestia.balanceOf(address(user1)) / 10;

        vm.startPrank(user1);
        bestia.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // assert user balance has been reduced by correct amout of shares
        assertEq(bestia.balanceOf(address(user1)), userShares - sharesToRedeem);

        // assert that the escrow address has received the share tokens
        assertEq(bestia.balanceOf(address(escrow)), sharesToRedeem);

        // assert the pendingRedeemRequests is updating correctly
        assertEq(bestia.pendingRedeemRequest(0, address(user1)), sharesToRedeem);
    }

    function testBestiaWithdraw() public {
        seedBestia();
        uint256 sharesToRedeem = bestia.balanceOf(address(user1)) / 10;
        uint256 assetsToClaim = bestia.convertToAssets(sharesToRedeem);

        vm.startPrank(user1);
        bestia.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // grab details for vault to liquidate
        address vaultAddress = address(vaultA);
        uint256 sharesToLiquidate = vaultA.convertToShares(assetsToClaim);

        // banker liquidates asset from sync vault position to top up
        vm.startPrank(banker);
        bestia.liquidateSyncVaultPosition(vaultAddress, sharesToLiquidate);
        bestia.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // user burns all usdc and withdraws
        vm.startPrank(user1);
        usdcMock.transfer(address(user2), usdcMock.balanceOf(address(user1)));
        bestia.withdraw(assetsToClaim, address(user1), address(user1));
        vm.stopPrank();

        // assert user has received correct balance of asset
        assertEq(assetsToClaim, usdcMock.balanceOf(address(user1)));

        // assert that Request has been cleared
        assertEq(bestia.pendingRedeemRequest(0, address(user1)), 0);
        assertEq(bestia.claimableRedeemRequest(0, address(user1)), 0);
        assertEq(bestia.maxWithdraw(user1), 0);
    }

    function testfulfilRedeemFromReserveReverts() public {
        seedBestia();
        bestia.enableLiquiateReserveBelowTarget(false);

        uint256 sharesToRedeem = bestia.balanceOf(address(user1)) / 10;
        uint256 assetsToClaim = bestia.convertToAssets(sharesToRedeem);

        vm.startPrank(user1);
        bestia.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // grab details for vault to liquidate. only liquidate requested withdrawal
        address vaultAddress = address(vaultA);
        uint256 sharesToLiquidate = vaultA.convertToShares(assetsToClaim / 2);

        // banker liquidates asset from sync vault position to top up
        vm.startPrank(banker);
        bestia.liquidateSyncVaultPosition(vaultAddress, sharesToLiquidate);

        // revert: no claimable assets for user
        vm.expectRevert();
        bestia.fulfilRedeemFromReserve(address(user2));

        // revert: not enough excess usdc above target cash reserve
        vm.expectRevert();
        bestia.fulfilRedeemFromReserve(address(user1));

        // liquidate other half and fulfilRedeemFrom Reserve succeeds
        bestia.liquidateSyncVaultPosition(vaultAddress, sharesToLiquidate);
        bestia.fulfilRedeemFromReserve(address(user1));
    }

    function testRequestRedeemSwingPricing() public {
        // seed bestia
        seedBestia();

        // disable liquidations below reserve
        bestia.enableLiquiateReserveBelowTarget(false);

        // assert that shares are 1:1 assets and enable swing pricing
        assertEq(bestia.convertToShares(1), 1);
        bestia.enableSwingPricing(true);

        // grab reserve cash value
        uint256 startingReserveCash = usdcMock.balanceOf(address(bestia));

        // grab shares worth 10% of current reserve cash
        uint256 redeemRequest = bestia.convertToShares(startingReserveCash / 10);

        // user 1 requests a redeem of redeem amount
        vm.startPrank(user1);
        bestia.requestRedeem(redeemRequest, address(user1), address(user1));
        vm.stopPrank();

        // Get the index for the redeem request from controllerToRedeemIndex mapping
        uint256 index = bestia.controllerToRedeemIndex(user1);

        // Retrieve the swingFactor from the redeem request by accessing its tuple
        (, uint256 sharesPending,,, uint256 sharesAdjusted) = bestia.redeemRequests(index - 1);

        // assert that the sharesAdjusted have been reduced by swing factor
        assertGt(sharesPending, sharesAdjusted);

        // banker to process redemption
        vm.startPrank(banker);

        // grab the value of assets to liquid and assert they are reduced by swing factor
        uint256 assetsToLiquidate = bestia.convertToAssets(sharesAdjusted);
        assertGt(redeemRequest, assetsToLiquidate);

        // using Vault A to source liquidity, grab the amount of shares needed for request
        // this adds excess cash to the reserve above the target ratio
        uint256 sharesToLiquidate = vaultA.convertToShares(assetsToLiquidate);
        bestia.liquidateSyncVaultPosition(address(vaultA), sharesToLiquidate);

        // assert that the current balance exceeds the original reserve cash
        assertGt(usdcMock.balanceOf(address(bestia)), startingReserveCash);

        // banker fulfils redeem request with the excess cash in the reserve
        bestia.fulfilRedeemFromReserve(address(user1));

        vm.stopPrank();

        // assert that the reserve ratio is at target after redemption fulfiled
        assertEq(startingReserveCash, usdcMock.balanceOf(address(bestia)));

        // assert that the escrow value is equal to maxWithdraw for user
        uint256 maxWithdraw = bestia.maxWithdraw(address(user1));
        assertEq(maxWithdraw, usdcMock.balanceOf(address(escrow)));

        // user 1 to request redeem
        vm.startPrank(user1);
        bestia.withdraw(maxWithdraw, address(user1), address(user1));
        vm.stopPrank();

        // grab all the values left in the Request after withdrawal
        (address controllerAddress, uint256 value1, uint256 value2, uint256 value3, uint256 value4) =
            bestia.redeemRequests(index - 1);

        // assert correct controller address and all values cleared
        assertEq(controllerAddress, address(user1));
        assertEq(value1, 0);
        assertEq(value2, 0);
        assertEq(value3, 0);
        assertEq(value4, 0);
    }
}
