// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryERC4626Router
 * @notice Integration tests for FuzzERC4626Router handler - Rebalancer story scenarios
 * @dev Tests happy path flows for ERC4626 component management
 */
contract FoundryERC4626Router is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992);
        fuzzSetup();
    }

    // ==============================================================
    // BASIC ROUTER OPERATIONS
    // ==============================================================

    function test_story_invest_single_component() public {
        setActor(rebalancer);
        fuzz_router4626_invest(0, 1e20);
    }

    function test_story_liquidate_single_component() public {
        // First invest
        setActor(rebalancer);
        fuzz_router4626_invest(0, 1e20);

        // Then liquidate
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 5e19);
    }

    // ==============================================================
    // INVEST -> LIQUIDATE CYCLES
    // ==============================================================

    function test_story_invest_liquidate_cycle() public {
        // Invest in vault
        setActor(rebalancer);
        fuzz_router4626_invest(0, 2e20);

        // Partial liquidate
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 1e20);

        // Re-invest
        setActor(rebalancer);
        fuzz_router4626_invest(0, 8e19);

        // Final liquidate
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 5e19);
    }

    function test_story_multi_component_invest() public {
        // Invest in primary vault
        setActor(rebalancer);
        fuzz_router4626_invest(0, 3e20);

        // Invest in secondary vault
        setActor(rebalancer);
        fuzz_router4626_invest(1, 2e20);

        // Invest in tertiary vault
        setActor(rebalancer);
        fuzz_router4626_invest(2, 1e20);
    }

    function test_story_multi_component_rebalance() public {
        // Invest in all vaults
        setActor(rebalancer);
        fuzz_router4626_invest(0, 3e20);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 2e20);

        setActor(rebalancer);
        fuzz_router4626_invest(2, 1e20);

        // Rebalance: liquidate from one, invest in another
        setActor(rebalancer);
        fuzz_router4626_liquidate(2, 5e19);

        setActor(rebalancer);
        fuzz_router4626_invest(0, 4e19);
    }

    // ==============================================================
    // USER REDEMPTION FULFILLMENT
    // ==============================================================

    function test_story_user_deposit_redeem_fulfill() public {
        // User deposits
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        // User requests redeem
        setActor(USERS[0]);
        fuzz_requestRedeem(5e18);

        // Rebalancer fulfills from component
        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(0, 0); // USERS[0], vault index 0
    }

    function test_story_multiple_users_fulfill_from_different_components() public {
        // USER0 deposits and requests redeem
        setActor(USERS[0]);
        fuzz_deposit(15e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(8e18);

        // USER1 deposits and requests redeem
        setActor(USERS[1]);
        fuzz_mint(12e18);

        setActor(USERS[1]);
        fuzz_requestRedeem(6e18);

        // Rebalancer fulfills USER0 from vault 0
        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(0, 0);

        // Rebalancer fulfills USER1 from vault 1
        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(1, 1);

        // Users withdraw
        setActor(USERS[0]);
        fuzz_withdraw(0, 5e18);

        setActor(USERS[1]);
        fuzz_withdraw(1, 4e18);
    }

    // ==============================================================
    // ADMIN OPERATIONS - Whitelist/Blacklist management
    // ==============================================================

    function test_story_owner_whitelist_component_invest() public {
        // Owner whitelists component
        setActor(owner);
        fuzz_router4626_setWhitelist(0, true);

        // Rebalancer invests in whitelisted component
        setActor(rebalancer);
        fuzz_router4626_invest(0, 1e20);
    }

    function test_story_owner_blacklist_prevents_operations() public {
        // Rebalancer invests first
        setActor(rebalancer);
        fuzz_router4626_invest(0, 2e20);

        // Owner blacklists component
        setActor(owner);
        fuzz_router4626_setBlacklist(0, true);

        // Liquidation should still work on blacklisted
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 1e20);
    }

    function test_story_batch_whitelist_multi_invest() public {
        // Owner batch whitelists components
        setActor(owner);
        fuzz_router4626_batchWhitelist(1);

        // Rebalancer invests in multiple
        setActor(rebalancer);
        fuzz_router4626_invest(0, 2e20);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 1e20);
    }

    // ==============================================================
    // TOLERANCE SETTINGS
    // ==============================================================

    function test_story_owner_setTolerance_invest() public {
        // Owner sets slippage tolerance
        setActor(owner);
        fuzz_router4626_setTolerance(50); // 0.5%

        // Rebalancer invests with tolerance
        setActor(rebalancer);
        fuzz_router4626_invest(0, 3e20);

        // Rebalancer liquidates with tolerance
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 1e20);
    }

    // ==============================================================
    // COMPLEX REBALANCING SCENARIOS
    // ==============================================================

    function test_story_full_rebalance_workflow() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_deposit(15e18);

        // Rebalancer starts rebalance
        setActor(rebalancer);
        fuzz_node_startRebalance(1);

        // Rebalancer invests in all components
        setActor(rebalancer);
        fuzz_router4626_invest(0, 3e20);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 2e20);

        setActor(rebalancer);
        fuzz_router4626_invest(2, 1e20);

        // User requests redeem during rebalance
        setActor(USERS[0]);
        fuzz_requestRedeem(10e18);

        // Rebalancer liquidates to fulfill
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 5e19);

        // Rebalancer fulfills request
        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(0, 0);

        // User withdraws
        setActor(USERS[0]);
        fuzz_withdraw(0, 8e18);
    }

    function test_story_strategic_reallocation() public {
        // Initial state: invest in vault 0
        setActor(rebalancer);
        fuzz_router4626_invest(0, 5e20);

        // Strategy change: move to vault 1
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 3e20);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 2e20);

        // Further optimization: some to vault 2
        setActor(rebalancer);
        fuzz_router4626_liquidate(1, 1e20);

        setActor(rebalancer);
        fuzz_router4626_invest(2, 8e19);
    }

    // ==============================================================
    // USER ACTIVITY DURING REBALANCING
    // ==============================================================

    function test_story_user_deposit_during_rebalance() public {
        // Rebalancer investing
        setActor(rebalancer);
        fuzz_router4626_invest(0, 2e20);

        // User deposits while rebalancing
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        // Rebalancer continues
        setActor(rebalancer);
        fuzz_router4626_invest(1, 1e20);

        // Another user deposits
        setActor(USERS[1]);
        fuzz_mint(8e18);

        // Rebalancer liquidates
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 5e19);
    }

    function test_story_sequential_user_redemptions() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_deposit(15e18);

        setActor(USERS[2]);
        fuzz_deposit(10e18);

        // All request redemptions
        setActor(USERS[0]);
        fuzz_requestRedeem(10e18);

        setActor(USERS[1]);
        fuzz_requestRedeem(8e18);

        setActor(USERS[2]);
        fuzz_requestRedeem(5e18);

        // Rebalancer fulfills sequentially from different vaults
        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(0, 0);

        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(1, 1);

        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(2, 0);

        // All users withdraw
        setActor(USERS[0]);
        fuzz_withdraw(0, 7e18);

        setActor(USERS[1]);
        fuzz_withdraw(1, 6e18);

        setActor(USERS[2]);
        fuzz_withdraw(2, 4e18);
    }

    // ==============================================================
    // STRESS TEST SCENARIOS
    // ==============================================================

    function test_story_rapid_invest_liquidate_cycles() public {
        for (uint256 i = 0; i < 5; i++) {
            setActor(rebalancer);
            fuzz_router4626_invest(i % 3, 1e20);

            setActor(rebalancer);
            fuzz_router4626_liquidate(i % 3, 5e19);
        }
    }

    function test_story_all_vaults_full_cycle() public {
        // Invest in all 3 vaults
        setActor(rebalancer);
        fuzz_router4626_invest(0, 3e20);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 2e20);

        setActor(rebalancer);
        fuzz_router4626_invest(2, 1e20);

        // Partial liquidate all
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 1e20);

        setActor(rebalancer);
        fuzz_router4626_liquidate(1, 8e19);

        setActor(rebalancer);
        fuzz_router4626_liquidate(2, 4e19);

        // Re-invest in different proportions
        setActor(rebalancer);
        fuzz_router4626_invest(0, 1e20);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 1e20);

        setActor(rebalancer);
        fuzz_router4626_invest(2, 1e20);
    }

    // ==============================================================
    // COMBINED NODE + ROUTER SCENARIOS
    // ==============================================================

    function test_story_complete_vault_migration() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(30e18);

        // Invest heavily in vault 0
        setActor(rebalancer);
        fuzz_router4626_invest(0, 5e20);

        // Owner decides to migrate to vault 1
        setActor(rebalancer);
        fuzz_router4626_liquidate(0, 5e20);

        setActor(rebalancer);
        fuzz_router4626_invest(1, 4e20);

        // User operations continue normally
        setActor(USERS[1]);
        fuzz_deposit(10e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(15e18);

        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(0, 1);

        setActor(USERS[0]);
        fuzz_withdraw(0, 12e18);
    }
}
