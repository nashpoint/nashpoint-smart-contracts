// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {MathLib} from "src/libraries/MathLib.sol";

contract NodeFuzzTest is BaseTest {
    uint256 public maxDeposit;

    function setUp() public override {
        super.setUp();
        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.maxDepositSize();

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        node.addRouter(address(router7540));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSITS & WITHDRAWALS
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_node_large_deposit(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);
        _seedNode(seedAmount);

        deal(address(asset), address(user), depositAmount);
        deal(address(asset), address(user2), depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 userAssets = node.convertToAssets(node.balanceOf(address(user)));
        assertEq(userAssets, depositAmount);

        vm.startPrank(user2);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user2);
        vm.stopPrank();

        uint256 user2Assets = node.convertToAssets(node.balanceOf(address(user2)));
        assertEq(user2Assets, depositAmount);

        assertEq(userAssets, user2Assets);
    }

    function test_fuzz_node_large_mint(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);
        _seedNode(seedAmount);

        deal(address(asset), address(user), depositAmount);
        deal(address(asset), address(user2), depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.mint(node.convertToShares(depositAmount), user);
        vm.stopPrank();

        uint256 userShares = (node.balanceOf(address(user)));
        assertEq(userShares, node.convertToShares(depositAmount));

        vm.startPrank(user2);
        asset.approve(address(node), depositAmount);
        node.mint(node.convertToShares(depositAmount), user2);
        vm.stopPrank();

        uint256 user2Shares = (node.balanceOf(address(user2)));
        assertEq(user2Shares, node.convertToShares(depositAmount));

        assertEq(userShares, user2Shares);
    }

    function test_fuzz_node_requestRedeem_partial_redeem(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 10, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);

        deal(address(asset), address(user), depositAmount);
        _seedNode(seedAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 userBalance = node.balanceOf(address(user));
        uint256 sharesToRedeem = bound(depositAmount, 1, userBalance - 1);

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);

        assertEq(node.pendingRedeemRequest(0, user), sharesToRedeem);

        vm.startPrank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableAssets = node.maxWithdraw(user);
        uint256 pendingAssets = node.convertToAssets(node.pendingRedeemRequest(0, user));
        uint256 userAssets = asset.balanceOf(address(user));
        uint256 userShares = node.balanceOf(address(user));

        assertEq(claimableAssets + pendingAssets + userAssets + node.convertToAssets(userShares), depositAmount);
    }

    function test_fuzz_node_requestRedeem_full(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 10, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);

        deal(address(asset), address(user), depositAmount);
        _seedNode(seedAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 sharesToRedeem = node.balanceOf(address(user));

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);

        assertEq(node.pendingRedeemRequest(0, user), sharesToRedeem);

        vm.startPrank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableAssets = node.maxWithdraw(user);
        uint256 pendingAssets = node.convertToAssets(node.pendingRedeemRequest(0, user));
        uint256 userAssets = asset.balanceOf(address(user));
        uint256 userShares = node.balanceOf(address(user));

        assertEq(claimableAssets, depositAmount);
        assertEq(pendingAssets, 0);
        assertEq(userShares, 0);
        assertEq(userAssets, 0);
    }

    function test_fuzz_node_requestRedeem_invalid_inputs(
        uint256 depositAmount,
        uint256 seedAmount,
        uint256 sharesToRedeem
    ) public {
        depositAmount = bound(depositAmount, 1, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);

        deal(address(asset), address(user), depositAmount);
        _seedNode(seedAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        sharesToRedeem = bound(sharesToRedeem, node.balanceOf(address(user)) + 1, type(uint256).max);

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();
    }

    function test_fuzz_node_withdaw_large_amount(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);
        _seedNode(seedAmount);

        deal(address(asset), address(user), depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 userAssets = node.convertToAssets(node.balanceOf(address(user)));
        assertEq(userAssets, depositAmount);

        uint256 sharesToRedeem = node.balanceOf(address(user));

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.fulfillRedeemFromReserve(user);
        vm.stopPrank();

        uint256 claimableAssets = node.maxWithdraw(user);

        vm.prank(user);
        node.withdraw(claimableAssets, user, user);

        userAssets = asset.balanceOf(address(user));
        assertEq(userAssets, depositAmount);
        assertEq(node.balanceOf(address(user)), 0);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(asset.balanceOf(address(node)), seedAmount);

        assertEq(node.pendingRedeemRequest(0, user), 0);
        assertEq(node.claimableRedeemRequest(0, user), 0);
    }

    function test_fuzz_node_redeem_large_amount(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);

        deal(address(asset), address(user), depositAmount);
        _seedNode(seedAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.mint(node.convertToShares(depositAmount), user);
        vm.stopPrank();

        uint256 userShares = (node.balanceOf(address(user)));
        assertEq(userShares, node.convertToShares(depositAmount));

        uint256 sharesToRedeem = node.balanceOf(address(user));

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.fulfillRedeemFromReserve(user);
        vm.stopPrank();

        uint256 claimableShares = node.maxRedeem(user);

        vm.prank(user);
        node.redeem(claimableShares, user, user);

        uint256 userAssets = asset.balanceOf(address(user));
        assertEq(userAssets, depositAmount);
        assertEq(node.balanceOf(address(user)), 0);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(asset.balanceOf(address(node)), seedAmount);

        assertEq(node.pendingRedeemRequest(0, user), 0);
        assertEq(node.claimableRedeemRequest(0, user), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        FEE PAYMENTS
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_node_payManagementFees(uint64 annualFee, uint64 protocolFee, uint256 seedAmount) public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        annualFee = uint64(bound(annualFee, 0, 0.99 ether));
        protocolFee = uint64(bound(protocolFee, 0, 0.99 ether));
        seedAmount = bound(seedAmount, 1e18, 1e36);

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(annualFee);
        registry.setProtocolManagementFee(protocolFee);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(seedAmount);
        assertEq(node.totalAssets(), seedAmount);

        vm.warp(block.timestamp + 364 days);

        vm.prank(owner);
        uint256 feeForPeriod = node.payManagementFees();
        uint256 expectedFee = annualFee * seedAmount / 1e18;

        assertEq(feeForPeriod, expectedFee);
        assertEq(
            asset.balanceOf(address(ownerFeesRecipient)) + asset.balanceOf(address(protocolFeesRecipient)), expectedFee
        );
        assertEq(node.totalAssets(), seedAmount - feeForPeriod);
    }

    function test_fuzz_node_payManagementFees_different_durations(
        uint64 annualFee,
        uint64 protocolFee,
        uint256 seedAmount,
        uint256 duration
    ) public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        // warp back one day to undo the warp forward in setUp()
        vm.warp(block.timestamp - 1 days);

        annualFee = uint64(bound(annualFee, 0, 0.99 ether));
        protocolFee = uint64(bound(protocolFee, 0, 0.99 ether));
        seedAmount = bound(seedAmount, 1e18, 1e36);
        duration = bound(duration, 2 days, 365 days);

        vm.startPrank(owner);
        node.setAnnualManagementFee(annualFee);
        registry.setProtocolManagementFee(protocolFee);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        vm.stopPrank();

        _seedNode(seedAmount);
        assertEq(node.totalAssets(), seedAmount);

        vm.warp(block.timestamp + duration);

        vm.prank(owner);
        uint256 feeForPeriod = node.payManagementFees();
        uint256 expectedFee = (annualFee * seedAmount * duration) / (1e18 * 365 days);

        assertEq(feeForPeriod, expectedFee);
        assertEq(
            asset.balanceOf(address(ownerFeesRecipient)) + asset.balanceOf(address(protocolFeesRecipient)), expectedFee
        );
        assertEq(node.totalAssets(), seedAmount - feeForPeriod);
    }

    /*//////////////////////////////////////////////////////////////
                        SWING PRICING
    //////////////////////////////////////////////////////////////*/

    // invariant 1: previewDeposit always returns the same value as shares to be minted after swing pricing applied
    // invariant 2: shares created always greater than convertToShares when reserve below target
    // invariant 3: deposit bonus never exceeds the value of the max swing factor
    // invariant 4: returned assets are always less than withdrawal amount
    // invariant 5: withdrawal penalty never exceeds the value of the max swing factor

    function test_fuzz_node_swing_price_previewDeposit_matches(
        uint64 targetReserveRatio,
        uint64 maxSwingFactor,
        uint256 seedAmount,
        uint256 depositAmount,
        uint256 sharesToRedeem
    ) public {
        targetReserveRatio = uint64(bound(targetReserveRatio, 0.01 ether, 0.1 ether)); // todo: extend test or hardcode these values
        maxSwingFactor = uint64(bound(maxSwingFactor, 0, 0.1 ether)); // todo: extend test or hardcode these values
        seedAmount = bound(seedAmount, 1 ether, maxDeposit);
        depositAmount = bound(depositAmount, 1 ether, maxDeposit);

        deal(address(asset), address(user), seedAmount);
        _userDeposits(user, seedAmount);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.enableSwingPricing(true, maxSwingFactor);
        node.updateTargetReserveRatio(targetReserveRatio);
        node.updateComponentAllocation(address(vault), 1 ether - targetReserveRatio, 0, address(router4626));

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 investmentAmount = router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        sharesToRedeem = bound(sharesToRedeem, 2, node.convertToShares(currentReserve));
        _userRedeemsAndClaims(user, sharesToRedeem, address(node));

        uint256 expectedShares = node.previewDeposit(depositAmount);

        deal(address(asset), address(user), depositAmount);
        uint256 sharesBefore = node.balanceOf(address(user));

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        uint256 sharesReceived = node.deposit(depositAmount, user);
        vm.stopPrank();

        // invariant 1: previewDeposit always returns the same value as shares to be minted after swing pricing applied
        assertEq(sharesReceived, expectedShares);
        assertEq(node.balanceOf(address(user)), sharesBefore + sharesReceived);
    }

    function test_fuzz_node_swing_price_deposit_never_exceeds_max(
        uint64 maxSwingFactor,
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint256 depositAmount
    ) public {
        maxSwingFactor = uint64(bound(maxSwingFactor, 0.01 ether, 0.99 ether));
        targetReserveRatio = uint64(bound(targetReserveRatio, 0.01 ether, 0.99 ether));
        seedAmount = bound(seedAmount, 1 ether, maxDeposit);
        depositAmount = bound(depositAmount, 1 ether, maxDeposit);

        deal(address(asset), address(user), seedAmount);
        _userDeposits(user, seedAmount);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.enableSwingPricing(true, maxSwingFactor);
        node.updateTargetReserveRatio(targetReserveRatio);
        node.updateComponentAllocation(address(vault), 1 ether - targetReserveRatio, 0, address(router4626));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 investmentAmount = router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        uint256 sharesToRedeem = node.convertToShares(currentReserve) / 10 + 1;
        _userRedeemsAndClaims(user, sharesToRedeem, address(node));

        // invariant 2: shares created always greater than convertToShares when reserve below target
        uint256 nonAdjustedShares = node.convertToShares(depositAmount);
        uint256 expectedShares = node.previewDeposit(depositAmount);
        assertGt(expectedShares, nonAdjustedShares);

        // invariant 3: deposit bonus never exceeds the value of the max swing factor
        uint256 depositBonus = expectedShares - nonAdjustedShares;
        uint256 maxBonus = depositAmount * maxSwingFactor / 1e18;
        assertLt(depositBonus, maxBonus);
    }

    function test_fuzz_node_swing_price_redeem_never_exceeds_max(
        uint64 maxSwingFactor,
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint256 withdrawalAmount
    ) public {
        maxSwingFactor = uint64(bound(maxSwingFactor, 0.01 ether, 0.99 ether));
        targetReserveRatio = uint64(bound(targetReserveRatio, 0.01 ether, 0.99 ether));
        seedAmount = bound(seedAmount, 100 ether, 1e36);

        deal(address(asset), address(user), seedAmount);
        _userDeposits(user, seedAmount);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.enableSwingPricing(true, maxSwingFactor);
        node.updateTargetReserveRatio(targetReserveRatio);
        node.updateComponentAllocation(address(vault), 1 ether - targetReserveRatio, 0, address(router4626));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 investmentAmount = router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        withdrawalAmount = bound(withdrawalAmount, 1 ether, currentReserve);

        uint256 reserveRatio = _getCurrentReserveRatio();
        assertEq(reserveRatio, targetReserveRatio);

        // invariant 4: returned assets are always less than withdrawal amount
        uint256 sharesToRedeem = node.convertToShares(withdrawalAmount);
        uint256 returnedAssets = _userRedeemsAndClaims(user, sharesToRedeem, address(node));
        assertLt(returnedAssets, withdrawalAmount);

        // invariant 5: withdrawal penalty never exceeds the value of the max swing factor
        uint256 tolerance = 10;
        uint256 withdrawalPenalty = withdrawalAmount - returnedAssets - tolerance;
        uint256 maxPenalty = withdrawalAmount * maxSwingFactor / 1e18;
        assertLt(withdrawalPenalty, maxPenalty);
    }

    function test_fuzz_node_swing_price_vault_attack(uint64 maxSwingFactor, uint64 targetReserveRatio, uint256 t)
        public
    {
        maxSwingFactor = uint64(bound(maxSwingFactor, 0.001 ether, 0.1 ether));
        targetReserveRatio = uint64(bound(targetReserveRatio, 0.01 ether, 0.1 ether));
        t = bound(t, 1e16, 1e18 - 1);
        uint256 seedAmount = 900_000 ether;
        uint256 userDeposit = 100_000 ether;
        uint256 tolerance = 1000;

        deal(address(asset), address(user2), userDeposit);

        vm.startPrank(user);
        asset.approve(address(node), seedAmount);
        node.deposit(seedAmount, user);
        vm.stopPrank();

        vm.startPrank(user2);
        asset.approve(address(node), type(uint256).max);
        node.deposit(userDeposit, user2);
        vm.stopPrank();

        // jump forward in time to apply swing pricing
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(owner);
        node.updateTargetReserveRatio(targetReserveRatio);
        node.updateComponentAllocation(address(vault), 1 ether - targetReserveRatio, 0, address(router4626));
        vm.stopPrank();

        // jump back in time to be in rebalance window
        vm.warp(block.timestamp - 1 days);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = _getCurrentReserveRatio();
        assertEq(reserveRatio, node.targetReserveRatio());

        // enable swing pricing
        vm.prank(owner);
        node.enableSwingPricing(true, maxSwingFactor);

        uint256 sharesToRedeem = (1e18 - t) * node.balanceOf(user2) / 1e18;

        if (sharesToRedeem > 0) {
            // user 2 makes their first withdrawl
            vm.startPrank(user2);
            node.approve(address(node), type(uint256).max);
            node.requestRedeem(sharesToRedeem, user2, user2);
            vm.stopPrank();
        }

        if (node.pendingRedeemRequest(0, user2) > 0) {
            vm.prank(rebalancer);
            node.fulfillRedeemFromReserve(user2);
        }

        uint256 user2BalBefore = asset.balanceOf(user2);

        // user 2 withdraws max assets
        uint256 maxWithdraw = node.maxWithdraw(address(user2));

        if (maxWithdraw > 0) {
            vm.prank(user2);
            node.withdraw(maxWithdraw, address(user2), address(user2));
        }

        uint256 user2FirstWithdrawal = asset.balanceOf(user2) - user2BalBefore;

        emit log_named_uint("user2 first withdrawal:", user2FirstWithdrawal);

        uint256 user2SecondWithdrawal = 0;
        // Only do second withdrawal if there should be something left to withdraw.
        if (t > 0) {
            sharesToRedeem = node.balanceOf(user2); // Redeem the rest

            if (sharesToRedeem > 0) {
                // user 2 makes there first withdrawl
                vm.startPrank(user2);
                node.approve(address(node), type(uint256).max);
                node.requestRedeem(sharesToRedeem, user2, user2);
                vm.stopPrank();
            }

            if (asset.balanceOf(address(node)) > 0) {
                vm.prank(rebalancer);
                node.fulfillRedeemFromReserve(user2);
            }

            user2BalBefore = asset.balanceOf(user2);

            // user 2 withdraws max assets
            maxWithdraw = node.maxWithdraw(address(user2));

            if (maxWithdraw > 0) {
                vm.prank(user2);
                node.withdraw(maxWithdraw, address(user2), address(user2));
            }

            user2SecondWithdrawal = asset.balanceOf(user2) - user2BalBefore;
        }

        emit log_named_uint("user2 second withdrawal:", user2SecondWithdrawal);
        uint256 totalWithdrawn = user2FirstWithdrawal + user2SecondWithdrawal;
        emit log_named_uint("total withdrawn:", totalWithdrawn);

        vm.startPrank(user2);
        asset.approve(address(node), type(uint256).max);
        node.deposit(totalWithdrawn, user2);
        vm.stopPrank();

        uint256 user2Assets = node.convertToAssets(node.balanceOf(user2));
        emit log_named_uint("user2 in-protocol share value:", user2Assets);

        emit log_named_uint("sum of share value and withdrawn value:", user2Assets + totalWithdrawn);
        emit log_named_uint("total deposited by user2:", 100_000 ether + totalWithdrawn);

        assertLt(user2Assets, userDeposit + tolerance);
    }

    /*//////////////////////////////////////////////////////////////
                        TOTAL ASSET & CACHE
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_node_component_earns_interest() public {}

    function test_fuzz_node_cache_totalAssets_4626_earns_interest(uint256 interestEarned, uint256 userDeposit) public {
        interestEarned = bound(interestEarned, 1e18, 1e36);
        userDeposit = bound(userDeposit, 1e18, 1e36);

        deal(address(asset), address(user), userDeposit);
        _userDeposits(user, userDeposit);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.updateTargetReserveRatio(0.2 ether);
        node.updateComponentAllocation(address(vault), 0.8 ether, 0, address(router4626));
        vm.stopPrank();

        uint256 expectedVaultAssets = MathLib.mulDiv(userDeposit, 0.8 ether, 1 ether);

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 vaultAssets = router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        // assert that shares are 1:1 assets & vault has the correct assets
        assertEq(node.convertToAssets(1), 1);
        assertEq(asset.balanceOf(address(vault)), vaultAssets);
        assertEq(vaultAssets, expectedVaultAssets);

        // deal assets to the vault to simulate interest earned
        deal(address(asset), address(vault), vaultAssets + interestEarned);
        assertEq(asset.balanceOf(address(vault)), vaultAssets + interestEarned);

        // update totalAssets cache
        vm.prank(rebalancer);
        node.updateTotalAssets();

        // assert that totalAssets cache has been updated (accurate to 0.0001%)
        assertApproxEqRel(node.totalAssets(), userDeposit + interestEarned, 1e12);
    }

    function test_fuzz_node_cache_totalAssets_4626_earns_interest_multiple_times(
        uint256 maxInterest,
        uint256 randUint,
        uint256 userDeposit,
        uint256 runs
    ) public {
        maxInterest = bound(maxInterest, 1 ether, maxDeposit);
        randUint = bound(randUint, 0, 1 ether);
        userDeposit = bound(userDeposit, 1 ether, maxDeposit);
        runs = bound(runs, 1, 100);

        deal(address(asset), address(user), userDeposit);
        _userDeposits(user, userDeposit);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.updateTargetReserveRatio(0.2 ether);
        node.updateComponentAllocation(address(vault), 0.8 ether, 0, address(router4626));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 vaultAssets = router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        uint256 interestEarned = 0;
        for (uint256 i = 0; i < runs; i++) {
            uint256 interestPayment = uint256(keccak256(abi.encodePacked(randUint++, i)));
            interestPayment = bound(interestPayment, 0, maxInterest);
            deal(address(asset), address(vault), vaultAssets + interestPayment);
            vaultAssets = asset.balanceOf(address(vault));
            interestEarned += interestPayment;
        }

        // update totalAssets cache
        vm.prank(rebalancer);
        node.updateTotalAssets();

        assertApproxEqRel(node.totalAssets(), userDeposit + interestEarned, 1e12);
    }

    function test_fuzz_node_cache_totalAssets_7540_earns_interest(uint256 userDeposit, uint256 interestEarned) public {
        userDeposit = bound(userDeposit, 1 ether, 1e36);
        interestEarned = bound(interestEarned, 0, 1e36);
        deal(address(asset), address(user), userDeposit);
        _userDeposits(user, userDeposit);

        vm.warp(block.timestamp + 1 days);

        _setAllocationToAsyncVault(address(liquidityPool), 0.8 ether);

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 vaultAssets = router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        node.updateTotalAssets();
        vm.stopPrank();

        // deal assets to the vault to simulate interest earned
        deal(address(asset), address(liquidityPool), vaultAssets + interestEarned);
        assertEq(asset.balanceOf(address(liquidityPool)), vaultAssets + interestEarned);

        vm.prank(rebalancer);
        node.updateTotalAssets();

        assertApproxEqRel(node.totalAssets(), userDeposit + interestEarned, 1e12);
    }

    function test_fuzz_node_cache_totalAssets_7540_earns_interest_multiple_times(
        uint256 randUint,
        uint256 userDeposit,
        uint256 maxInterest,
        uint256 runs
    ) public {
        randUint = bound(randUint, 0, 1e18);
        userDeposit = bound(userDeposit, 1e18, 1e36);
        maxInterest = bound(maxInterest, 0, 1e36);
        runs = bound(runs, 1, 100);

        deal(address(asset), address(user), userDeposit);
        _userDeposits(user, userDeposit);

        vm.warp(block.timestamp + 1 days);

        _setAllocationToAsyncVault(address(liquidityPool), 0.8 ether);

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 vaultAssets = router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        node.updateTotalAssets();
        vm.stopPrank();

        uint256 interestEarned = 0;
        for (uint256 i = 0; i < runs; i++) {
            uint256 interestPayment = uint256(keccak256(abi.encodePacked(randUint++, i)));
            assertTrue(interestPayment > 0);
            interestPayment = bound(interestPayment, 0, maxInterest);
            deal(address(asset), address(liquidityPool), vaultAssets + interestPayment);
            vaultAssets = asset.balanceOf(address(liquidityPool));
            interestEarned += interestPayment;
        }

        vm.prank(rebalancer);
        node.updateTotalAssets();

        assertApproxEqRel(node.totalAssets(), userDeposit + interestEarned, 1e12);
    }

    function test_fuzz_node_component_loses_values() public {}

    function test_fuzz_node_total_assets_cache_is_updated() public {}

    //todo: check if cache returns 0

    /*//////////////////////////////////////////////////////////////
                        COMPONENT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    // figure out what to test here later

    // todo: create a mock token that spits out random stuff and see when it breaks your vault

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}
