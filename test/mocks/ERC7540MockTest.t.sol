// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract MockERC7540Tests is BaseTest {
    ERC7540Mock public liquidityPool;
    address public poolManager = makeAddr("poolManager");

    function setUp() public override {
        super.setUp();
        liquidityPool = new ERC7540Mock(asset, "Mock", "MOCK", poolManager);
    }

    function testBasicDepositFlow() public {
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
        vm.startPrank(poolManager);
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

    function testBasicRedeemFlow() public {
        uint256 amount = 10 ether;

        // Setup: User deposits and gets shares first
        vm.startPrank(user);
        asset.approve(address(liquidityPool), amount);
        liquidityPool.requestDeposit(amount, user, user);
        vm.stopPrank();

        vm.startPrank(poolManager);
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
        vm.startPrank(poolManager);
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

    function test_multipleDeposits() public {
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

        vm.startPrank(poolManager);
        liquidityPool.processPendingDeposits();
        vm.stopPrank();

        assertEq(liquidityPool.totalSupply(), 0);
        assertEq(liquidityPool.totalAssets(), 0);

        // Mint and verify loop
        uint256 shares;
        for (uint256 i = 0; i < users.length; i++) {
            shares = liquidityPool.maxMint(users[i]);
            vm.prank(users[i]);
            liquidityPool.mint(shares, users[i], users[i]);

            assertEq(liquidityPool.balanceOf(users[i]), shares);
            assertEq(liquidityPool.convertToAssets(shares), amount);
            assertEq(liquidityPool.totalSupply(), shares * (i + 1));
            assertEq(liquidityPool.totalAssets(), amount * (i + 1));
        }
    }

    function test_multipleRedemptions() public {
        uint256 amount = 10 ether;
        address[3] memory users = [user, user2, user3];

        // Request deposits loop
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            asset.approve(address(liquidityPool), amount);
            liquidityPool.requestDeposit(amount, users[i], users[i]);
            vm.stopPrank();
        }

        vm.startPrank(poolManager);
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

        vm.startPrank(poolManager);
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

    function testRevertOnZeroDeposit() public {
        vm.startPrank(user);
        vm.expectRevert("Cannot request deposit of 0 assets");
        liquidityPool.requestDeposit(0, user, user);
        vm.stopPrank();
    }

    function testRevertOnZeroRedeem() public {
        vm.startPrank(user);
        vm.expectRevert("Cannot request redeem of 0 shares");
        liquidityPool.requestRedeem(0, user, user);
        vm.stopPrank();
    }

    function testOnlyManagerCanProcess() public {
        vm.startPrank(user);
        vm.expectRevert("only poolManager can execute");
        liquidityPool.processPendingDeposits();

        vm.expectRevert("only poolManager can execute");
        liquidityPool.processPendingRedemptions();
        vm.stopPrank();
    }
}
