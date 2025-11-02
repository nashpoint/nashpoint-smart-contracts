// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryRewardsRouters
 * @notice Integration tests for Fluid, Incentra, and Merkl reward router handlers
 * @dev Tests happy path flows for claiming rewards from external protocols
 */
contract FoundryRewardsRouters is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992);
        fuzzSetup();
    }

    // ==============================================================
    // FLUID REWARDS
    // ==============================================================

    function test_story_fluid_claim_basic() public {
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 1, 2);
    }

    function test_story_fluid_claim_multiple_cycles() public {
        // Claim for cycle 1
        setActor(rebalancer);
        fuzz_fluid_claim(5e17, 1, 1);

        // Claim for cycle 2
        setActor(rebalancer);
        fuzz_fluid_claim(8e17, 2, 2);

        // Claim for cycle 3
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 3, 3);
    }

    function test_story_fluid_claim_after_user_deposits() public {
        // Users deposit (providing liquidity to protocol)
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_deposit(15e18);

        // Time passes, rewards accrue
        vm.warp(block.timestamp + 7 days);

        // Rebalancer claims Fluid rewards
        setActor(rebalancer);
        fuzz_fluid_claim(2e18, 4, 4);
    }

    // ==============================================================
    // INCENTRA REWARDS
    // ==============================================================

    function test_story_incentra_claim_basic() public {
        setActor(rebalancer);
        fuzz_incentra_claim(1e18, 1, 2);
    }

    function test_story_incentra_claim_multiple_campaigns() public {
        // Claim from campaign 1
        setActor(rebalancer);
        fuzz_incentra_claim(5e17, 1, 1);

        // Claim from campaign 2
        setActor(rebalancer);
        fuzz_incentra_claim(8e17, 2, 2);

        // Claim from campaign 3
        setActor(rebalancer);
        fuzz_incentra_claim(1e18, 3, 3);
    }

    function test_story_incentra_claim_after_rebalance() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(15e18);

        // Rebalancer rebalances
        setActor(rebalancer);
        fuzz_node_startRebalance(1);

        // Rewards available after rebalance
        setActor(rebalancer);
        fuzz_incentra_claim(1e18, 5, 5);
    }

    // ==============================================================
    // MERKL REWARDS
    // ==============================================================

    function test_story_merkl_claim_basic() public {
        setActor(rebalancer);
        fuzz_merkl_claim(1e18, 1);
    }

    function test_story_merkl_claim_multiple_epochs() public {
        // Claim epoch 1
        setActor(rebalancer);
        fuzz_merkl_claim(5e17, 1);

        // Claim epoch 2
        setActor(rebalancer);
        fuzz_merkl_claim(8e17, 2);

        // Claim epoch 3
        setActor(rebalancer);
        fuzz_merkl_claim(1e18, 3);
    }

    function test_story_merkl_claim_with_user_activity() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        setActor(USERS[1]);
        fuzz_deposit(8e18);

        // Time passes
        vm.warp(block.timestamp + 30 days);

        // Rebalancer claims Merkl rewards
        setActor(rebalancer);
        fuzz_merkl_claim(2e18, 4);
    }

    // ==============================================================
    // COMBINED REWARD CLAIMING SCENARIOS
    // ==============================================================

    function test_story_claim_all_rewards_same_cycle() public {
        // Users provide liquidity
        setActor(USERS[0]);
        fuzz_deposit(25e18);

        setActor(USERS[1]);
        fuzz_deposit(20e18);

        // Time passes for rewards to accrue
        vm.warp(block.timestamp + 14 days);

        // Rebalancer claims from all protocols
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 5, 5);

        setActor(rebalancer);
        fuzz_incentra_claim(8e17, 6, 6);

        setActor(rebalancer);
        fuzz_merkl_claim(1e18, 7);
    }

    function test_story_periodic_reward_harvesting() public {
        // Initial deposits
        setActor(USERS[0]);
        fuzz_deposit(30e18);

        // Week 1 harvest
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_fluid_claim(5e17, 1, 1);

        // Week 2 harvest
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_incentra_claim(6e17, 2, 2);

        // Week 3 harvest
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_merkl_claim(7e17, 3);

        // Week 4 harvest all
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_fluid_claim(8e17, 4, 4);

        setActor(rebalancer);
        fuzz_incentra_claim(9e17, 5, 5);

        setActor(rebalancer);
        fuzz_merkl_claim(1e18, 6);
    }

    // ==============================================================
    // REWARDS + REBALANCING SCENARIOS
    // ==============================================================

    function test_story_claim_rewards_then_rebalance() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_deposit(15e18);

        // Time passes
        vm.warp(block.timestamp + 30 days);

        // Claim rewards from all sources
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 7, 7);

        setActor(rebalancer);
        fuzz_incentra_claim(8e17, 8, 8);

        setActor(rebalancer);
        fuzz_merkl_claim(1e18, 9);

        // Use rewards for rebalancing
        setActor(rebalancer);
        fuzz_node_startRebalance(2);

        // Invest rewards
        setActor(rebalancer);
        fuzz_router4626_invest(0, 1e20);
    }

    function test_story_rewards_during_redemptions() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(30e18);

        setActor(USERS[1]);
        fuzz_deposit(25e18);

        // Time passes
        vm.warp(block.timestamp + 21 days);

        // User requests redemption
        setActor(USERS[0]);
        fuzz_requestRedeem(15e18);

        // Rebalancer claims rewards before fulfilling
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 10, 10);

        setActor(rebalancer);
        fuzz_incentra_claim(9e17, 11, 11);

        // Fulfill redemption
        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        // User withdraws
        setActor(USERS[0]);
        fuzz_withdraw(0, 12e18);
    }

    // ==============================================================
    // MULTI-PROTOCOL REWARD OPTIMIZATION
    // ==============================================================

    function test_story_strategic_reward_claiming() public {
        // Initial liquidity
        setActor(USERS[0]);
        fuzz_deposit(40e18);

        // Month 1: Focus on Fluid
        vm.warp(block.timestamp + 10 days);
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 12, 12);

        setActor(rebalancer);
        fuzz_fluid_claim(8e17, 13, 13);

        // Month 2: Focus on Incentra
        vm.warp(block.timestamp + 20 days);
        setActor(rebalancer);
        fuzz_incentra_claim(1e18, 14, 14);

        setActor(rebalancer);
        fuzz_incentra_claim(9e17, 15, 15);

        // Month 3: Focus on Merkl
        vm.warp(block.timestamp + 30 days);
        setActor(rebalancer);
        fuzz_merkl_claim(1e18, 16);

        setActor(rebalancer);
        fuzz_merkl_claim(1e18, 17);
    }

    // ==============================================================
    // COMPLEX SCENARIOS
    // ==============================================================

    function test_story_full_protocol_lifecycle_with_rewards() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_deposit(15e18);

        // Rebalancer invests
        setActor(rebalancer);
        fuzz_router4626_invest(0, 3e20);

        // Time passes, rewards accrue
        vm.warp(block.timestamp + 7 days);

        // Claim Fluid rewards
        setActor(rebalancer);
        fuzz_fluid_claim(5e17, 18, 18);

        // More user activity
        setActor(USERS[2]);
        fuzz_deposit(10e18);

        // Time passes more
        vm.warp(block.timestamp + 7 days);

        // Claim Incentra rewards
        setActor(rebalancer);
        fuzz_incentra_claim(6e17, 19, 19);

        // Rebalance with rewards
        setActor(rebalancer);
        fuzz_node_startRebalance(3);

        // Time passes
        vm.warp(block.timestamp + 7 days);

        // Claim Merkl rewards
        setActor(rebalancer);
        fuzz_merkl_claim(7e17, 20);

        // User redemptions
        setActor(USERS[0]);
        fuzz_requestRedeem(10e18);

        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        setActor(USERS[0]);
        fuzz_withdraw(0, 8e18);

        // Final reward claim
        setActor(rebalancer);
        fuzz_fluid_claim(8e17, 21, 21);
    }

    function test_story_rewards_compound_strategy() public {
        // Initial deposit
        setActor(USERS[0]);
        fuzz_deposit(50e18);

        // Invest initial capital
        setActor(rebalancer);
        fuzz_router4626_invest(0, 5e20);

        // Week 1: Claim and reinvest
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_fluid_claim(5e17, 22, 22);

        setActor(rebalancer);
        fuzz_router4626_invest(0, 1e20);

        // Week 2: Claim and reinvest
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_incentra_claim(6e17, 23, 23);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 1e20);

        // Week 3: Claim and reinvest
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_merkl_claim(7e17, 24);

        setActor(rebalancer);
        fuzz_router4626_invest(2, 1e20);

        // Week 4: Final compound
        vm.warp(block.timestamp + 7 days);
        setActor(rebalancer);
        fuzz_fluid_claim(8e17, 25, 25);

        setActor(rebalancer);
        fuzz_incentra_claim(8e17, 26, 26);

        setActor(rebalancer);
        fuzz_merkl_claim(8e17, 27);
    }
}
