// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract ERC7540Tests is BaseTest {
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

    // exact same test logic as testBestiaWithdraw but user call redeem in last step
    function testBestiaRedeem() public {
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
        bestia.redeem(assetsToClaim, address(user1), address(user1));
        vm.stopPrank();

        // assert user has received correct balance of asset
        assertEq(assetsToClaim, usdcMock.balanceOf(address(user1)));

        // assert shares to assets are 1:1
        assertEq(bestia.convertToShares(1), 1);

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

    function testSetOperator() public {
        // user 1 sets user 2 as operator
        vm.startPrank(user1);
        bestia.setOperator(address(user2), true);
        vm.stopPrank();

        // assert user 2 is operator to user 1
        assertTrue(bestia.isOperator(address(user1), address(user2)));

        // assert user 1 IS NOT operator to user 2
        assertFalse(bestia.isOperator(address(user2), address(user1)));
    }

    function testViewFunctionsRevert() public {
        vm.expectRevert();
        bestia.previewRedeem(100);

        vm.expectRevert();
        bestia.previewWithdraw(100);
    }

    function testOnlyOperatorCanWithdraw() public {
        // seed bestia
        seedBestia();

        // configure liquidations & swing pricing
        bestia.enableLiquiateReserveBelowTarget(true);
        bestia.enableSwingPricing(false);

        // assert shares are correct
        assertEq(bestia.convertToShares(1), 1);

        uint256 sharesToRedeem = bestia.balanceOf(address(user1)) / 10;

        // revert: user 2 is not operator for user 1
        vm.startPrank(user2);
        vm.expectRevert();
        bestia.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // user 1 sets user 2 as operator
        vm.startPrank(user1);
        bestia.setOperator(address(user2), true);
        vm.stopPrank();

        // user 2 can request redeem as now operator
        vm.startPrank(user2);
        bestia.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        console2.log(bestia.pendingRedeemRequest(0, address(user1)));

        // assert that pendingRedeemRequest for user 1 == sharesToRedeem
        assertEq(bestia.pendingRedeemRequest(0, address(user1)), sharesToRedeem);

        // banker fulfils request from reserve cash
        vm.startPrank(banker);
        bestia.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // assert that claimableRedeemRequest for user 1 == sharesToRedeem
        assertEq(bestia.claimableRedeemRequest(0, address(user1)), sharesToRedeem);

        uint256 withdrawal = bestia.maxWithdraw(address(user1));

        // assert user 3 IS NOT operator to user 1
        assertFalse(bestia.isOperator(address(user1), address(user3)));

        // revert: user 3 is not operator
        vm.startPrank(user3);
        vm.expectRevert();
        bestia.withdraw(withdrawal, address(user1), address(user1));
        vm.stopPrank();

        // succeeds: user 3 is operator
        vm.startPrank(user2);
        bestia.withdraw(withdrawal, address(user1), address(user1));
        vm.stopPrank();

        // no more asserts: if test completes you can consider this working
    }

    function testOnlyOperatorCanRedeem() public {
        // seed bestia
        seedBestia();

        // configure liquidations & swing pricing
        bestia.enableLiquiateReserveBelowTarget(true);
        bestia.enableSwingPricing(false);

        // assert shares are correct
        assertEq(bestia.convertToShares(1), 1);

        uint256 sharesToRedeem = bestia.balanceOf(address(user1)) / 10;

        // user 1 sets user 2 as operator
        vm.startPrank(user1);
        bestia.setOperator(address(operatorNoAllowance), true);
        vm.stopPrank();

        // user 2 can request redeem as now operator
        vm.startPrank(operatorNoAllowance);
        bestia.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // assert that pendingRedeemRequest for user 1 == sharesToRedeem
        assertEq(bestia.pendingRedeemRequest(0, address(user1)), sharesToRedeem);

        // banker fulfils request from reserve cash
        vm.startPrank(banker);
        bestia.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // assert that claimableRedeemRequest for user 1 == sharesToRedeem
        assertEq(bestia.claimableRedeemRequest(0, address(user1)), sharesToRedeem);

        uint256 redeem = bestia.maxRedeem(address(user1));

        // assert user 3 IS NOT operator to user 1
        assertFalse(bestia.isOperator(address(user1), address(user3)));

        // revert: user 3 is not operator
        vm.startPrank(user3);
        vm.expectRevert();
        bestia.redeem(redeem, address(user1), address(user1));
        vm.stopPrank();

        // succeeds: user 3 is operator
        vm.startPrank(operatorNoAllowance);
        bestia.redeem(redeem, address(user1), address(user1));
        vm.stopPrank();

        // no more asserts: if test completes you can consider this working
    }

    function testShareSupport() public {
        seedBestia(); // shuts up warning
        assertEq(address(bestia), bestia.share());
    }

    function testSupportsInterface() public {
        seedBestia(); // shuts up warning
        
        // ERC-165 Interface ID
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        assertTrue(bestia.supportsInterface(erc165InterfaceId));

        // ERC-7540 Operator Methods Interface ID
        bytes4 operatorMethodsInterfaceId = 0xe3bc4e65;
        assertTrue(bestia.supportsInterface(operatorMethodsInterfaceId));

        // ERC-7575 Interface ID
        bytes4 erc7575InterfaceId = 0x2f0a18c5;
        assertTrue(bestia.supportsInterface(erc7575InterfaceId));

        // Asynchronous Redemption Interface ID
        bytes4 asyncRedemptionInterfaceId = 0x620ee8e4;
        assertTrue(bestia.supportsInterface(asyncRedemptionInterfaceId));

        // Unsupported Interface ID (should not be supported)
        bytes4 unsupportedInterfaceId = 0xffffffff;
        assertFalse(bestia.supportsInterface(unsupportedInterfaceId));
    }
}


