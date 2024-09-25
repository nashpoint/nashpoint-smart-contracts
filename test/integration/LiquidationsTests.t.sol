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
        bestia.liquidateSyncVaultPosition(address(vaultA), vaultA.convertToShares(DEPOSIT_10));

        // assert remaining holdings in Vault A == initial investment minus liquidated assets
        uint256 remainingVaultA = vaultA.convertToAssets(vaultA.balanceOf(address(bestia)));
        assertEq(remainingVaultA, initialVaultA - DEPOSIT_10);

        // assert that 10 units of asset has been returned to bestia reserve
        assertEq(usdcMock.balanceOf(address(bestia)), DEPOSIT_10);

        // revert: cannot redeem 0 shares
        vm.expectRevert();
        bestia.liquidateSyncVaultPosition(address(vaultA), 0);

        // get too many shares for redemption
        uint256 tooManyShares = vaultA.balanceOf(address(bestia)) + 1;

        // revert: cannot redeem more shares than balance
        vm.expectRevert();
        bestia.liquidateSyncVaultPosition(address(vaultA), tooManyShares);

        // revert: cannot liquidate async vault
        vm.expectRevert();
        bestia.liquidateSyncVaultPosition(address(liquidityPool), tooManyShares);

        // revert: cannot liquidate non component
        vm.expectRevert();
        bestia.liquidateSyncVaultPosition(address(usdc), 1);
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

    

    
}
