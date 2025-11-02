// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryOneInchRouter
 * @notice Integration tests for FuzzOneInchRouter handler - Swap and whitelist scenarios
 * @dev Tests happy path flows for 1inch integration
 */
contract FoundryOneInchRouter is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992);
        fuzzSetup();
    }

    // ==============================================================
    // BASIC SWAP OPERATIONS
    // ==============================================================

    function test_story_oneInch_swap_basic() public {
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 1e18, 1);
    }

    function test_story_oneInch_swap_larger_amount() public {
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 10e18, 2);
    }

    // ==============================================================
    // WHITELIST MANAGEMENT
    // ==============================================================

    function test_story_owner_whitelist_incentive_then_swap() public {
        // Owner whitelists incentive token
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        // Rebalancer performs swap
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 5e18, 3);
    }

    function test_story_owner_whitelist_executor_then_swap() public {
        // Owner whitelists executor
        setActor(owner);
        fuzz_oneInch_setExecutorWhitelist(0, true);

        // Rebalancer performs swap
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 8e18, 4);
    }

    function test_story_whitelist_both_then_swap() public {
        // Owner whitelists both incentive and executor
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(1, true);

        setActor(owner);
        fuzz_oneInch_setExecutorWhitelist(1, true);

        // Rebalancer performs swap
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 12e18, 5);
    }

    // ==============================================================
    // MULTIPLE SWAP SCENARIOS
    // ==============================================================

    function test_story_sequential_swaps() public {
        // Whitelist first
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        // Multiple swaps
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 2e18, 6);

        setActor(rebalancer);
        fuzz_oneInch_swap(0, 3e18, 7);

        setActor(rebalancer);
        fuzz_oneInch_swap(0, 4e18, 8);
    }

    function test_story_swap_different_incentives() public {
        // Whitelist multiple incentives
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(1, true);

        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(2, true);

        // Swap different incentives
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 5e18, 9);

        setActor(rebalancer);
        fuzz_oneInch_swap(1, 6e18, 10);

        setActor(rebalancer);
        fuzz_oneInch_swap(2, 7e18, 11);
    }

    // ==============================================================
    // COMBINED SCENARIOS WITH USER ACTIVITY
    // ==============================================================

    function test_story_users_deposit_earn_incentives_swap() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_deposit(15e18);

        // Rebalancer invests
        setActor(rebalancer);
        fuzz_router4626_invest(0, 3e20);

        // Time passes, incentives accrue
        vm.warp(block.timestamp + 30 days);

        // Owner whitelists incentive for swap
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        // Rebalancer swaps incentives to underlying
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 10e18, 12);
    }

    function test_story_swap_reinvest_cycle() public {
        // Initial deposit
        setActor(USERS[0]);
        fuzz_deposit(30e18);

        // Invest
        setActor(rebalancer);
        fuzz_router4626_invest(0, 4e20);

        // Time passes
        vm.warp(block.timestamp + 14 days);

        // Whitelist and swap incentives
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        setActor(rebalancer);
        fuzz_oneInch_swap(0, 8e18, 13);

        // Reinvest swapped assets
        setActor(rebalancer);
        fuzz_router4626_invest(1, 2e20);
    }

    // ==============================================================
    // REWARDS + SWAPS SCENARIOS
    // ==============================================================

    function test_story_claim_rewards_swap_to_underlying() public {
        // Users provide liquidity
        setActor(USERS[0]);
        fuzz_deposit(25e18);

        // Time passes
        vm.warp(block.timestamp + 21 days);

        // Claim rewards
        setActor(rebalancer);
        fuzz_fluid_claim(5e17, 1, 1);

        setActor(rebalancer);
        fuzz_incentra_claim(6e17, 2, 2);

        // Whitelist reward tokens
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        // Swap rewards to underlying
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 1e18, 14);
    }

    function test_story_full_incentive_management_cycle() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(40e18);

        setActor(USERS[1]);
        fuzz_deposit(30e18);

        // Invest in components
        setActor(rebalancer);
        fuzz_router4626_invest(0, 5e20);

        setActor(rebalancer);
        fuzz_router7540_invest(0, 3e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Time passes - incentives accrue
        vm.warp(block.timestamp + 30 days);

        // Claim all protocol rewards
        setActor(rebalancer);
        fuzz_fluid_claim(8e17, 3, 3);

        setActor(rebalancer);
        fuzz_incentra_claim(7e17, 4, 4);

        setActor(rebalancer);
        fuzz_merkl_claim(9e17, 5);

        // Whitelist all reward tokens
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(1, true);

        // Swap all to underlying
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 15e18, 15);

        setActor(rebalancer);
        fuzz_oneInch_swap(1, 10e18, 16);

        // Reinvest swapped assets
        setActor(rebalancer);
        fuzz_router4626_invest(0, 2e20);
    }

    // ==============================================================
    // EXECUTOR MANAGEMENT SCENARIOS
    // ==============================================================

    function test_story_change_executor_mid_operations() public {
        // Whitelist executor 0
        setActor(owner);
        fuzz_oneInch_setExecutorWhitelist(0, true);

        // Perform swaps
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 5e18, 17);

        // Change to executor 1
        setActor(owner);
        fuzz_oneInch_setExecutorWhitelist(0, false);

        setActor(owner);
        fuzz_oneInch_setExecutorWhitelist(1, true);

        // Continue swaps with new executor
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 6e18, 18);
    }

    // ==============================================================
    // STRESS SCENARIOS
    // ==============================================================

    function test_story_high_frequency_swaps() public {
        // Setup whitelists
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        setActor(owner);
        fuzz_oneInch_setExecutorWhitelist(0, true);

        // Rapid swaps
        for (uint256 i = 0; i < 10; i++) {
            setActor(rebalancer);
            fuzz_oneInch_swap(0, (i + 1) * 1e18, i);
        }
    }

    function test_story_batch_whitelist_batch_swap() public {
        // Batch whitelist incentives
        for (uint256 i = 0; i < 3; i++) {
            setActor(owner);
            fuzz_oneInch_setIncentiveWhitelist(i, true);
        }

        // Batch whitelist executors
        for (uint256 i = 0; i < 2; i++) {
            setActor(owner);
            fuzz_oneInch_setExecutorWhitelist(i, true);
        }

        // Batch swaps
        for (uint256 i = 0; i < 5; i++) {
            setActor(rebalancer);
            fuzz_oneInch_swap(i % 3, (i + 2) * 1e18, i + 100);
        }
    }

    // ==============================================================
    // COMPLEX INTEGRATED SCENARIOS
    // ==============================================================

    function test_story_complete_yield_optimization_with_swaps() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(50e18);

        setActor(USERS[1]);
        fuzz_deposit(40e18);

        // Initial investment
        setActor(rebalancer);
        fuzz_router4626_invest(0, 6e20);

        // Week 1: Claim and swap
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 6, 6);

        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(0, true);

        setActor(rebalancer);
        fuzz_oneInch_swap(0, 1e18, 19);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 1e20);

        // Week 2: More rewards and swaps
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_incentra_claim(1e18, 7, 7);

        setActor(rebalancer);
        fuzz_oneInch_swap(0, 1e18, 20);

        setActor(rebalancer);
        fuzz_router4626_invest(2, 1e20);

        // Week 3: User redemption
        setActor(USERS[0]);
        fuzz_requestRedeem(25e18);

        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 2e20);

        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        setActor(USERS[0]);
        fuzz_withdraw(0, 20e18);

        // Final swap optimization
        setActor(rebalancer);
        fuzz_merkl_claim(8e17, 8);

        setActor(rebalancer);
        fuzz_oneInch_swap(0, 8e17, 21);
    }
}
