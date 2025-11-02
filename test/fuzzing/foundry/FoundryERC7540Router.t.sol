// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryERC7540Router
 * @notice Integration tests for FuzzERC7540Router handler - Async vault story scenarios
 * @dev Tests happy path flows for ERC7540 async component management
 */
contract FoundryERC7540Router is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992);
        fuzzSetup();
    }

    // ==============================================================
    // BASIC ASYNC OPERATIONS
    // ==============================================================

    function test_story_invest_async_component() public {
        setActor(rebalancer);
        fuzz_router7540_invest(0, 5e20); // Invest in liquidityPool
    }

    function test_story_invest_mintClaimable() public {
        // Invest creates pending deposit request
        setActor(rebalancer);
        fuzz_router7540_invest(0, 3e20);

        // Pool manager settles deposits (simulated in mock)
        // Rebalancer mints claimable shares
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0); // Mint from liquidityPool
    }

    // ==============================================================
    // INVEST -> MINT -> WITHDRAW CYCLES
    // ==============================================================

    function test_story_full_async_invest_cycle() public {
        // Rebalancer requests deposit
        setActor(rebalancer);
        fuzz_router7540_invest(0, 4e20);

        // Settlement happens, mint shares
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Rebalancer requests withdrawal
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 2e18);

        // Execute withdrawal after settlement
        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 1e18);
    }

    function test_story_multi_component_async_operations() public {
        // Invest in primary async pool
        setActor(rebalancer);
        fuzz_router7540_invest(0, 3e20);

        // Invest in secondary async pool
        setActor(rebalancer);
        fuzz_router7540_invest(1, 2e20);

        // Mint from both
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(1);

        // Request withdrawals from both
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 1e18);

        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(1, 5e17);

        // Execute withdrawals
        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 8e17);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(1, 4e17);
    }

    // ==============================================================
    // USER REDEMPTION FULFILLMENT (ASYNC)
    // ==============================================================

    function test_story_user_redeem_fulfill_async() public {
        // User deposits
        setActor(USERS[0]);
        fuzz_deposit(15e18);

        // User requests redeem
        setActor(USERS[0]);
        fuzz_requestRedeem(8e18);

        // Rebalancer fulfills from async component
        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(0, 0); // USERS[0], liquidityPool 0

        // User withdraws
        setActor(USERS[0]);
        fuzz_withdraw(0, 6e18);
    }

    function test_story_multiple_user_redemptions_async() public {
        // Multiple users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_mint(15e18);

        setActor(USERS[2]);
        fuzz_deposit(10e18);

        // All request redemptions
        setActor(USERS[0]);
        fuzz_requestRedeem(10e18);

        setActor(USERS[1]);
        fuzz_requestRedeem(8e18);

        setActor(USERS[2]);
        fuzz_requestRedeem(5e18);

        // Rebalancer fulfills from async pools
        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(0, 0); // USER0, pool 0

        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(1, 1); // USER1, pool 1

        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(2, 0); // USER2, pool 0

        // All withdraw
        setActor(USERS[0]);
        fuzz_withdraw(0, 8e18);

        setActor(USERS[1]);
        fuzz_withdraw(1, 6e18);

        setActor(USERS[2]);
        fuzz_withdraw(2, 4e18);
    }

    // ==============================================================
    // ADMIN OPERATIONS
    // ==============================================================

    function test_story_owner_whitelist_async_component() public {
        // Owner whitelists async component
        setActor(owner);
        fuzz_router7540_setWhitelist(0, true);

        // Rebalancer invests in whitelisted component
        setActor(rebalancer);
        fuzz_router7540_invest(0, 2e20);

        // Mint claimable
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);
    }

    function test_story_owner_blacklist_async_component() public {
        // Rebalancer invests first
        setActor(rebalancer);
        fuzz_router7540_invest(0, 3e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Owner blacklists
        setActor(owner);
        fuzz_router7540_setBlacklist(0, true);

        // Withdrawal should still work
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 1e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 8e17);
    }

    function test_story_batch_whitelist_async() public {
        // Owner batch whitelists
        setActor(owner);
        fuzz_router7540_batchWhitelist(1);

        // Rebalancer invests in multiple
        setActor(rebalancer);
        fuzz_router7540_invest(0, 2e20);

        setActor(rebalancer);
        fuzz_router7540_invest(1, 1e20);

        // Mint from both
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(1);
    }

    function test_story_setTolerance_async() public {
        // Owner sets tolerance
        setActor(owner);
        fuzz_router7540_setTolerance(100); // 1%

        // Rebalancer operations with tolerance
        setActor(rebalancer);
        fuzz_router7540_invest(0, 3e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 1e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 8e17);
    }

    // ==============================================================
    // COMPLEX ASYNC SCENARIOS
    // ==============================================================

    function test_story_overlapping_invest_withdraw_requests() public {
        // First investment cycle
        setActor(rebalancer);
        fuzz_router7540_invest(0, 5e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Request withdrawal while also requesting new deposit
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 2e18);

        setActor(rebalancer);
        fuzz_router7540_invest(0, 2e20); // New invest while withdrawal pending

        // Execute withdrawal
        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 1e18);

        // Mint new shares from second deposit
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);
    }

    function test_story_sequential_batches() public {
        // Batch 1: Invest and mint
        setActor(rebalancer);
        fuzz_router7540_invest(0, 3e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Batch 2: Request withdrawal and execute
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 1e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 8e17);

        // Batch 3: Another invest cycle
        setActor(rebalancer);
        fuzz_router7540_invest(0, 2e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Batch 4: Final withdrawal
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 5e17);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 4e17);
    }

    // ==============================================================
    // COMBINED USER + REBALANCER FLOWS
    // ==============================================================

    function test_story_users_deposit_rebalancer_invests_async() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_deposit(15e18);

        // Rebalancer invests user funds into async vault
        setActor(rebalancer);
        fuzz_router7540_invest(0, 5e20);

        // Settlement occurs
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // User requests redemption
        setActor(USERS[0]);
        fuzz_requestRedeem(10e18);

        // Rebalancer must withdraw from async vault to fulfill
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 3e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 2e18);

        // Fulfill user redemption
        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(0, 0);

        // User withdraws
        setActor(USERS[0]);
        fuzz_withdraw(0, 8e18);
    }

    function test_story_high_activity_async_pool() public {
        // Users continuously deposit
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        setActor(USERS[1]);
        fuzz_deposit(8e18);

        // Rebalancer invests
        setActor(rebalancer);
        fuzz_router7540_invest(0, 3e20);

        // More user deposits
        setActor(USERS[2]);
        fuzz_deposit(6e18);

        // Rebalancer mints
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Another invest
        setActor(rebalancer);
        fuzz_router7540_invest(0, 2e20);

        // User redemptions
        setActor(USERS[0]);
        fuzz_requestRedeem(5e18);

        setActor(USERS[1]);
        fuzz_requestRedeem(4e18);

        // Rebalancer processes
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 2e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 1e18);

        // Fulfill redemptions
        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(0, 0);

        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(1, 0);
    }

    // ==============================================================
    // STRESS SCENARIOS
    // ==============================================================

    function test_story_rapid_async_cycles() public {
        for (uint256 i = 0; i < 3; i++) {
            // Invest
            setActor(rebalancer);
            fuzz_router7540_invest(i % 2, 2e20);

            // Mint
            setActor(rebalancer);
            fuzz_router7540_mintClaimable(i % 2);

            // Request withdrawal
            setActor(rebalancer);
            fuzz_router7540_requestWithdrawal(i % 2, 1e18);

            // Execute withdrawal
            setActor(rebalancer);
            fuzz_router7540_executeWithdrawal(i % 2, 8e17);
        }
    }

    function test_story_both_pools_full_cycle() public {
        // Invest in both pools
        setActor(rebalancer);
        fuzz_router7540_invest(0, 4e20);

        setActor(rebalancer);
        fuzz_router7540_invest(1, 3e20);

        // Mint from both
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(1);

        // Withdraw from both
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 2e18);

        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(1, 1e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 1e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(1, 8e17);

        // Re-invest in different proportions
        setActor(rebalancer);
        fuzz_router7540_invest(0, 1e20);

        setActor(rebalancer);
        fuzz_router7540_invest(1, 2e20);

        // Mint again
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(1);
    }

    // ==============================================================
    // MIGRATION SCENARIOS
    // ==============================================================

    function test_story_migrate_between_async_pools() public {
        // Fully invested in pool 0
        setActor(rebalancer);
        fuzz_router7540_invest(0, 5e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(0);

        // Decide to migrate to pool 1
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 3e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(0, 2e18);

        // Invest in pool 1
        setActor(rebalancer);
        fuzz_router7540_invest(1, 4e20);

        setActor(rebalancer);
        fuzz_router7540_mintClaimable(1);

        // User activity continues
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(5e18);

        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(0, 1);

        setActor(USERS[0]);
        fuzz_withdraw(0, 4e18);
    }
}
