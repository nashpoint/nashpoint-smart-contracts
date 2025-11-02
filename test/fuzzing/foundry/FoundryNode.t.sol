// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryNode
 * @notice Integration tests for FuzzNode handler - User story scenarios
 * @dev Tests happy path flows to ensure handlers work without errors
 */
contract FoundryNode is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992); // echidna starting time
        fuzzSetup();
    }

    // ==============================================================
    // BASIC OPERATIONS - Single user actions
    // ==============================================================

    function test_story_deposit() public {
        setActor(USERS[0]);
        fuzz_deposit(1e18);
    }

    function test_story_mint() public {
        setActor(USERS[1]);
        fuzz_mint(5e17);
    }

    function test_story_deposit_and_transfer() public {
        setActor(USERS[0]);
        fuzz_deposit(2e18);

        setActor(USERS[0]);
        fuzz_node_transfer(1, 1e18); // Transfer to USERS[1]
    }

    function test_story_mint_and_approve() public {
        setActor(USERS[1]);
        fuzz_mint(3e18);

        setActor(USERS[1]);
        fuzz_node_approve(2, 1e18); // Approve USERS[2]
    }

    // ==============================================================
    // REDEMPTION FLOWS - Full lifecycle tests
    // ==============================================================

    function test_story_deposit_request_fulfill_withdraw() public {
        // User deposits
        setActor(USERS[0]);
        fuzz_deposit(5e18);

        // User requests redeem
        setActor(USERS[0]);
        fuzz_requestRedeem(3e18);

        // Rebalancer fulfills
        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        // User withdraws
        setActor(USERS[0]);
        fuzz_withdraw(0, 2e18);
    }

    function test_story_mint_request_fulfill_withdraw() public {
        // User mints shares
        setActor(USERS[1]);
        fuzz_mint(4e18);

        // User requests redeem
        setActor(USERS[1]);
        fuzz_requestRedeem(2e18);

        // Rebalancer fulfills
        setActor(rebalancer);
        fuzz_fulfillRedeem(1);

        // User withdraws
        setActor(USERS[1]);
        fuzz_withdraw(1, 1e18);
    }

    function test_story_partial_redemption_multiple_users() public {
        // USER0 deposits
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        // USER1 mints
        setActor(USERS[1]);
        fuzz_mint(8e18);

        // USER0 requests partial redeem
        setActor(USERS[0]);
        fuzz_requestRedeem(5e18);

        // Rebalancer fulfills USER0
        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        // USER1 also requests redeem
        setActor(USERS[1]);
        fuzz_requestRedeem(4e18);

        // Rebalancer fulfills USER1
        setActor(rebalancer);
        fuzz_fulfillRedeem(1);

        // Both users withdraw
        setActor(USERS[0]);
        fuzz_withdraw(0, 3e18);

        setActor(USERS[1]);
        fuzz_withdraw(1, 2e18);
    }

    // ==============================================================
    // TRANSFER SCENARIOS - Share movement between users
    // ==============================================================

    function test_story_deposit_transfer_redeem_new_owner() public {
        // USER0 deposits
        setActor(USERS[0]);
        fuzz_deposit(6e18);

        // USER0 transfers shares to USER2
        setActor(USERS[0]);
        fuzz_node_transfer(2, 3e18);

        // USER2 requests redeem of received shares
        setActor(USERS[2]);
        fuzz_requestRedeem(2e18);

        // Rebalancer fulfills
        setActor(rebalancer);
        fuzz_fulfillRedeem(2);

        // USER2 withdraws
        setActor(USERS[2]);
        fuzz_withdraw(2, 1e18);
    }

    function test_story_approve_transferFrom_lifecycle() public {
        // USER1 mints shares
        setActor(USERS[1]);
        fuzz_mint(5e18);

        // USER1 approves USER3
        setActor(USERS[1]);
        fuzz_node_approve(3, 4e18);

        // USER3 transfers from USER1 using approval
        setActor(USERS[3]);
        fuzz_node_transferFrom(1, 3e18);

        // USER3 requests redeem
        setActor(USERS[3]);
        fuzz_requestRedeem(2e18);

        // Rebalancer fulfills
        setActor(rebalancer);
        fuzz_fulfillRedeem(3);

        // USER3 withdraws
        setActor(USERS[3]);
        fuzz_withdraw(3, 1e18);
    }

    // ==============================================================
    // OPERATOR SCENARIOS - ERC7575 operator functionality
    // ==============================================================

    function test_story_setOperator_and_operate() public {
        // USER0 deposits
        setActor(USERS[0]);
        fuzz_deposit(4e18);

        // USER0 sets USER4 as operator
        setActor(USERS[0]);
        fuzz_setOperator(4, true);

        // Operator (USER4) can now act on behalf of USER0
        setActor(USERS[4]);
        fuzz_requestRedeem(2e18); // Operating on USER0's shares
    }

    // ==============================================================
    // REBALANCING SCENARIOS
    // ==============================================================

    function test_story_deposit_startRebalance() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        setActor(USERS[1]);
        fuzz_mint(8e18);

        // Rebalancer starts rebalance
        setActor(rebalancer);
        fuzz_node_startRebalance(1);
    }

    function test_story_full_rebalance_with_redemptions() public {
        // Multiple users deposit
        setActor(USERS[0]);
        fuzz_deposit(15e18);

        setActor(USERS[1]);
        fuzz_deposit(12e18);

        // Rebalancer starts rebalance
        setActor(rebalancer);
        fuzz_node_startRebalance(2);

        // Users request redemptions during rebalance
        setActor(USERS[0]);
        fuzz_requestRedeem(7e18);

        // Rebalancer fulfills after rebalance
        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        // User withdraws
        setActor(USERS[0]);
        fuzz_withdraw(0, 5e18);
    }

    // ==============================================================
    // ADMIN OPERATIONS - Owner actions
    // ==============================================================

    function test_story_owner_setMaxDeposit_user_deposits() public {
        // Owner sets max deposit
        setActor(owner);
        fuzz_node_setMaxDepositSize(20e18);

        // User deposits within new limit
        setActor(USERS[0]);
        fuzz_deposit(15e18);
    }

    function test_story_owner_setManagementFee_payFees() public {
        // Owner sets management fee
        setActor(owner);
        fuzz_node_setAnnualManagementFee(100); // 1%

        // User deposits
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        // Time passes and fees accrue
        vm.warp(block.timestamp + 365 days);

        // Owner pays management fees
        setActor(owner);
        fuzz_node_payManagementFees(1);
    }

    function test_story_owner_updateComponentAllocation() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        // Owner updates component allocation
        setActor(owner);
        fuzz_node_updateComponentAllocation(0);

        // Rebalancer rebalances to new allocation
        setActor(rebalancer);
        fuzz_node_startRebalance(3);
    }

    // ==============================================================
    // COMPLEX MULTI-USER SCENARIOS
    // ==============================================================

    function test_story_three_users_deposit_transfer_chain() public {
        // USER0 deposits
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        // USER0 transfers to USER1
        setActor(USERS[0]);
        fuzz_node_transfer(1, 5e18);

        // USER1 deposits more
        setActor(USERS[1]);
        fuzz_deposit(5e18);

        // USER1 transfers to USER2
        setActor(USERS[1]);
        fuzz_node_transfer(2, 6e18);

        // USER2 requests redeem
        setActor(USERS[2]);
        fuzz_requestRedeem(4e18);

        // Rebalancer fulfills
        setActor(rebalancer);
        fuzz_fulfillRedeem(2);

        // USER2 withdraws
        setActor(USERS[2]);
        fuzz_withdraw(2, 3e18);
    }

    function test_story_liquidity_pool_full_cycle() public {
        // Multiple users add liquidity
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_mint(15e18);

        setActor(USERS[2]);
        fuzz_deposit(10e18);

        // Rebalancer rebalances
        setActor(rebalancer);
        fuzz_node_startRebalance(4);

        // One user redeems
        setActor(USERS[1]);
        fuzz_requestRedeem(8e18);

        setActor(rebalancer);
        fuzz_fulfillRedeem(1);

        setActor(USERS[1]);
        fuzz_withdraw(1, 7e18);

        // Another user deposits during ongoing operations
        setActor(USERS[3]);
        fuzz_deposit(12e18);
    }

    // ==============================================================
    // STRESS SCENARIOS - Edge cases
    // ==============================================================

    function test_story_rapid_deposit_withdraw_cycles() public {
        // USER0 rapid deposits and withdrawals
        setActor(USERS[0]);
        fuzz_deposit(5e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(2e18);

        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        setActor(USERS[0]);
        fuzz_withdraw(0, 1e18);

        // Immediately deposit again
        setActor(USERS[0]);
        fuzz_deposit(3e18);

        // Request again
        setActor(USERS[0]);
        fuzz_requestRedeem(2e18);

        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        setActor(USERS[0]);
        fuzz_withdraw(0, 1e18);
    }

    function test_story_max_users_participation() public {
        // All 6 users participate
        for (uint256 i = 0; i < USERS.length; i++) {
            setActor(USERS[i]);
            fuzz_deposit((i + 1) * 1e18);
        }

        // Rebalancer starts rebalance
        setActor(rebalancer);
        fuzz_node_startRebalance(5);

        // Each user requests different amounts
        for (uint256 i = 0; i < USERS.length / 2; i++) {
            setActor(USERS[i]);
            fuzz_requestRedeem((i + 1) * 5e17);
        }

        // Rebalancer fulfills all
        for (uint256 i = 0; i < USERS.length / 2; i++) {
            setActor(rebalancer);
            fuzz_fulfillRedeem(i);
        }
    }

    // ==============================================================
    // POLICY INTEGRATION SCENARIOS
    // ==============================================================

    function test_story_owner_addPolicies_submitData() public {
        // Owner adds policies
        setActor(owner);
        fuzz_node_addPolicies(1);

        // User deposits
        setActor(USERS[0]);
        fuzz_deposit(5e18);

        // Submit policy data
        setActor(owner);
        fuzz_node_submitPolicyData(1);
    }

    function test_story_policies_add_remove_lifecycle() public {
        // Owner adds policies
        setActor(owner);
        fuzz_node_addPolicies(2);

        // Users interact
        setActor(USERS[0]);
        fuzz_deposit(8e18);

        setActor(USERS[1]);
        fuzz_mint(6e18);

        // Owner removes policies
        setActor(owner);
        fuzz_node_removePolicies(2);
    }

    // ==============================================================
    // RESCUE & EMERGENCY SCENARIOS
    // ==============================================================

    function test_story_rescue_tokens() public {
        // Some tokens end up in node (donation or error)
        setActor(USERS[0]);
        fuzz_donate(0, 0, 2e18); // Donate to node

        // Owner rescues tokens
        setActor(owner);
        fuzz_node_rescueTokens(1e18);
    }

    function test_story_swing_pricing_lifecycle() public {
        // Owner enables swing pricing
        setActor(owner);
        fuzz_node_enableSwingPricing(5, true);

        // Users deposit under swing pricing
        setActor(USERS[0]);
        fuzz_deposit(10e18);

        setActor(USERS[1]);
        fuzz_mint(8e18);

        // Owner disables swing pricing
        setActor(owner);
        fuzz_node_enableSwingPricing(5, false);

        // Users continue operations
        setActor(USERS[2]);
        fuzz_deposit(5e18);
    }
}
