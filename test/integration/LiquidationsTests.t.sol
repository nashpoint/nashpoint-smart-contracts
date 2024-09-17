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

        // user withhdraws 10e6 cash
        vm.startPrank(user1);
        bestia.withdraw(DEPOSIT_10, address(user1), (address(user1)));
        vm.stopPrank();

        // assert reserve cash == zero
        assertEq(usdcMock.balanceOf(address(bestia)), 0);

        // get the initial holdings for bestia in Vault A
        uint256 initialVaultA = vaultA.convertToAssets(vaultA.balanceOf(address(bestia)));

        // assert vaultA shares/assets are 1
        assertEq(vaultA.convertToShares(1), 1);

        // liquidate 10 assets worth of shares
        bestia.liquidateSynchVaultPosition(address(vaultA), vaultA.convertToShares(DEPOSIT_10));

        // assert remaining holdings in Vault A == initial investment minus liquidated assets
        uint256 remainingVaultA = vaultA.convertToAssets(vaultA.balanceOf(address(bestia)));
        assertEq(remainingVaultA, initialVaultA - DEPOSIT_10);

        // assert that 10 units of asset has been returned to bestia reserve
        assertEq(usdcMock.balanceOf(address(bestia)), DEPOSIT_10);

        // cannot redeem 0 shares
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(vaultA), 0);

        // get too many shares for redemption
        uint256 tooManyShares = vaultA.balanceOf(address(bestia)) + 1;

        // cannot redeem more shares than balance
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(vaultA), tooManyShares);

        // cannot liquidate async vault
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(liquidityPool), tooManyShares);

        // cannot liquidate non component
        vm.expectRevert();
        bestia.liquidateSynchVaultPosition(address(usdc), 1);
    }

    function testWithdrawalOrder() public {
        seedBestia();

        // bestia has 4 assets in this state, zero-indexed
        for (uint256 i = 0; i <= 3; i++) {
            (,,,, uint256 withdrawalOrder) = bestia.components(i);
            assertEq(withdrawalOrder, i);
        }

        // cannot query component that does not exist
        vm.expectRevert();
        bestia.components(4);
    }
}
