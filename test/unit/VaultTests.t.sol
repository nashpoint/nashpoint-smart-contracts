// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract VaultTests is BaseTest {
    function testDeposit() public {
        vm.startPrank(user1);
        node.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        uint256 shares = node.balanceOf(user1);

        assertEq(usdcMock.balanceOf(address(node)), DEPOSIT_100);
        assertEq(node.convertToAssets(shares), DEPOSIT_100);
    }

    function testMint() public {
        // user1 deposits 10 units and it is rebalanced into proportions
        seedNode();

        // assert node has 100 in assets and 10 of deposit asset
        assertEq(usdcMock.balanceOf(address(node)), DEPOSIT_10);
        assertEq(node.totalAssets(), DEPOSIT_100);

        // assert shares to assets are 1:1
        assertEq(node.convertToShares(1), 1);

        // user 2 MINTS 10 units of shares (equal to 10 units of assets)
        vm.startPrank(user2);
        node.mint(DEPOSIT_10, address(user2));
        vm.stopPrank();

        // assert user 2 has received 10 units of shares
        assertEq(node.balanceOf(address(user2)), DEPOSIT_10);

        // assert that node received 10 of deposit assets + 10 reserve
        assertEq(usdcMock.balanceOf(address(node)), DEPOSIT_10 * 2);

        // assert shares to assets are 1:1
        assertEq(node.convertToShares(1), 1);

        // assert that node has shares equivelant to the seed and deposit assets
        assertEq(node.totalSupply(), DEPOSIT_100 + DEPOSIT_10);
    }

    // TODO: write a test to get total assets even when you have no async assets
    function testTotalAssets() public {
        vm.startPrank(user1);
        node.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        assertEq(node.totalAssets(), DEPOSIT_100);
    }

    function testInvestCash() public {
        // add one component at 90% target ratio
        node.addComponent(address(vaultA), 90e16, false, address(vaultA));

        vm.startPrank(user1);
        node.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        // test that the cash reserve after investCash == the targetReserveRatio
        uint256 expectedCashReserve = DEPOSIT_100 * node.targetReserveRatio() / 1e18;
        assertEq(usdcMock.balanceOf(address(node)), expectedCashReserve);

        // remove some cash from reserve
        vm.startPrank(user1);
        node.requestRedeem(node.convertToShares(2e6), address(user1), address(user1));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // mint cash so invested assets = 100
        usdcMock.mint(address(vaultA), 10e6 + 1);

        // expect revert
        vm.startPrank(rebalancer);
        vm.expectRevert(); // error CashBelowTargetRatio();
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        // user 2 deposits 4 tokens to bring cash reserve to 12 tokens
        vm.startPrank(user2);
        node.deposit(4e6, address(user2));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        // asserts cash reserve == target reserve
        expectedCashReserve = node.totalAssets() * node.targetReserveRatio() / 1e18;
        assertEq(usdcMock.balanceOf(address(node)), expectedCashReserve);

        // test large deposit of 1000e18 (about 10x total assets)
        vm.startPrank(user3);
        node.deposit(START_BALANCE_1000, address(user3));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        // asserts cash reserve == target reserve
        expectedCashReserve = node.totalAssets() * node.targetReserveRatio() / 1e18;
        assertEq(usdcMock.balanceOf(address(node)), expectedCashReserve);
    }

    function testGetSwingFactor() public {
        // enable swing pricing
        node.enableSwingPricing(true);

        // note: no longer check on reverting as 0 is ok when using on deposits
        // a value at zero just means a deposit when reserve is full
        // reverts on withdrawal exceeds available reserve

        // vm.expectRevert();
        // node.getSwingFactor(0);

        vm.expectRevert();
        node.getSwingFactor(-1e16);

        // assert swing factor is zero if reserve target is met or exceeded
        uint256 swingFactor = node.getSwingFactor(int256(node.targetReserveRatio()));
        assertEq(swingFactor, 0);

        swingFactor = node.getSwingFactor(int256(node.targetReserveRatio()) + 1e16);
        assertEq(swingFactor, 0);

        // assert that swing factor approaches maxDiscount when reserve approaches zero
        int256 minReservePossible = 1;
        swingFactor = node.getSwingFactor(minReservePossible);
        assertEq(swingFactor, node.maxDiscount() - 1);

        // assert that 0.0% < swing factor < 0.1% when reserve approaches
        int256 maxReservePossible = int256(node.targetReserveRatio()) - 1;
        swingFactor = node.getSwingFactor(maxReservePossible);
        assertGt(swingFactor, 0);
        assertLt(swingFactor, 1e15); // 0.1%
    }

    function testAdjustedDeposit() public {
        // set the strategy to one asset at 90% holding
        node.addComponent(address(vaultA), 90e16, false, address(vaultA));

        // enable swing pricing
        node.enableSwingPricing(true);

        vm.startPrank(user1);
        node.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = getCurrentReserveRatio();
        assertEq(reserveRatio, node.targetReserveRatio());

        // mint cash so invested assets = 100
        usdcMock.mint(address(vaultA), 10 * DECIMALS + 1);

        // get the shares to be minted from a tx with no swing factor
        // this will break later when you complete 4626 conversion
        uint256 nonAdjustedShares = node.previewDeposit(DEPOSIT_10);

        // user 2 deposits 10e6 to node
        vm.startPrank(user2);
        node.deposit(DEPOSIT_10, address(user2));
        vm.stopPrank();

        // TEST 1: assert that no swing factor is applied when reserve ratio exceeds target

        // get the reserve ratio after the deposit and assert it is greater than target reserve ratio
        uint256 reserveRatioAfterTX = getCurrentReserveRatio();
        assertGt(reserveRatioAfterTX, node.targetReserveRatio());

        // get the actual shares received and assert they are the same i.e. no swing factor applied
        uint256 sharesReceived = node.balanceOf(address(user2));
        assertApproxEqAbs(sharesReceived, nonAdjustedShares, 1e12);

        // invest cash to return reserve ratio to 100%
        vm.startPrank(rebalancer);
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        uint256 redeemRequest = (5 * DECIMALS);

        // withdraw usdc to bring reserve ratio below 100%
        vm.startPrank(user2);
        node.requestRedeem(node.convertToShares(redeemRequest), (address(user2)), address((user2)));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.fulfilRedeemFromReserve(address(user2));

        // get the shares to be minted from a deposit with no swing factor applied
        nonAdjustedShares = node.previewDeposit(2e6);

        vm.startPrank(user3);
        node.deposit(2e6, address(user3));
        vm.stopPrank();

        // TEST 2: test that swing factor is applied with reserve ratio is below target

        // get the reserve ratio after the deposit and assert it is less than target reserve ratio
        reserveRatioAfterTX = getCurrentReserveRatio();
        assertLt(reserveRatioAfterTX, node.targetReserveRatio());

        // get the actual shares received and assert they are greater than & have swing factor applied
        sharesReceived = node.balanceOf(address(user3));
        assertGt(sharesReceived, nonAdjustedShares);

        console2.log(getCurrentReserveRatio());
    }

    function testAdjustedWithdraw() public {
        // enable swing pricing
        node.enableSwingPricing(true);

        // set the strategy to one asset at 90% holding
        node.addComponent(address(vaultA), 90e16, false, address(vaultA));

        vm.startPrank(user1);
        node.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = getCurrentReserveRatio();
        assertEq(reserveRatio, node.targetReserveRatio());

        // mint cash so invested assets = 100
        usdcMock.mint(address(vaultA), 10e6 + 1);

        // user 2 deposits 10e6 to node and burns the rest of their usdc
        vm.startPrank(user2);
        node.deposit(DEPOSIT_10, address(user2));
        usdcMock.transfer(0x000000000000000000000000000000000000dEaD, usdcMock.balanceOf(address(user2)));
        vm.stopPrank();

        // assert user2 has zero usdc balance
        assertEq(usdcMock.balanceOf(address(user2)), 0);

        // rebalancer invests excess reserve
        vm.startPrank(rebalancer);
        node.investInSyncVault(address(vaultA));
        vm.stopPrank();

        // grab share value of deposit
        uint256 sharesToRedeem = node.convertToShares(DEPOSIT_10);

        // user 2 withdraws the same amount they deposited
        vm.startPrank(user2);
        node.requestRedeem(sharesToRedeem, address(user2), address(user2));
        vm.stopPrank();

        // assert that user2 has burned all shares to withdraw max usdc
        uint256 user2NodeClosingBalance = node.balanceOf(address(user2));
        assertEq(user2NodeClosingBalance, 0);

        // assert that user2 received less USDC back than they deposited
        uint256 usdcReturned = usdcMock.balanceOf(address(user2));
        assertLt(usdcReturned, DEPOSIT_10);

        // note: this test does not check if the correct amount was returned
        // only that is was less than originally deposited
        // check for correct swing factor is in that test
    }

    function testAddComponent() public {
        address component = address(vaultA);
        uint256 targetRatio = 20e16;
        node.addComponent(component, targetRatio, false, component);

        assertTrue(node.isComponent(component));
        assertEq(node.getComponentRatio(component), targetRatio);
        assertFalse(node.isAsync(component));
    }

    function testGetPendingRedeemAssets() public {
        // seed the node vault and rebalance into underlying assets
        seedNode();
        node.enableLiquiateReserveBelowTarget(true);

        // assert getPendingRedeemAssets returns zero after setup
        assertEq(node.getPendingRedeemAssets(), 0);

        // select a value of share to redeem that is 10% of user shares in node
        uint256 redemption = node.convertToShares(node.balanceOf(address(user1)) / 100);

        // user requests redeem
        vm.startPrank(user1);
        node.requestRedeem(redemption, address(user1), address(user1));
        vm.stopPrank();

        // assert getPendingRedeemAssets is correctly tallying the request
        assertEq(node.getPendingRedeemAssets(), node.convertToAssets(redemption));

        // user requests to redeem same # of shares again
        vm.startPrank(user1);
        node.requestRedeem(redemption, address(user1), address(user1));
        vm.stopPrank();

        // assert getPendingRedeemAssets is correctly tallying the request
        assertEq(node.getPendingRedeemAssets(), node.convertToAssets(redemption * 2));

        // user 2 deposits and immediately requests a redemption of same value
        vm.startPrank(user2);
        node.deposit(DEPOSIT_100, address(user2));
        node.requestRedeem(redemption, address(user2), address(user2));
        vm.stopPrank();

        // assert getPendingRedeemAssets correctly tracking balance for user 2
        assertEq(node.getPendingRedeemAssets(), node.convertToAssets(redemption * 3));

        // fulfils 2 x redemption for user 1 and assert getPendingRedeemAssets reduced correctly
        vm.startPrank(rebalancer);
        node.fulfilRedeemFromReserve(user1);
        assertEq(node.getPendingRedeemAssets(), node.convertToAssets(redemption));

        // fulfil pending redeem for user 2 and assert getPendingRedeemAssets == 0
        node.fulfilRedeemFromReserve(user2);
        assertEq(node.getPendingRedeemAssets(), 0);

        vm.stopPrank();

        // rebalancer rebalances strategies so that cash reserve is depleted down to target ratio 10%
        rebalancerInvestsInAsyncVault(address(liquidityPool));
        rebalancerInvestsCash(address(vaultA));
        rebalancerInvestsCash(address(vaultB));
        rebalancerInvestsCash(address(vaultC));

        // grab total value of user shares still remaining
        uint256 totalShares = node.balanceOf(address(user1));

        // assert that the shares are worth more than available reserve
        assertGt(node.convertToAssets(totalShares), usdcMock.balanceOf(address(node)));

        // user 1 request redeem for all their shares
        vm.startPrank(user1);
        node.requestRedeem(totalShares, address(user1), address(user1));
        vm.stopPrank();

        // assert the pending redeem assets > cash reserve
        assertGt(node.getPendingRedeemAssets(), usdcMock.balanceOf(address(node)));
    }

    function testSwingFactorAppliedToPending() public {
        seedNode();
        node.enableSwingPricing(true);

        // select a value of share to redeem that is 10% of user shares in node
        uint256 redemption = node.convertToShares(node.balanceOf(address(user1)) / 100);

        // user2 deposits to node
        vm.startPrank(user2);
        node.deposit(DEPOSIT_100, address(user2));
        vm.stopPrank();

        // rebalancer rebalances strategies so that cash reserve is depleted down to target ratio 10%
        rebalancerInvestsInAsyncVault(address(liquidityPool));
        rebalancerInvestsCash(address(vaultA));
        rebalancerInvestsCash(address(vaultB));
        rebalancerInvestsCash(address(vaultC));

        // user 1 requests redemption
        vm.startPrank(user1);
        node.requestRedeem(redemption, address(user1), address(user1));
        vm.stopPrank();

        // Get the index for the redeem request from controllerToRedeemIndex mapping
        uint256 index1 = node.controllerToRedeemIndex(user1);

        // Retrieve the swingFactor from the redeem request by accessing its tuple
        (, uint256 user1SharesPending,,, uint256 user1SharesAdjusted) = node.redeemRequests(index1 - 1);

        // assert thats shares adjusted is lower as swing pricing is applied
        assertGt(user1SharesPending, user1SharesAdjusted);

        // user 2 requests redeem
        vm.startPrank(user2);
        node.requestRedeem(redemption, address(user2), address(user2));
        vm.stopPrank();

        // Get the index for the redeem request from controllerToRedeemIndex mapping
        uint256 index2 = node.controllerToRedeemIndex(user2);

        // Retrieve the swingFactor from the redeem request by accessing its tuple
        (, uint256 user2SharesPending,,, uint256 user2SharesAdjusted) = node.redeemRequests(index2 - 1);

        // assert thats shares adjusted is lower as swing pricing is applied
        assertGt(user2SharesPending, user2SharesAdjusted);

        // grab the delta between the two for both users
        uint256 delta1 = user1SharesPending - user1SharesAdjusted;
        uint256 delta2 = user2SharesPending - user2SharesAdjusted;

        // assert delta is higher for user two as greater swing price applied
        assertGt(delta2, delta1);
    }

    function testNewDeposit() public {
        // add a single component at 90% of totalAssets
        node.addComponent(address(vaultA), 90e16, false, address(vaultA));
        node.enableLiquiateReserveBelowTarget(true);

        // user makes deposit of 100 units
        vm.startPrank(user1);
        node.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // rebalancer rebalances node instant vaults
        rebalancerInvestsCash(address(vaultA));

        // assert totalAssets == 100 & reserve == 10
        assertEq(node.totalAssets(), DEPOSIT_100);  
        assertEq(usdcMock.balanceOf(address(node)), DEPOSIT_10);     
        
        // user requests 10 units
        vm.startPrank(user1);
        node.requestRedeem(node.convertToShares(DEPOSIT_10), address(user1), address(user1));        
        vm.stopPrank();

        // rebalancer fulfils user request for 10
        vm.startPrank(rebalancer);
        node.fulfilRedeemFromReserve(address(user1));
        vm.stopPrank();

        // user withdraws
        vm.startPrank(user1);
        node.withdraw(DEPOSIT_10, address(user1), address(user1));
        vm.stopPrank();

        // assert zero reserve
        assertEq(usdcMock.balanceOf(address(node)), 0);

        vm.startPrank(user1);
        node.newDeposit(DEPOSIT_1, address(user1));
        vm.stopPrank();
    }
}
