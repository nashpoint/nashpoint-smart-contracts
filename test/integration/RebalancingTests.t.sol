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

        // bestia.addComponent(address(tempRWA), 0, false);

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(liquidityPool), 30e16, true);

        // initial deposit
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
        uint256 pendingDeposits = liquidityPool.pendingDepositRequest(0, address(bestia));
        uint256 vaultAHoldings = vaultA.balanceOf(address(bestia));
        uint256 vaultBHoldings = vaultB.balanceOf(address(bestia));
        uint256 vaultCHoldings = vaultC.balanceOf(address(bestia));
        uint256 asyncAssets = bestia.getAsyncVaultAssets(address(liquidityPool));

        console2.log("VAULT SETUP");
        console2.log("totalAssets :", totalAssets / 1e16);
        console2.log("pendingDeposits :", pendingDeposits / 1e16);
        console2.log("vaultAHoldings :", vaultAHoldings / 1e16);
        console2.log("vaultBHoldings :", vaultBHoldings / 1e16);
        console2.log("vaultCHoldings :", vaultCHoldings / 1e16);
        console2.log("asyncAssets :", asyncAssets / 1e16);

        // second deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));

        vm.expectRevert();
        bankerInvestsInAsyncVault(address(liquidityPool));

        totalAssets = bestia.totalAssets();
        pendingDeposits = liquidityPool.pendingDepositRequest(0, address(bestia));
        vaultAHoldings = vaultA.balanceOf(address(bestia));
        vaultBHoldings = vaultB.balanceOf(address(bestia));
        vaultCHoldings = vaultC.balanceOf(address(bestia));
        asyncAssets = bestia.getAsyncVaultAssets(address(liquidityPool));

        console2.log("FIRST DEPOSIT");
        console2.log("totalAssets :", totalAssets / 1e16);
        console2.log("pendingDeposits :", pendingDeposits / 1e16);
        console2.log("vaultAHoldings :", vaultAHoldings / 1e16);
        console2.log("vaultBHoldings :", vaultBHoldings / 1e16);
        console2.log("vaultCHoldings :", vaultCHoldings / 1e16);
        console2.log("asyncAssets :", asyncAssets / 1e16);

        // second deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // need to write a check that blocks investInCash when RWAs below target

        bankerInvestsInAsyncVault(address(liquidityPool));
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));

        totalAssets = bestia.totalAssets();
        pendingDeposits = liquidityPool.pendingDepositRequest(0, address(bestia));
        vaultAHoldings = vaultA.balanceOf(address(bestia));
        vaultBHoldings = vaultB.balanceOf(address(bestia));
        vaultCHoldings = vaultC.balanceOf(address(bestia));
        asyncAssets = bestia.getAsyncVaultAssets(address(liquidityPool));

        console2.log("SECOND DEPOSIT");
        console2.log("totalAssets :", totalAssets / 1e16);
        console2.log("pendingDeposits :", pendingDeposits / 1e16);
        console2.log("vaultAHoldings :", vaultAHoldings / 1e16);
        console2.log("vaultBHoldings :", vaultBHoldings / 1e16);
        console2.log("vaultCHoldings :", vaultCHoldings / 1e16);
        console2.log("asyncAssets :", asyncAssets / 1e16);
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
