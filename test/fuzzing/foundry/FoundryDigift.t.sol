// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryDigift
 * @notice Integration tests for Digift Adapter, Factory, and Event Verifier handlers
 * @dev Tests happy path flows for Digift ecosystem integration
 */
contract FoundryDigift is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992);
        fuzzSetup();
    }

    // ==============================================================
    // FACTORY OPERATIONS
    // ==============================================================

    function test_story_factory_deploy_adapter() public {
        setActor(owner);
        fuzz_digiftFactory_deploy(1);
    }

    function test_story_factory_upgrade() public {
        setActor(owner);
        fuzz_digiftFactory_upgrade(2);
    }

    function test_story_factory_transferOwnership() public {
        setActor(owner);
        fuzz_digiftFactory_transferOwnership(1);
    }

    // ==============================================================
    // EVENT VERIFIER OPERATIONS
    // ==============================================================

    function test_story_verifier_setWhitelist() public {
        setActor(owner);
        fuzz_digiftVerifier_setWhitelist(0, true);
    }

    function test_story_verifier_setBlockHash() public {
        setActor(owner);
        fuzz_digiftVerifier_setBlockHash(1);
    }

    function test_story_verifier_verify_subscribe() public {
        fuzz_digiftVerifier_verifySettlement(1, true);
    }

    function test_story_verifier_verify_redeem() public {
        fuzz_digiftVerifier_verifySettlement(2, false);
    }

    // ==============================================================
    // BASIC ADAPTER OPERATIONS
    // ==============================================================

    function test_story_adapter_requestDeposit() public {
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(1e18);
    }

    function test_story_adapter_requestRedeem() public {
        setActor(USERS[0]);
        fuzz_digift_requestRedeem(5e17);
    }

    // ==============================================================
    // DEPOSIT LIFECYCLE
    // ==============================================================

    function test_story_adapter_full_deposit_cycle() public {
        // User requests deposit
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(10e18);

        // Manager forwards request
        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        // Offchain settlement happens
        // Manager settles deposit
        setActor(rebalancer);
        fuzz_digift_settleDeposit(9e18, 10e18);

        // User mints shares
        setActor(USERS[0]);
        fuzz_digift_mint(9e18);
    }

    function test_story_adapter_multiple_users_deposit() public {
        // USER0 requests deposit
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(15e18);

        // USER1 requests deposit
        setActor(USERS[1]);
        fuzz_digift_requestDeposit(12e18);

        // Manager forwards both
        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        // Settle USER0
        setActor(rebalancer);
        fuzz_digift_settleDeposit(14e18, 15e18);

        // Settle USER1
        setActor(rebalancer);
        fuzz_digift_settleDeposit(11e18, 12e18);

        // Both mint
        setActor(USERS[0]);
        fuzz_digift_mint(14e18);

        setActor(USERS[1]);
        fuzz_digift_mint(11e18);
    }

    // ==============================================================
    // REDEMPTION LIFECYCLE
    // ==============================================================

    function test_story_adapter_full_redeem_cycle() public {
        // First deposit to get shares
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(20e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(19e18, 20e18);

        setActor(USERS[0]);
        fuzz_digift_mint(19e18);

        // Now redeem
        setActor(USERS[0]);
        fuzz_digift_requestRedeem(10e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(false, true);

        setActor(rebalancer);
        fuzz_digift_settleRedeem(10e18, 9e18);

        setActor(USERS[0]);
        fuzz_digift_withdraw(9e18);
    }

    function test_story_adapter_deposit_redeem_multiple_cycles() public {
        // Cycle 1: Deposit
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(25e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(24e18, 25e18);

        setActor(USERS[0]);
        fuzz_digift_mint(24e18);

        // Cycle 2: Partial redeem
        setActor(USERS[0]);
        fuzz_digift_requestRedeem(12e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(false, true);

        setActor(rebalancer);
        fuzz_digift_settleRedeem(12e18, 11e18);

        setActor(USERS[0]);
        fuzz_digift_withdraw(11e18);

        // Cycle 3: Deposit again
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(15e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(14e18, 15e18);

        setActor(USERS[0]);
        fuzz_digift_mint(14e18);
    }

    // ==============================================================
    // TRANSFER SCENARIOS
    // ==============================================================

    function test_story_adapter_deposit_transfer_redeem() public {
        // USER0 deposits
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(20e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(19e18, 20e18);

        setActor(USERS[0]);
        fuzz_digift_mint(19e18);

        // USER0 transfers shares to USER1
        setActor(USERS[0]);
        fuzz_digift_transfer(1, 10e18);

        // USER1 redeems received shares
        setActor(USERS[1]);
        fuzz_digift_requestRedeem(9e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(false, true);

        setActor(rebalancer);
        fuzz_digift_settleRedeem(9e18, 8e18);

        setActor(USERS[1]);
        fuzz_digift_withdraw(8e18);
    }

    function test_story_adapter_approve_transferFrom() public {
        // USER0 deposits
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(15e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(14e18, 15e18);

        setActor(USERS[0]);
        fuzz_digift_mint(14e18);

        // USER0 approves USER2
        setActor(USERS[0]);
        fuzz_digift_approve(2, 12e18);

        // USER2 transfers from USER0
        setActor(USERS[2]);
        fuzz_digift_transferFrom(3, 10e18);
    }

    // ==============================================================
    // ADMIN CONFIGURATION
    // ==============================================================

    function test_story_manager_configuration() public {
        // Owner sets manager
        setActor(owner);
        fuzz_digift_setManager(1, true);

        // New manager can forward requests
        setActor(USERS[1]);
        fuzz_digift_requestDeposit(10e18);

        setActor(USERS[1]);
        fuzz_digift_forwardRequests(true, false);
    }

    function test_story_node_configuration() public {
        // Owner sets node
        setActor(owner);
        fuzz_digift_setNode(0, true);

        // Adapter can be added to node
        setActor(owner);
        fuzz_node_addComponent(6); // Digift adapter
    }

    function test_story_parameter_configuration() public {
        // Owner sets min deposit
        setActor(owner);
        fuzz_digift_setMinDeposit(2000e6);

        // Owner sets min redeem
        setActor(owner);
        fuzz_digift_setMinRedeem(20e18);

        // Owner sets price deviation
        setActor(owner);
        fuzz_digift_setPriceDeviation(5e15); // 0.5%

        // User operations with new parameters
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(2500e6);
    }

    // ==============================================================
    // COMPLEX SCENARIOS
    // ==============================================================

    function test_story_multiple_users_concurrent_operations() public {
        // USER0 deposits
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(20e18);

        // USER1 also deposits
        setActor(USERS[1]);
        fuzz_digift_requestDeposit(15e18);

        // USER2 deposits
        setActor(USERS[2]);
        fuzz_digift_requestDeposit(10e18);

        // Manager forwards all
        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        // Settle all deposits
        setActor(rebalancer);
        fuzz_digift_settleDeposit(19e18, 20e18);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(14e18, 15e18);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(9e18, 10e18);

        // All mint
        setActor(USERS[0]);
        fuzz_digift_mint(19e18);

        setActor(USERS[1]);
        fuzz_digift_mint(14e18);

        setActor(USERS[2]);
        fuzz_digift_mint(9e18);

        // USER0 redeems
        setActor(USERS[0]);
        fuzz_digift_requestRedeem(10e18);

        // USER1 also redeems
        setActor(USERS[1]);
        fuzz_digift_requestRedeem(7e18);

        // Forward redemptions
        setActor(rebalancer);
        fuzz_digift_forwardRequests(false, true);

        // Settle redemptions
        setActor(rebalancer);
        fuzz_digift_settleRedeem(10e18, 9e18);

        setActor(rebalancer);
        fuzz_digift_settleRedeem(7e18, 6e18);

        // Withdraw
        setActor(USERS[0]);
        fuzz_digift_withdraw(9e18);

        setActor(USERS[1]);
        fuzz_digift_withdraw(6e18);
    }

    function test_story_integrated_with_node_operations() public {
        // Users deposit into node
        setActor(USERS[0]);
        fuzz_deposit(30e18);

        // Node invests in Digift adapter via router7540
        setActor(rebalancer);
        fuzz_router7540_invest(2, 2e20); // index 2 is digiftAdapter

        // Mint from digift adapter
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(2);

        // User requests redemption from node
        setActor(USERS[0]);
        fuzz_requestRedeem(15e18);

        // Rebalancer withdraws from Digift to fulfill
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(2, 1e18);

        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(2, 8e17);

        // Fulfill node redemption
        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(0, 2);

        // User withdraws
        setActor(USERS[0]);
        fuzz_withdraw(0, 12e18);
    }

    // ==============================================================
    // VERIFIER INTEGRATION SCENARIOS
    // ==============================================================

    function test_story_verifier_whitelist_then_settle() public {
        // Owner whitelists adapter
        setActor(owner);
        fuzz_digiftVerifier_setWhitelist(0, true);

        // User deposits
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(12e18);

        // Forward
        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        // Verify and settle
        fuzz_digiftVerifier_verifySettlement(1, true);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(11e18, 12e18);

        setActor(USERS[0]);
        fuzz_digift_mint(11e18);
    }

    function test_story_full_lifecycle_with_verifier() public {
        // Setup verifier
        setActor(owner);
        fuzz_digiftVerifier_setWhitelist(0, true);

        setActor(owner);
        fuzz_digiftVerifier_setBlockHash(1);

        // USER deposits
        setActor(USERS[0]);
        fuzz_digift_requestDeposit(25e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(true, false);

        // Verify subscribe event
        fuzz_digiftVerifier_verifySettlement(2, true);

        setActor(rebalancer);
        fuzz_digift_settleDeposit(24e18, 25e18);

        setActor(USERS[0]);
        fuzz_digift_mint(24e18);

        // USER redeems
        setActor(USERS[0]);
        fuzz_digift_requestRedeem(15e18);

        setActor(rebalancer);
        fuzz_digift_forwardRequests(false, true);

        // Verify redeem event
        fuzz_digiftVerifier_verifySettlement(3, false);

        setActor(rebalancer);
        fuzz_digift_settleRedeem(15e18, 14e18);

        setActor(USERS[0]);
        fuzz_digift_withdraw(14e18);
    }
}
