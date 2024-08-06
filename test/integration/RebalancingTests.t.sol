// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract RebalancingTests is BaseTest {
    function testSimpleRebalance() public {
        // SET THE STRATEGY
        // add the 4626 Vaults
        bestia.addComponent(address(vaultA), 18e16, false);
        bestia.addComponent(address(vaultB), 20e16, false);
        bestia.addComponent(address(vaultC), 22e16, false);

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(tempRWA), 30e16, false); // temp delete

        // initial deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // banker rebalances bestia
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
        bankerInvestsCash(address(tempRWA));

        // second deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // banker rebalances bestia
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
        bankerInvestsCash(address(tempRWA));

        // assert the components are in the right proportion
        assertEq(
            vaultA.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(vaultA))
        );
        assertEq(
            vaultB.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(vaultB))
        );
        assertEq(
            vaultC.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(vaultC))
        );
        assertEq(
            tempRWA.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(tempRWA))
        );

        // third deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_1 * 6, address(user1));
        vm.stopPrank();

        // expect revert as asset within range
        vm.expectRevert();
        bankerInvestsCash(address(vaultA));

        // rebalances succeed as outside range, test would fail if these tx revert
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
        bankerInvestsCash(address(tempRWA));
    }

    function testAsyncRebalance() public {
        // SET THE STRATEGY
        // add the 4626 Vaults
        bestia.addComponent(address(vaultA), 18e16, false);
        bestia.addComponent(address(vaultB), 20e16, false);
        bestia.addComponent(address(vaultC), 22e16, false);

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(liquidityPool), 30e16, true);

        // SEED VAULT WITH 100 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // banker rebalances bestia instant vaults
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));

        // cannot use this function to invest in async vault
        vm.expectRevert();
        bankerInvestsCash(address(liquidityPool));

        // banker rebalances into illiquid vault
        bankerInvestsInAsyncVault(address(liquidityPool));

        uint256 totalAssets = bestia.totalAssets();
        uint256 pendingDeposits = bestia.pendingDeposits();
        uint256 vaultAHoldings = vaultA.balanceOf(address(bestia));
        uint256 vaultBHoldings = vaultB.balanceOf(address(bestia));
        uint256 vaultCHoldings = vaultC.balanceOf(address(bestia));
        uint256 getAsyncAssets = bestia.getAsyncAssets(address(liquidityPool));

        // assert that the protocol was rebalanced to the correct ratios
        assertEq(totalAssets, DEPOSIT_100);
        assertEq(pendingDeposits, 30e18);
        assertEq(vaultAHoldings, 18e18);
        assertEq(vaultBHoldings, 20e18);
        assertEq(vaultCHoldings, 22e18);

        // assert that pendingDeposits tracked on Bestia == getAsyncAssets calls to liquidityPool
        assertEq(pendingDeposits, getAsyncAssets);

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
        pendingDeposits = liquidityPool.pendingDepositRequest(0, address(bestia));
        vaultAHoldings = vaultA.balanceOf(address(bestia));
        vaultBHoldings = vaultB.balanceOf(address(bestia));
        vaultCHoldings = vaultC.balanceOf(address(bestia));
        getAsyncAssets = bestia.getAsyncAssets(address(liquidityPool));

        // assert the liquid assets are all in the correct proportions
        assertEq(vaultAHoldings * 1e18 / totalAssets, 18e16);
        assertEq(vaultBHoldings * 1e18 / totalAssets, 20e16);
        assertEq(vaultCHoldings * 1e18 / totalAssets, 22e16);

        // assert that cash reserve has not been reduced below target by rebalance
        assertGt(usdc.balanceOf(address(bestia)), bestia.targetReserveRatio() * 1e18 / totalAssets);

        // SECOND DEPOSIT: 10 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // TODO: need to write a check that blocks investInCash when RWAs below target

        // should reject investCash as async vault is below threshold
        console2.log(bestia.isAsyncAssetsInRange(address(liquidityPool)));

        // must invest in async first to ensure it gets full amount
        bankerInvestsInAsyncVault(address(liquidityPool));

        // then invest in liquid asset
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));

        totalAssets = bestia.totalAssets();
        pendingDeposits = bestia.pendingDeposits();
        vaultAHoldings = vaultA.balanceOf(address(bestia));
        vaultBHoldings = vaultB.balanceOf(address(bestia));
        vaultCHoldings = vaultC.balanceOf(address(bestia));
        getAsyncAssets = bestia.getAsyncAssets(address(liquidityPool));

        // assert that pendingDeposits tracked on Bestia == getAsyncAssets calls to liquidityPool
        assertEq(pendingDeposits, getAsyncAssets);

        // assert that pendingDeposits on liquidityPool == target ratio
        assertEq(getAsyncAssets * 1e18 / totalAssets, 30e16);

        // assert the liquid assets are all in the correct proportions
        assertEq(vaultAHoldings * 1e18 / totalAssets, 18e16);
        assertEq(vaultBHoldings * 1e18 / totalAssets, 20e16);
        assertEq(vaultCHoldings * 1e18 / totalAssets, 22e16);

        // assert that totalAssets = initial value + 2 deposits
        assertEq(totalAssets, DEPOSIT_100 + DEPOSIT_10 + DEPOSIT_10);
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
}
