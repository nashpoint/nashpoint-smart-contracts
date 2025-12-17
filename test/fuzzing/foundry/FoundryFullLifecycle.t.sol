// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryFullLifecycle
 * @notice Comprehensive integration tests for full protocol lifecycle
 * @dev Tests the complete user journey: deploy node, deposit, mint, redeem
 *      These tests verify end-to-end protocol functionality
 */
contract FoundryFullLifecycle is FuzzGuided {
    /**
     * @notice Setup function to initialize the fuzzing environment
     */
    function setUp() public {
        fuzzSetup();
        clearNodeContextOverrideForTest();
    }

    /**
     * @notice Test complete lifecycle: deploy node and perform operations
     * @dev Deploy a new node via factory, then deposit and mint on it
     */
    function test_fullLifecycle_deploy_and_use() public {
        forceNodeContextForTest(0);
        // Deploy a new node
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);
        forceNodeContextForTest(managedNodeCountForTest() - 1);

        // Perform deposits on the default node
        setActor(USERS[2]);
        fuzz_deposit(5e17);

        setActor(USERS[3]);
        fuzz_mint(4e17);

        setActor(USERS[2]);
        fuzz_deposit(3e17);
    }

    /**
     * @notice Test lifecycle with multiple node deployments
     * @dev Deploy multiple nodes and perform operations
     */
    function test_fullLifecycle_multiple_deploys() public {
        forceNodeContextForTest(0);
        // User 1 deploys a node
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        // User 2 deploys a node
        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(2);
        forceNodeContextForTest(managedNodeCountForTest() - 1);

        // Users perform operations on default node
        setActor(USERS[1]);
        fuzz_deposit(6e17);

        setActor(USERS[2]);
        fuzz_mint(5e17);

        setActor(USERS[3]);
        fuzz_deposit(4e17);
    }

    /**
     * @notice Test full cycle with deposits, mints, and redemptions
     * @dev Complete workflow including redemption requests
     */
    function test_fullLifecycle_complete_cycle() public {
        forceNodeContextForTest(0);
        // Deploy node
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);
        forceNodeContextForTest(managedNodeCountForTest() - 1);

        // Deposits and mints
        setActor(USERS[1]);
        fuzz_deposit(8e17);

        setActor(USERS[2]);
        fuzz_mint(6e17);

        setActor(USERS[3]);
        fuzz_deposit(5e17);

        // Request redemptions
        setActor(USERS[1]);
        fuzz_requestRedeem(3e17);

        setActor(USERS[2]);
        fuzz_requestRedeem(2e17);
    }

    /**
     * @notice Test lifecycle with transfers and approvals
     * @dev Deploy, deposit, and perform transfers
     */
    function test_fullLifecycle_with_transfers() public {
        forceNodeContextForTest(0);
        // Deploy
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(2);
        forceNodeContextForTest(0);

        // Deposits
        setActor(USERS[1]);
        fuzz_deposit(7e17);

        setActor(USERS[2]);
        fuzz_deposit(6e17);

        // Approvals and transfers
        setActor(USERS[1]);
        fuzz_node_approve(2, 5e17);

        setActor(USERS[1]);
        fuzz_node_transfer(3, 3e17);

        setActor(USERS[2]);
        fuzz_mint(4e17);
    }

    /**
     * @notice Test lifecycle with operator management
     * @dev Deploy, deposit, and manage operators
     */
    function test_fullLifecycle_with_operators() public {
        forceNodeContextForTest(0);
        // Deploy
        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(1);
        forceNodeContextForTest(managedNodeCountForTest() - 1);

        // Set operators
        setActor(USERS[1]);
        fuzz_setOperator(2, true);

        // Deposits
        setActor(USERS[1]);
        fuzz_deposit(6e17);

        setActor(USERS[2]);
        fuzz_mint(5e17);

        setActor(USERS[3]);
        fuzz_deposit(4e17);

        // More operator actions
        setActor(USERS[2]);
        fuzz_setOperator(3, true);
    }

    /**
     * @notice Test Digift adapter operations in full lifecycle
     * @dev Combine node operations with Digift adapter approvals
     */
    function test_fullLifecycle_with_digift() public {
        forceNodeContextForTest(0);
        // Deploy node
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);
        forceNodeContextForTest(0);

        // Node operations
        setActor(USERS[1]);
        fuzz_deposit(7e17);

        // Digift adapter approvals
        fuzz_digift_approve(1, 5e17);
        fuzz_digift_approve(2, 6e17);

        // More node operations
        setActor(USERS[2]);
        fuzz_mint(5e17);

        setActor(USERS[3]);
        fuzz_deposit(4e17);
    }

    /**
     * @notice Test event verification in full lifecycle
     * @dev Combine operations with event verifications
     */
    function test_fullLifecycle_with_verification() public {
        forceNodeContextForTest(0);
        // Deploy
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(2);
        forceNodeContextForTest(0);

        // Deposits
        setActor(USERS[1]);
        fuzz_deposit(8e17);

        // More operations
        setActor(USERS[2]);
        fuzz_mint(6e17);

        setActor(USERS[3]);
        fuzz_deposit(5e17);
    }

    /**
     * @notice Test comprehensive multi-user lifecycle
     * @dev All users deploy, deposit, and interact
     */
    function test_fullLifecycle_all_users() public {
        forceNodeContextForTest(0);
        // All users deploy nodes
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(3);
        forceNodeContextForTest(0);

        // All users perform deposits
        setActor(USERS[1]);
        fuzz_deposit(7e17);

        setActor(USERS[2]);
        fuzz_deposit(6e17);

        setActor(USERS[3]);
        fuzz_deposit(5e17);

        // All users mint
        setActor(USERS[1]);
        fuzz_mint(4e17);

        setActor(USERS[2]);
        fuzz_mint(3e17);

        setActor(USERS[3]);
        fuzz_mint(2e17);
    }

    /**
     * @notice Test sequential lifecycle operations
     * @dev Sequential deployment and operations by single user
     */
    function test_fullLifecycle_sequential() public {
        forceNodeContextForTest(0);
        setActor(USERS[1]);

        // Deploy
        fuzz_nodeFactory_deploy(1);
        forceNodeContextForTest(0);

        // Deposits
        fuzz_deposit(8e17);
        fuzz_deposit(7e17);

        // Mints
        fuzz_mint(6e17);
        fuzz_mint(5e17);

        // Redemption
        fuzz_requestRedeem(3e17);
    }

    /**
     * @notice Test mixed operations across all modules
     * @dev Comprehensive test touching all handler types
     */
    function test_fullLifecycle_mixed_operations() public {
        forceNodeContextForTest(0);
        // Deploy
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);
        forceNodeContextForTest(0);

        // Node operations
        setActor(USERS[1]);
        fuzz_deposit(9e17);
        fuzz_node_approve(2, 7e17);

        // Digift operations
        fuzz_digift_approve(1, 6e17);

        // More node operations
        setActor(USERS[2]);
        fuzz_mint(5e17);
        fuzz_setOperator(3, true);

        // More operations
        setActor(USERS[3]);
        fuzz_deposit(4e17);
        fuzz_requestRedeem(2e17);
    }
}
