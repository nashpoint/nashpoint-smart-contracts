// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract ERC7540Tests is BaseTest {
    function testNodeRequestRedeem() public {
        seedNode();
        uint256 userShares = node.balanceOf(address(user1));
        uint256 sharesToRedeem = node.balanceOf(address(user1)) / 10;

        vm.startPrank(user1);
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // assert user balance has been reduced by correct amout of shares
        assertEq(node.balanceOf(address(user1)), userShares - sharesToRedeem);

        // assert that the escrow address has received the share tokens
        assertEq(node.balanceOf(address(escrow)), sharesToRedeem);

        // assert the pendingRedeemRequests is updating correctly
        assertEq(node.pendingRedeemRequest(0, address(user1)), sharesToRedeem);
    }

    function testNodeWithdraw() public {
        seedNode();
        uint256 sharesToRedeem = node.balanceOf(address(user1)) / 10;
        uint256 assetsToClaim = node.convertToAssets(sharesToRedeem);

        vm.startPrank(user1);
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // grab details for vault to liquidate
        address vaultAddress = address(vaultA);
        uint256 sharesToLiquidate = vaultA.convertToShares(assetsToClaim);

        // rebalancer liquidates asset from sync vault position to top up
        vm.startPrank(rebalancer);
        node.liquidateSyncVaultPosition(vaultAddress, sharesToLiquidate);
        node.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // user burns all usdc and withdraws
        vm.startPrank(user1);
        usdcMock.transfer(address(user2), usdcMock.balanceOf(address(user1)));
        node.withdraw(assetsToClaim, address(user1), address(user1));
        vm.stopPrank();

        // assert user has received correct balance of asset
        assertEq(assetsToClaim, usdcMock.balanceOf(address(user1)));

        // assert that Request has been cleared
        assertEq(node.pendingRedeemRequest(0, address(user1)), 0);
        assertEq(node.claimableRedeemRequest(0, address(user1)), 0);
        assertEq(node.maxWithdraw(user1), 0);
    }

    // exact same test logic as testNodeWithdraw but user call redeem in last step
    function testNodeRedeem() public {
        seedNode();
        uint256 sharesToRedeem = node.balanceOf(address(user1)) / 10;
        uint256 assetsToClaim = node.convertToAssets(sharesToRedeem);

        vm.startPrank(user1);
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // grab details for vault to liquidate
        address vaultAddress = address(vaultA);
        uint256 sharesToLiquidate = vaultA.convertToShares(assetsToClaim);

        // rebalancer liquidates asset from sync vault position to top up
        vm.startPrank(rebalancer);
        node.liquidateSyncVaultPosition(vaultAddress, sharesToLiquidate);
        node.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // user burns all usdc and withdraws
        vm.startPrank(user1);
        usdcMock.transfer(address(user2), usdcMock.balanceOf(address(user1)));
        node.redeem(assetsToClaim, address(user1), address(user1));
        vm.stopPrank();

        // assert user has received correct balance of asset
        assertEq(assetsToClaim, usdcMock.balanceOf(address(user1)));

        // assert shares to assets are 1:1
        assertEq(node.convertToShares(1), 1);

        // assert that Request has been cleared
        assertEq(node.pendingRedeemRequest(0, address(user1)), 0);
        assertEq(node.claimableRedeemRequest(0, address(user1)), 0);
        assertEq(node.maxWithdraw(user1), 0);
    }

    function testfulfilRedeemFromReserveReverts() public {
        seedNode();
        node.enableLiquiateReserveBelowTarget(false);

        uint256 sharesToRedeem = node.balanceOf(address(user1)) / 10;
        uint256 assetsToClaim = node.convertToAssets(sharesToRedeem);

        vm.startPrank(user1);
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // grab details for vault to liquidate. only liquidate requested withdrawal
        address vaultAddress = address(vaultA);
        uint256 sharesToLiquidate = vaultA.convertToShares(assetsToClaim / 2);

        // rebalancer liquidates asset from sync vault position to top up
        vm.startPrank(rebalancer);
        node.liquidateSyncVaultPosition(vaultAddress, sharesToLiquidate);

        // revert: no claimable assets for user
        vm.expectRevert();
        node.fulfilRedeemFromReserve(address(user2));

        // revert: not enough excess usdc above target cash reserve
        vm.expectRevert();
        node.fulfilRedeemFromReserve(address(user1));

        // liquidate other half and fulfilRedeemFrom Reserve succeeds
        node.liquidateSyncVaultPosition(vaultAddress, sharesToLiquidate);
        node.fulfilRedeemFromReserve(address(user1));
    }

    function testRequestRedeemSwingPricing() public {
        // seed node
        seedNode();

        // disable liquidations below reserve
        node.enableLiquiateReserveBelowTarget(false);

        // assert that shares are 1:1 assets and enable swing pricing
        assertEq(node.convertToShares(1), 1);
        node.enableSwingPricing(true);

        // grab reserve cash value
        uint256 startingReserveCash = usdcMock.balanceOf(address(node));

        // grab shares worth 10% of current reserve cash
        uint256 redeemRequest = node.convertToShares(startingReserveCash / 10);

        // user 1 requests a redeem of redeem amount
        vm.startPrank(user1);
        node.requestRedeem(redeemRequest, address(user1), address(user1));
        vm.stopPrank();

        // Get the index for the redeem request from controllerToRedeemIndex mapping
        uint256 index = node.controllerToRedeemIndex(user1);

        // Retrieve the sharesPending and sharesAdjusted from the redeem request
        (, uint256 sharesPending,,, uint256 sharesAdjusted) = node.redeemRequests(index - 1);

        // assert that the sharesAdjusted have been reduced by swing factor
        assertGt(sharesPending, sharesAdjusted);

        // rebalancer to process redemption
        vm.startPrank(rebalancer);

        // grab the value of assets to liquid and assert they are reduced by swing factor
        uint256 assetsToLiquidate = node.convertToAssets(sharesAdjusted);
        assertGt(redeemRequest, assetsToLiquidate);

        // using Vault A to source liquidity, grab the amount of shares needed for request
        // this adds excess cash to the reserve above the target ratio
        uint256 sharesToLiquidate = vaultA.convertToShares(assetsToLiquidate);
        node.liquidateSyncVaultPosition(address(vaultA), sharesToLiquidate);

        // assert that the current balance exceeds the original reserve cash
        assertGt(usdcMock.balanceOf(address(node)), startingReserveCash);

        // rebalancer fulfils redeem request with the excess cash in the reserve
        node.fulfilRedeemFromReserve(address(user1));

        vm.stopPrank();

        // assert that the reserve ratio is at target after redemption fulfiled
        assertEq(startingReserveCash, usdcMock.balanceOf(address(node)));

        // assert that the escrow value is equal to maxWithdraw for user
        uint256 maxWithdraw = node.maxWithdraw(address(user1));
        assertEq(maxWithdraw, usdcMock.balanceOf(address(escrow)));

        // user 1 to request redeem
        vm.startPrank(user1);
        node.withdraw(maxWithdraw, address(user1), address(user1));
        vm.stopPrank();

        // grab all the values left in the Request after withdrawal
        (address controllerAddress, uint256 value1, uint256 value2, uint256 value3, uint256 value4) =
            node.redeemRequests(index - 1);

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
        node.setOperator(address(user2), true);
        vm.stopPrank();

        // assert user 2 is operator to user 1
        assertTrue(node.isOperator(address(user1), address(user2)));

        // assert user 1 IS NOT operator to user 2
        assertFalse(node.isOperator(address(user2), address(user1)));
    }

    function testViewFunctionsRevert() public {
        vm.expectRevert();
        node.previewRedeem(100);

        vm.expectRevert();
        node.previewWithdraw(100);
    }

    function testOnlyOperatorCanWithdraw() public {
        // seed node
        seedNode();

        // configure liquidations & swing pricing
        node.enableLiquiateReserveBelowTarget(true);
        node.enableSwingPricing(false);

        // assert shares are correct
        assertEq(node.convertToShares(1), 1);

        uint256 sharesToRedeem = node.balanceOf(address(user1)) / 10;

        // revert: user 2 is not operator for user 1
        vm.startPrank(user2);
        vm.expectRevert();
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // user 1 sets user 2 as operator
        vm.startPrank(user1);
        node.setOperator(address(user2), true);
        node.approve(address(user2), sharesToRedeem);
        vm.stopPrank();

        // user 2 can request redeem as now operator
        vm.startPrank(user2);
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        console2.log(node.pendingRedeemRequest(0, address(user1)));

        // assert that pendingRedeemRequest for user 1 == sharesToRedeem
        assertEq(node.pendingRedeemRequest(0, address(user1)), sharesToRedeem);

        // rebalancer fulfils request from reserve cash
        vm.startPrank(rebalancer);
        node.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // assert that claimableRedeemRequest for user 1 == sharesToRedeem
        assertEq(node.claimableRedeemRequest(0, address(user1)), sharesToRedeem);

        uint256 withdrawal = node.maxWithdraw(address(user1));

        // assert user 3 IS NOT operator to user 1
        assertFalse(node.isOperator(address(user1), address(user3)));

        // revert: user 3 is not operator
        vm.startPrank(user3);
        vm.expectRevert();
        node.withdraw(withdrawal, address(user1), address(user1));
        vm.stopPrank();

        // succeeds: user 3 is operator
        vm.startPrank(user2);
        node.withdraw(withdrawal, address(user1), address(user1));
        vm.stopPrank();

        // no more asserts: if test completes you can consider this working
    }

    function testOnlyOperatorCanRedeem() public {
        // seed node
        seedNode();

        // configure liquidations & swing pricing
        node.enableLiquiateReserveBelowTarget(true);
        node.enableSwingPricing(false);

        // assert shares are correct
        assertEq(node.convertToShares(1), 1);

        uint256 sharesToRedeem = node.balanceOf(address(user1)) / 10;

        // user 1 sets user as operator
        // operatorNoAllowance address does not have an allowance set in the test setup
        vm.startPrank(user1);
        node.setOperator(address(operatorNoAllowance), true);
        node.approve(address(operatorNoAllowance), sharesToRedeem);
        vm.stopPrank();

        // user 2 can request redeem as now operator
        vm.startPrank(operatorNoAllowance);
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // assert that pendingRedeemRequest for user 1 == sharesToRedeem
        assertEq(node.pendingRedeemRequest(0, address(user1)), sharesToRedeem);

        // rebalancer fulfils request from reserve cash
        vm.startPrank(rebalancer);
        node.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // assert that claimableRedeemRequest for user 1 == sharesToRedeem
        assertEq(node.claimableRedeemRequest(0, address(user1)), sharesToRedeem);

        uint256 redeem = node.maxRedeem(address(user1));

        // assert user 3 IS NOT operator to user 1
        assertFalse(node.isOperator(address(user1), address(user3)));

        // revert: user 3 is not operator
        vm.startPrank(user3);
        vm.expectRevert();
        node.redeem(redeem, address(user1), address(user1));
        vm.stopPrank();

        // succeeds: user 3 is operator
        vm.startPrank(operatorNoAllowance);
        node.redeem(redeem, address(user1), address(user1));
        vm.stopPrank();

        // no more asserts: if test completes you can consider this working
    }

    function testShareSupport() public {
        seedNode(); // shuts up warning
        assertEq(address(node), node.share());
    }

    function testSupportsInterface() public {
        seedNode(); // shuts up warning

        // ERC-165 Interface ID
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        assertTrue(node.supportsInterface(erc165InterfaceId));

        // Asynchronous Redemption Interface ID
        bytes4 asyncRedemptionInterfaceId = 0x620ee8e4;
        assertTrue(node.supportsInterface(asyncRedemptionInterfaceId));

        // Unsupported Interface ID (should not be supported)
        bytes4 unsupportedInterfaceId = 0xffffffff;
        assertFalse(node.supportsInterface(unsupportedInterfaceId));
    }

    function testArbitraryTransferFrom() public {
        seedNode();
        uint256 sharesToRedeem = node.balanceOf(address(user1)) / 10;
        node.enableLiquiateReserveBelowTarget(true);

        // revert user 2 tries to redeem user1 shares
        vm.startPrank(user2);
        vm.expectRevert();
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // user 1 requests redeem and rebalancer fulfils request
        vm.startPrank(user1);
        node.requestRedeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();
        vm.startPrank(rebalancer);
        node.fulfilRedeemFromReserve(user1);
        vm.stopPrank();

        // revert user 2 tries to redeem user 1 shares
        vm.startPrank(user2);
        vm.expectRevert();
        node.redeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();

        // user 2 successfully redeems shares
        vm.startPrank(user1);
        node.redeem(sharesToRedeem, address(user1), address(user1));
        vm.stopPrank();
    }
}
