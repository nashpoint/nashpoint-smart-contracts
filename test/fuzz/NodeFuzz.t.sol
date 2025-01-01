// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";

contract NodeFuzzTest is BaseTest {
    uint256 public maxDeposit;

    function setUp() public override {
        super.setUp();
        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.MAX_DEPOSIT();
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
        depositAmount = bound(depositAmount, 10, maxDeposit);
        seedAmount = bound(seedAmount, 1, maxDeposit);

        deal(address(asset), address(user), depositAmount);
        _seedNode(seedAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        sharesToRedeem = bound(sharesToRedeem, node.balanceOf(address(user)) + 1, maxDeposit);

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();
    }

    function test_fuzz_node_withdaw_large_amount(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        seedAmount = bound(seedAmount, 1, 100);
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
        depositAmount = bound(depositAmount, 1e24, maxDeposit);
        deal(address(asset), address(user), depositAmount);
        seedAmount = bound(seedAmount, 1, 100);
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

    function test_fuzz_node_payManagementFees(uint256 annualFee, uint256 protocolFee, uint256 seedAmount) public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        annualFee = bound(annualFee, 0, 1e18);
        protocolFee = bound(protocolFee, 0, 1e18);
        seedAmount = bound(seedAmount, 1e18, 1e36);

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(annualFee);
        registry.setProtocolManagementFee(protocolFee);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(seedAmount);
        assertEq(node.totalAssets(), seedAmount);

        vm.warp(block.timestamp + 365 days);

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
        uint256 annualFee,
        uint256 protocolFee,
        uint256 seedAmount,
        uint256 duration
    ) public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        annualFee = bound(annualFee, 0, 1e18);
        protocolFee = bound(protocolFee, 0, 1e18);
        seedAmount = bound(seedAmount, 1e18, 1e36);
        duration = bound(duration, 1 days, 365 days);

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
        uint256 targetReserveRatio,
        uint256 maxSwingFactor,
        uint256 seedAmount,
        uint256 depositAmount,
        uint256 sharesToRedeem
    ) public {
        targetReserveRatio = bound(targetReserveRatio, 0.01 ether, 0.1 ether);
        maxSwingFactor = bound(maxSwingFactor, 100, 0.1 ether);
        seedAmount = bound(seedAmount, 1e18, 1e36);
        depositAmount = bound(depositAmount, 1e18, 100e18);

        deal(address(asset), address(user), seedAmount);
        _userDeposits(user, seedAmount);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.enableSwingPricing(true, maxSwingFactor);
        node.updateReserveAllocation(ComponentAllocation({targetWeight: targetReserveRatio, maxDelta: 0}));
        node.updateComponentAllocation(
            address(vault), ComponentAllocation({targetWeight: 1 ether - targetReserveRatio, maxDelta: 0.1 ether})
        );

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 investmentAmount = router4626.invest(address(node), address(vault));
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        sharesToRedeem = bound(sharesToRedeem, 2, node.convertToShares(currentReserve));
        _userRedeemsAndClaims(user, sharesToRedeem);

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
        uint256 maxSwingFactor,
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 depositAmount
    ) public {
        maxSwingFactor = bound(maxSwingFactor, 0.01 ether, 0.99 ether);
        targetReserveRatio = bound(targetReserveRatio, 0.01 ether, 0.99 ether);
        seedAmount = bound(seedAmount, 1 ether, 1e36);
        depositAmount = bound(depositAmount, 1 ether, 1e36);

        deal(address(asset), address(user), seedAmount);
        _userDeposits(user, seedAmount);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.enableSwingPricing(true, maxSwingFactor);
        node.updateReserveAllocation(ComponentAllocation({targetWeight: targetReserveRatio, maxDelta: 0}));
        node.updateComponentAllocation(
            address(vault), ComponentAllocation({targetWeight: 1 ether - targetReserveRatio, maxDelta: 0})
        );
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 investmentAmount = router4626.invest(address(node), address(vault));
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        uint256 sharesToRedeem = node.convertToShares(currentReserve) / 10 + 1;

        _userRedeemsAndClaims(user, sharesToRedeem);

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
        uint256 maxSwingFactor,
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 withdrawalAmount
    ) public {
        maxSwingFactor = bound(maxSwingFactor, 0.01 ether, 0.99 ether);
        targetReserveRatio = bound(targetReserveRatio, 0.01 ether, 0.99 ether);
        seedAmount = bound(seedAmount, 100 ether, 1e36);

        deal(address(asset), address(user), seedAmount);
        _userDeposits(user, seedAmount);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.enableSwingPricing(true, maxSwingFactor);
        node.updateReserveAllocation(ComponentAllocation({targetWeight: targetReserveRatio, maxDelta: 0}));
        node.updateComponentAllocation(
            address(vault), ComponentAllocation({targetWeight: 1 ether - targetReserveRatio, maxDelta: 0})
        );
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 investmentAmount = router4626.invest(address(node), address(vault));
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        withdrawalAmount = bound(withdrawalAmount, 1 ether, currentReserve);

        uint256 reserveRatio = _getCurrentReserveRatio();
        assertEq(reserveRatio, targetReserveRatio);

        // invariant 4: returned assets are always less than withdrawal amount
        uint256 sharesToRedeem = node.convertToShares(withdrawalAmount);
        uint256 returnedAssets = _userRedeemsAndClaims(user, sharesToRedeem);
        assertLt(returnedAssets, withdrawalAmount);

        // invariant 5: withdrawal penalty never exceeds the value of the max swing factor
        uint256 tolerance = 10;
        uint256 withdrawalPenalty = withdrawalAmount - returnedAssets - tolerance;
        uint256 maxPenalty = withdrawalAmount * maxSwingFactor / 1e18;
        assertLt(withdrawalPenalty, maxPenalty);
    }

    function test_fuzz_node_swing_price_vault_attack() public {}

    /*//////////////////////////////////////////////////////////////
                        TOTAL ASSET & CACHE
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_node_component_earns_interest() public {}

    function test_fuzz_node_component_loses_values() public {}

    /*//////////////////////////////////////////////////////////////
                        COMPONENT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    // figure out what to test here later

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}
