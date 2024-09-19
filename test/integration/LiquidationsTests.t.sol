// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract LiquidationsTest is BaseTest {
    function testLiquidateSynchVault() public {
        seedBestia();
        // seed vault with 100e6 cash rebalanced into:
        // Cash Reserve: 10%
        // 3 ERC-4626 vaults: 18%, 20%, 22%
        // 1 ERC-7540 vault: 30%

        // user withdraws 10e6 cash
        vm.startPrank(user1);
        bestia.withdraw(DEPOSIT_10, address(user1), (address(user1)));
        vm.stopPrank();

        // assert reserve cash == zero
        assertEq(usdcMock.balanceOf(address(bestia)), 0);

        // assert vaultA shares/assets are 1
        assertEq(vaultA.convertToShares(1), 1);

        // get the initial holdings for bestia in Vault A
        uint256 initialVaultA = vaultA.convertToAssets(vaultA.balanceOf(address(bestia)));

        // liquidate 10 assets worth of shares
        bestia.liquidateSynchVaultPosition(address(vaultA), vaultA.convertToShares(DEPOSIT_10));

        // assert remaining holdings in Vault A == initial investment minus liquidated assets
        uint256 remainingVaultA = vaultA.convertToAssets(vaultA.balanceOf(address(bestia)));
        assertEq(remainingVaultA, initialVaultA - DEPOSIT_10);

        // assert that 10 units of asset has been returned to bestia reserve
        assertEq(usdcMock.balanceOf(address(bestia)), DEPOSIT_10);

        // revert: cannot redeem 0 shares
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(vaultA), 0);

        // get too many shares for redemption
        uint256 tooManyShares = vaultA.balanceOf(address(bestia)) + 1;

        // revert: cannot redeem more shares than balance
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(vaultA), tooManyShares);

        // revert: cannot liquidate async vault
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(liquidityPool), tooManyShares);

        // revert: cannot liquidate non component
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(usdc), 1);
    }

    function testComponentsOrder() public {
        seedBestia();

        // Check that components exist in the expected order
        for (uint256 i = 0; i <= 3; i++) {
            (address componentAddress,,,) = bestia.components(i);
            assertTrue(componentAddress != address(0)); // Just ensuring the component exists
        }

        // Expect revert if querying beyond the number of components
        vm.expectRevert();
        bestia.components(4);
    }

    function testCannotLiquidateAsyncAsset() public {
        // add the 7540 Vault (RWA)
        bestia.addComponent(address(liquidityPool), 90e16, true, address(liquidityPool));

        // SEED VAULT WITH 100 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // revert: first item in components is async and causes revert
        vm.expectRevert();
        bestia.instantUserLiquidation(DEPOSIT_10);
    }

    function testInstantUserLiquidation() public {
        // Setup
        seedBestia();
        // seed vault with 100e6 cash rebalanced into:
        // Cash Reserve: 10%
        // 3 ERC-4626 vaults: 18%, 20%, 22%
        // 1 ERC-7540 vault: 30%

        // user withdraws 10e6 cash
        vm.startPrank(user1);
        bestia.withdraw(DEPOSIT_10, address(user1), (address(user1)));
        vm.stopPrank();

        // assert reserve cash == zero
        assertEq(usdcMock.balanceOf(address(bestia)), 0);

        // assert user still has shares in bestia
        assertGt(bestia.balanceOf(user1), 0);

        // note: prank as user 1 for rest of the test
        vm.startPrank(user1);

        // revert: bestia does not have enough usdc for withdrawal
        vm.expectRevert();
        bestia.withdraw(DEPOSIT_10, address(user1), address(user1));

        // user burns all usdc
        usdcMock.transfer(address(user2), usdcMock.balanceOf(address(user1)));

        // grab vault A holdings BEFORE instantLiquidation
        uint256 vaultAHoldingsBefore = vaultA.convertToAssets(vaultA.balanceOf(address(bestia)));

        // user 1 executes instantLiquidation
        bestia.instantUserLiquidation(bestia.convertToShares(DEPOSIT_10));

        // grab max discount
        uint256 maxDiscount = bestia.maxDiscount();

        // assert funds return == requested amount minus maxDiscount
        assertEq(usdcMock.balanceOf(address(user1)), DEPOSIT_10 * (1e18 - maxDiscount) / 1e18);

        // grab vault A holdings AFTER instantLiquidation
        uint256 vaultAHoldingsAfter = vaultA.convertToAssets(vaultA.balanceOf(address(bestia)));

        // assert that the underlying vault was reduced by the same value as returened to the user
        assertEq(vaultAHoldingsBefore - vaultAHoldingsAfter, usdcMock.balanceOf(address(user1)));

        // user burns all usdc
        usdcMock.transfer(address(user2), usdcMock.balanceOf(address(user1)));

        // grab Vault B holdings before withdrawal
        uint256 vaultBHoldingsBefore = vaultB.convertToAssets(vaultB.balanceOf(address(bestia)));

        // user 1 executes instantLiquidation with amount greater than available in Vault A
        uint256 tooMuch = vaultAHoldingsAfter + DEPOSIT_10;
        bestia.instantUserLiquidation(bestia.convertToShares(tooMuch));

        // assert that user received the expected amount
        uint256 expectedAmount = tooMuch * (1e18 - maxDiscount) / 1e18;
        assertApproxEqAbs(usdcMock.balanceOf(address(user1)), expectedAmount, 1);

        // assert that vault B was reduced by the correct amount.
        // this implies that vault A was skipped
        uint256 vaultBHoldingsAfter = vaultB.convertToAssets(vaultB.balanceOf(address(bestia)));
        assertApproxEqAbs(vaultBHoldingsAfter + expectedAmount, vaultBHoldingsBefore, 1);

        // show both underlying vaults still have a balance
        assertGt(vaultA.convertToAssets(vaultA.balanceOf(address(bestia))), 0);
        assertGt(vaultB.convertToAssets(vaultB.balanceOf(address(bestia))), 0);

        // grab the usdc value of bestia's holdings in vaultC
        uint256 vaultCBalanceBefore = vaultC.convertToAssets(vaultC.balanceOf(address(bestia)));

        // user burns all usdc and executes liquidation of full
        usdcMock.transfer(address(user2), usdcMock.balanceOf(address(user1)));
        bestia.instantUserLiquidation(bestia.convertToShares(vaultCBalanceBefore));

        // grab the vault C balance after the liquidation
        uint256 vaultCBalanceAfter = vaultC.convertToAssets(vaultC.balanceOf(address(bestia)));

        // Calculate the expected remaining balance due to the discount
        uint256 expectedVaultCBalanceAfter = vaultCBalanceBefore * maxDiscount / 1e18;

        // Assert that the remaining balance is as expected
        assertApproxEqAbs(vaultCBalanceAfter, expectedVaultCBalanceAfter, 1);

        // assert that user balance + remainder in vault c == vault c starting balance
        assertEq(vaultCBalanceAfter + usdcMock.balanceOf(address(user1)), vaultCBalanceBefore);

        // assert no vault has a remaining balance > 10 units
        assertLt(vaultA.convertToAssets(vaultA.balanceOf(address(bestia))), DEPOSIT_10);
        assertLt(vaultB.convertToAssets(vaultB.balanceOf(address(bestia))), DEPOSIT_10);
        assertLt(vaultC.convertToAssets(vaultC.balanceOf(address(bestia))), DEPOSIT_10);

        // show that liquidityPool (async) has sufficent assets to withdraw
        assertGt(bestia.getAsyncAssets(address(liquidityPool)), DEPOSIT_10);

        // convert this to shares to enable expectRevert to run directly on the value
        uint256 tooManyShares = bestia.convertToShares(DEPOSIT_10);
        
        // revert: skips all sync assets as too small
        // then cannot withdraw from the async asset
        vm.expectRevert();
        bestia.instantUserLiquidation(tooManyShares);
        
        vm.stopPrank();
    }
}
