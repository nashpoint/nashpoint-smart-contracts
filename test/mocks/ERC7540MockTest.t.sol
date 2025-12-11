// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract MockERC7540Tests is BaseTest {
    function setUp() public override {
        super.setUp();
        liquidityPool = new ERC7540Mock(asset, "Mock", "MOCK", testPoolManager);
    }

    function test_7540Mock_basic_deposit_flow() public {
        uint256 amount = 10 ether;

        // User requests deposit
        vm.startPrank(user);
        asset.approve(address(liquidityPool), amount);
        liquidityPool.requestDeposit(amount, user, user);
        vm.stopPrank();

        // Verify pending deposit
        uint256 pendingDeposits = liquidityPool.pendingDepositRequest(0, user);
        assertEq(amount, pendingDeposits);

        // Manager processes deposits
        vm.startPrank(testPoolManager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // User mints shares
        uint256 sharesClaimable = liquidityPool.maxMint(user);
        vm.startPrank(user);
        liquidityPool.mint(sharesClaimable, user, user);
        vm.stopPrank();

        // Verify final balances
        assertEq(liquidityPool.balanceOf(user), sharesClaimable);
        assertEq(liquidityPool.totalSupply(), liquidityPool.totalAssets());
    }

    function test_7540Mock_basic_redeem_flow() public {
        uint256 amount = 10 ether;

        // Setup: User deposits and gets shares first
        vm.startPrank(user);
        asset.approve(address(liquidityPool), amount);
        liquidityPool.requestDeposit(amount, user, user);
        vm.stopPrank();

        vm.startPrank(testPoolManager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        uint256 shares = liquidityPool.maxMint(user);
        vm.startPrank(user);
        liquidityPool.mint(shares, user, user);

        // User requests redemption
        liquidityPool.approve(address(liquidityPool), shares);
        liquidityPool.requestRedeem(shares, user, user);
        vm.stopPrank();

        // Verify pending redemption
        uint256 pendingRedemptions = liquidityPool.pendingRedeemRequest(0, user);
        assertEq(shares, pendingRedemptions);

        // Manager processes redemptions
        vm.startPrank(testPoolManager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();

        // User withdraws assets
        uint256 claimableAssets = liquidityPool.claimableRedeemRequest(0, user);
        vm.startPrank(user);

        liquidityPool.withdraw(claimableAssets, user, user);
        vm.stopPrank();

        // Verify final state
        assertEq(liquidityPool.balanceOf(user), 0);
        assertEq(liquidityPool.totalSupply(), liquidityPool.totalAssets());
    }

    function test_7540Mock_multiple_deposits() public {
        uint256 amount = 10 ether;
        address[3] memory users = [user, user2, user3];

        // Request deposits loop
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            asset.approve(address(liquidityPool), amount);
            liquidityPool.requestDeposit(amount, users[i], users[i]);
            vm.stopPrank();
        }

        // Verify pending deposits loop
        for (uint256 i = 0; i < users.length; i++) {
            assertEq(liquidityPool.pendingDepositRequest(0, users[i]), amount);
        }

        assertEq(liquidityPool.totalSupply(), 0);
        assertEq(liquidityPool.totalAssets(), 0);

        vm.startPrank(testPoolManager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        assertEq(liquidityPool.totalSupply(), 0);
        assertEq(liquidityPool.totalAssets(), 30 ether);

        // Mint and verify loop
        uint256 shares;
        for (uint256 i = 0; i < users.length; i++) {
            shares = liquidityPool.maxMint(users[i]);
            vm.prank(users[i]);
            liquidityPool.mint(shares, users[i], users[i]);

            assertEq(liquidityPool.balanceOf(users[i]), shares);
            assertEq(liquidityPool.convertToAssets(shares), amount);
            assertEq(liquidityPool.totalSupply(), shares * (i + 1));
            assertEq(liquidityPool.totalAssets(), amount * 3);
        }
    }

    function test_7540Mock_multiple_redemptions() public {
        uint256 amount = 10 ether;
        address[3] memory users = [user, user2, user3];

        // Request deposits loop
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            asset.approve(address(liquidityPool), amount);
            liquidityPool.requestDeposit(amount, users[i], users[i]);
            vm.stopPrank();
        }

        vm.startPrank(testPoolManager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        // Mint shares loop
        uint256 shares;
        for (uint256 i = 0; i < users.length; i++) {
            shares = liquidityPool.maxMint(users[i]);
            vm.prank(users[i]);
            liquidityPool.mint(shares, users[i], users[i]);
        }

        // Request redemptions loop
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            liquidityPool.approve(address(liquidityPool), shares);
            liquidityPool.requestRedeem(shares, users[i], users[i]);
            vm.stopPrank();
        }

        assertEq(liquidityPool.totalSupply(), shares * users.length);
        assertEq(liquidityPool.totalAssets(), amount * users.length);

        vm.startPrank(testPoolManager);
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();

        assertEq(liquidityPool.totalSupply(), shares * users.length);
        assertEq(liquidityPool.totalAssets(), amount * users.length);

        // Withdraw loop
        for (uint256 i = 0; i < users.length; i++) {
            uint256 claimableAssets = liquidityPool.claimableRedeemRequest(0, users[i]);
            vm.startPrank(users[i]);
            liquidityPool.withdraw(claimableAssets, users[i], users[i]);
            vm.stopPrank();

            assertEq(liquidityPool.balanceOf(users[i]), 0);
            assertEq(liquidityPool.convertToAssets(shares), amount);
        }
    }

    function test_7540Mock_earns_interest(uint256 amount, uint256 interest) public {
        amount = bound(amount, 1 ether, 1e36);
        interest = bound(interest, 0, 1e36);

        deal(address(asset), address(user), amount);

        // User requests deposit
        vm.startPrank(user);
        asset.approve(address(liquidityPool), amount);
        liquidityPool.requestDeposit(amount, user, user);
        vm.stopPrank();

        // Manager processes deposits
        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        // User mints shares
        uint256 sharesClaimable = liquidityPool.maxMint(user);

        vm.prank(user);
        liquidityPool.mint(sharesClaimable, user, user);

        uint256 shares = liquidityPool.balanceOf(address(user));
        uint256 assets = asset.balanceOf(address(liquidityPool));

        // Verify final balances
        assertEq(liquidityPool.balanceOf(user), sharesClaimable);
        assertEq(liquidityPool.totalSupply(), liquidityPool.totalAssets());
        assertEq(assets, liquidityPool.totalAssets());
        assertEq(liquidityPool.convertToAssets(shares), amount);

        // simulate interest earned & user share value increased
        deal(address(asset), address(liquidityPool), assets + interest);
        assertApproxEqRel(liquidityPool.convertToAssets(shares), amount + interest, 1e12);
    }

    function test_7540Mock_revert_on_zero_deposit() public {
        vm.startPrank(user);
        vm.expectRevert("Cannot request deposit of 0 assets");
        liquidityPool.requestDeposit(0, user, user);
        vm.stopPrank();
    }

    function test_7540Mock_revert_on_zero_redeem() public {
        vm.startPrank(user);
        vm.expectRevert("Cannot request redeem of 0 shares");
        liquidityPool.requestRedeem(0, user, user);
        vm.stopPrank();
    }

    function test_7540Mock_revert_on_non_manager_process() public {
        vm.startPrank(user);
        vm.expectRevert("only poolManager can execute");
        liquidityPool.processPendingDeposits();

        vm.expectRevert("only poolManager can execute");
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();
    }
}
