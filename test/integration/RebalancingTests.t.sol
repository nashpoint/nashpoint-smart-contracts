// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract RebalancingTests is BaseTest {
    function testRebalance() public {
        // SET THE STRATEGY
        // add the 4626 Vaults
        bestia.addComponent(address(vaultA), 18e16, false, address(vaultA));
        bestia.addComponent(address(vaultB), 20e16, false, address(vaultB));
        bestia.addComponent(address(vaultC), 22e16, false, address(vaultC));

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(liquidityPool), 30e16, true, address(liquidityPool));

        // SEED VAULT WITH 100 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // cannot use this function to invest in async vault
        vm.expectRevert();
        bankerInvestsCash(address(liquidityPool));

        // banker rebalances into illiquid vault
        bankerInvestsInAsyncVault(address(liquidityPool));

        // banker rebalances bestia instant vaults
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));

        uint256 totalAssets = bestia.totalAssets();
        uint256 vaultAHoldings = vaultA.balanceOf(address(bestia));
        uint256 vaultBHoldings = vaultB.balanceOf(address(bestia));
        uint256 vaultCHoldings = vaultC.balanceOf(address(bestia));
        uint256 getAsyncAssets = bestia.getAsyncAssets(address(liquidityPool));

        // assert that the protocol was rebalanced to the correct ratios
        assertEq(totalAssets, DEPOSIT_100);
        assertEq(getAsyncAssets, 30e18);
        assertEq(vaultAHoldings, 18e18);
        assertEq(vaultBHoldings, 20e18);
        assertEq(vaultCHoldings, 22e18);

        // FIRST DEPOSIT: 10 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // banker rebalances into liquid assets
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));

        // banker cannot rebalance into liquidityPool as lower threshold not breached
        vm.expectRevert();
        bankerInvestsInAsyncVault(address(liquidityPool));

        totalAssets = bestia.totalAssets();
        vaultAHoldings = vaultA.balanceOf(address(bestia));
        vaultBHoldings = vaultB.balanceOf(address(bestia));
        vaultCHoldings = vaultC.balanceOf(address(bestia));
        getAsyncAssets = bestia.getAsyncAssets(address(liquidityPool));

        // assert the liquid assets are all in the correct proportions
        assertEq(vaultAHoldings * 1e18 / totalAssets, 18e16);
        assertEq(vaultBHoldings * 1e18 / totalAssets, 20e16);
        assertEq(vaultCHoldings * 1e18 / totalAssets, 22e16);

        // assert that cash reserve has not been reduced below target by rebalance
        assertGt(usdcMock.balanceOf(address(bestia)), bestia.targetReserveRatio() * 1e18 / totalAssets);

        // SECOND DEPOSIT: 10 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // check that blocks investInCash when RWAs below target
        vm.expectRevert();
        bankerInvestsCash(address(vaultA));

        // should reject investCash as async vault is below threshold
        console2.log(bestia.isAsyncAssetsBelowMinimum(address(liquidityPool)));

        // must invest in async first to ensure it gets full amount
        bankerInvestsInAsyncVault(address(liquidityPool));

        // then invest in liquid asset
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));

        totalAssets = bestia.totalAssets();
        // pendingDeposits = bestia.pendingDeposits();
        vaultAHoldings = vaultA.balanceOf(address(bestia));
        vaultBHoldings = vaultB.balanceOf(address(bestia));
        vaultCHoldings = vaultC.balanceOf(address(bestia));
        getAsyncAssets = bestia.getAsyncAssets(address(liquidityPool));

        // assert that asyncAssets on liquidityPool == target ratio
        assertEq(getAsyncAssets * 1e18 / totalAssets, 30e16);

        // assert the liquid assets are all in the correct proportions
        assertEq(vaultAHoldings * 1e18 / totalAssets, 18e16);
        assertEq(vaultBHoldings * 1e18 / totalAssets, 20e16);
        assertEq(vaultCHoldings * 1e18 / totalAssets, 22e16);

        // assert that totalAssets = initial value + 2 deposits
        assertEq(totalAssets, DEPOSIT_100 + DEPOSIT_10 + DEPOSIT_10);
    }

    function testGetAsyncAssets() public {
        // deposit 100 units to bestia and rebalance into correct target ratios
        seedBestia();

        // assert that the return value for getAsyncAssets == pendingDeposits on Liquidity Pool
        uint256 asyncAssets = bestia.getAsyncAssets(address(liquidityPool));
        uint256 pendingDeposits = liquidityPool.pendingDepositRequest(0, address(bestia));
        assertEq(asyncAssets, pendingDeposits);

        // process pending deposits
        vm.startPrank(manager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // assert that the return value for getAsyncAssets == claimableDeposits on Liquidity Pool
        asyncAssets = bestia.getAsyncAssets(address(liquidityPool));
        uint256 claimableDeposits =
            liquidityPool.convertToAssets(liquidityPool.claimableDepositRequest(0, address(bestia)));
        assertEq(asyncAssets, claimableDeposits);

        // mint the claimable shares
        vm.startPrank(banker);
        bestia.mintClaimableShares(address(liquidityPool));
        vm.stopPrank();

        // assert that return value for getAsyncAssets == value of newly minted shares
        asyncAssets = bestia.getAsyncAssets(address(liquidityPool));
        uint256 valueOfShares = liquidityPool.convertToAssets(liquidityPool.balanceOf(address(bestia)));
        assertEq(asyncAssets, valueOfShares);

        // get amount of shares minted
        uint256 mintedShares = liquidityPool.balanceOf(address(bestia));

        // assert pendingDepositRequest deleted
        vm.expectRevert();
        liquidityPool.pendingDepositRequest(0, address(bestia));

        // assert claimableDeposits requests == 0
        assertEq(liquidityPool.claimableDepositRequest(0, address(bestia)), 0);

        // request async asset withdrawal
        vm.startPrank(banker);
        bestia.requestAsyncWithdrawal(address(liquidityPool), mintedShares);
        vm.stopPrank();

        // assert the asset value of the redeeming shares == async assets
        asyncAssets = bestia.getAsyncAssets(address(liquidityPool));
        uint256 pendingWithdrawals =
            liquidityPool.convertToAssets(liquidityPool.pendingRedeemRequest(0, address(bestia)));
        assertEq(asyncAssets, pendingWithdrawals);

        // process pending deposits
        vm.startPrank(manager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();

        // assert claimable assets == async assets
        asyncAssets = bestia.getAsyncAssets(address(liquidityPool));
        uint256 claimableWithdrawals = liquidityPool.claimableRedeemRequest(0, address(bestia));
        assertEq(asyncAssets, claimableWithdrawals);

        // execute the withdrawal
        vm.startPrank(banker);
        bestia.executeAsyncWithdrawal(address(liquidityPool), claimableWithdrawals);
        vm.stopPrank();

        assertEq(bestia.getAsyncAssets(address(liquidityPool)), 0);

        console2.log(bestia.totalAssets());
    }

    function bankerInvestsCash(address _component) public {
        vm.startPrank(banker);
        bestia.investCash(_component);
        vm.stopPrank();
    }

    function bankerInvestsInAsyncVault(address _component) public {
        vm.startPrank(banker);
        bestia.investInAsyncVault(address(_component));
        vm.stopPrank();
    }

    function seedBestia() public {
        // SET THE STRATEGY
        // add the 4626 Vaults
        bestia.addComponent(address(vaultA), 18e16, false, address(vaultA));
        bestia.addComponent(address(vaultB), 20e16, false, address(vaultB));
        bestia.addComponent(address(vaultC), 22e16, false, address(vaultC));

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(liquidityPool), 30e16, true, address(liquidityPool));

        // SEED VAULT WITH 100 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // banker rebalances into illiquid vault
        bankerInvestsInAsyncVault(address(liquidityPool));

        // banker rebalances bestia instant vaults
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
    }
}
