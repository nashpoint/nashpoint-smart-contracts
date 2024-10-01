// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract RebalancingTests is BaseTest {
    function testRebalance() public {
        seedNode(); // see this function in BaseTest to see the initial state of the test

        uint256 totalAssets = node.totalAssets();
        uint256 vaultAHoldings = vaultA.balanceOf(address(node));
        uint256 vaultBHoldings = vaultB.balanceOf(address(node));
        uint256 vaultCHoldings = vaultC.balanceOf(address(node));
        uint256 getAsyncAssets = node.getAsyncAssets(address(liquidityPool));

        // assert that the protocol was rebalanced to the correct ratios
        assertEq(totalAssets, DEPOSIT_100, "Total assets should equal initial deposit");
        assertEq(getAsyncAssets, 30e6, "Async assets should be 30% of total");
        assertEq(vaultAHoldings, 18e6, "Vault A should hold 18% of total");
        assertEq(vaultBHoldings, 20e6, "Vault B should hold 20% of total");
        assertEq(vaultCHoldings, 22e6, "Vault C should hold 22% of total");

        // FIRST DEPOSIT: 10 UNITS
        vm.startPrank(user1);
        node.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // rebalancer rebalances into liquid assets
        rebalancerInvestsCash(address(vaultA));
        rebalancerInvestsCash(address(vaultB));
        rebalancerInvestsCash(address(vaultC));

        // rebalancer cannot rebalance into liquidityPool as lower threshold not breached
        vm.expectRevert();
        rebalancerInvestsInAsyncVault(address(liquidityPool));

        totalAssets = node.totalAssets();
        vaultAHoldings = vaultA.balanceOf(address(node));
        vaultBHoldings = vaultB.balanceOf(address(node));
        vaultCHoldings = vaultC.balanceOf(address(node));
        getAsyncAssets = node.getAsyncAssets(address(liquidityPool));

        // assert the liquid assets are all in the correct proportions
        assertEq(vaultAHoldings * 1e18 / totalAssets, 18e16, "Vault A ratio incorrect");
        assertEq(vaultBHoldings * 1e18 / totalAssets, 20e16, "Vault B ratio incorrect");
        assertEq(vaultCHoldings * 1e18 / totalAssets, 22e16, "Vault C ratio incorrect");

        // assert that cash reserve has not been reduced below target by rebalance
        uint256 currentReserve = usdcMock.balanceOf(address(node));
        uint256 targetCash = (node.totalAssets() * node.targetReserveRatio()) / 1e18;
        assertGt(currentReserve, targetCash, "Current reserve below target");

        // SECOND DEPOSIT: 10 UNITS
        vm.startPrank(user1);
        node.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // check that blocks investInCash when RWAs below target
        // note: leave this here as failing test will remind you to fix later
        vm.expectRevert();
        rebalancerInvestsCash(address(vaultA));

        // note: maybe delete, not sure I need this anymore
        // // should reject investCash as async vault is below threshold
        // console2.log(node.isAsyncAssetsBelowMinimum(address(liquidityPool)));

        // must invest in async first to ensure it gets full amount
        rebalancerInvestsInAsyncVault(address(liquidityPool));

        // then invest in liquid asset
        rebalancerInvestsCash(address(vaultA));
        rebalancerInvestsCash(address(vaultB));
        rebalancerInvestsCash(address(vaultC));

        totalAssets = node.totalAssets();
        // pendingDeposits = node.pendingDeposits();
        vaultAHoldings = vaultA.balanceOf(address(node));
        vaultBHoldings = vaultB.balanceOf(address(node));
        vaultCHoldings = vaultC.balanceOf(address(node));
        getAsyncAssets = node.getAsyncAssets(address(liquidityPool));

        // assert that asyncAssets on liquidityPool == target ratio
        assertEq(getAsyncAssets * 1e18 / totalAssets, 30e16, "Async assets ratio incorrect");

        // assert the liquid assets are all in the correct proportions
        assertEq(vaultAHoldings * 1e18 / totalAssets, 18e16, "Vault A ratio incorrect after rebalance");
        assertEq(vaultBHoldings * 1e18 / totalAssets, 20e16, "Vault B ratio incorrect after rebalance");
        assertEq(vaultCHoldings * 1e18 / totalAssets, 22e16, "Vault C ratio incorrect after rebalance");

        // assert that totalAssets = initial value + 2 deposits
        assertEq(totalAssets, DEPOSIT_100 + DEPOSIT_10 + DEPOSIT_10, "Total assets incorrect after deposits");
    }

    function testGetAsyncAssets() public {
        // deposit 100 units to node and rebalance into correct target ratios
        seedNode();

        // grab total assets at start of test to check at the end
        uint256 startingAssets = node.totalAssets();

        // assert user has zero shares at start
        uint256 sharesToMint = liquidityPool.maxMint(address(node));
        assertEq(sharesToMint, 0);

        // assert that the return value for getAsyncAssets == pendingDeposits on Liquidity Pool
        uint256 asyncAssets = node.getAsyncAssets(address(liquidityPool));
        uint256 pendingDeposits = liquidityPool.pendingDepositRequest(0, address(node));
        assertEq(asyncAssets, pendingDeposits, "Async assets don't match pending deposits");

        // process pending deposits
        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // grab shares to mint for node after processing pending deposits
        // assert maxMint of shares = pendingDeposits in assets terms
        sharesToMint = liquidityPool.maxMint(address(node));
        assertEq(liquidityPool.convertToAssets(sharesToMint), pendingDeposits, "Shares do no match value of assets");

        // assert that the return value for getAsyncAssets == claimableDeposits on Liquidity Pool
        asyncAssets = node.getAsyncAssets(address(liquidityPool));
        uint256 claimableDeposits = liquidityPool.claimableDepositRequest(0, address(node));
        assertEq(asyncAssets, claimableDeposits, "Async assets don't match claimable deposits");

        // mint the claimable shares
        vm.startPrank(rebalancer);
        node.mintClaimableShares(address(liquidityPool));
        vm.stopPrank();

        // assert that all shares have been minted
        sharesToMint = liquidityPool.maxMint(address(node));
        assertEq(sharesToMint, 0);

        // assert that all claimable deposits have been minted
        claimableDeposits = liquidityPool.claimableDepositRequest(0, address(node));
        assertEq(claimableDeposits, 0);

        // assert that the asset value of the minted shares == getAsyncAssets
        asyncAssets = node.getAsyncAssets(address(liquidityPool));
        uint256 valueOfShares = liquidityPool.convertToAssets(liquidityPool.balanceOf(address(node)));
        assertEq(asyncAssets, valueOfShares, "Async assets don't match value of shares");

        // assert pendingDepositRequest deleted
        vm.expectRevert();
        liquidityPool.pendingDepositRequest(0, address(node));

        // assert claimableDeposits requests == 0
        assertEq(liquidityPool.claimableDepositRequest(0, address(node)), 0, "Claimable deposits not cleared");

        // WITHDRAWAL SEQUENCE STARTS

        // get amount of shares minted
        uint256 mintedShares = liquidityPool.balanceOf(address(node));

        // request async asset withdrawal
        vm.startPrank(rebalancer);
        node.requestAsyncWithdrawal(address(liquidityPool), mintedShares);
        vm.stopPrank();

        // assert the asset value of the redeeming shares == async assets
        asyncAssets = node.getAsyncAssets(address(liquidityPool));
        uint256 pendingWithdrawals = liquidityPool.convertToAssets(liquidityPool.pendingRedeemRequest(0, address(node)));
        assertEq(asyncAssets, pendingWithdrawals, "Async assets don't match pending withdrawals");

        // process pending deposits
        vm.startPrank(manager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();

        // assert claimable assets == async assets
        asyncAssets = node.getAsyncAssets(address(liquidityPool));
        uint256 claimableWithdrawals =
            liquidityPool.convertToAssets(liquidityPool.claimableRedeemRequest(0, address(node)));
        assertEq(asyncAssets, claimableWithdrawals, "Async assets don't match claimable withdrawals");

        // get the max amount of assets that can be withdrawn
        uint256 maxWithdraw = liquidityPool.maxWithdraw(address(node));

        // execute the withdrawal
        vm.startPrank(rebalancer);
        node.executeAsyncWithdrawal(address(liquidityPool), maxWithdraw);
        vm.stopPrank();

        // assert node no longer has async assets
        assertEq(node.getAsyncAssets(address(liquidityPool)), 0, "Async assets not zero after withdrawal");

        // assert no assets lost through process
        uint256 finishingAssets = node.totalAssets();
        assertEq(startingAssets, finishingAssets);
    }
}
