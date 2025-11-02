// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzGuided.sol";

/**
 * @title FoundryAdmin
 * @notice Integration tests for Registry, NodeFactory, and NodeAdmin handlers
 * @dev Tests happy path flows for protocol administration
 */
contract FoundryAdmin is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992);
        fuzzSetup();
    }

    // ==============================================================
    // NODE FACTORY OPERATIONS
    // ==============================================================

    function test_story_factory_deployNode() public {
        setActor(USERS[0]);
        fuzz_nodeFactory_deploy(1);
    }

    function test_story_multiple_nodes_deployment() public {
        setActor(USERS[0]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(4);
    }

    // ==============================================================
    // REGISTRY CONFIGURATION
    // ==============================================================

    function test_story_registry_setProtocolFeeAddress() public {
        setActor(owner);
        fuzz_registry_setProtocolFeeAddress(1);
    }

    function test_story_registry_setManagementFee() public {
        setActor(owner);
        fuzz_registry_setProtocolManagementFee(100); // 1%
    }

    function test_story_registry_setExecutionFee() public {
        setActor(owner);
        fuzz_registry_setProtocolExecutionFee(50); // 0.5%
    }

    function test_story_registry_setMaxSwingFactor() public {
        setActor(owner);
        fuzz_registry_setProtocolMaxSwingFactor(200); // 2%
    }

    function test_story_registry_setRegistryType() public {
        setActor(owner);
        fuzz_registry_setRegistryType(1);
    }

    // ==============================================================
    // REGISTRY FEES CONFIGURATION FLOW
    // ==============================================================

    function test_story_registry_configure_all_fees() public {
        // Set protocol fee address
        setActor(owner);
        fuzz_registry_setProtocolFeeAddress(1);

        // Set management fee
        setActor(owner);
        fuzz_registry_setProtocolManagementFee(150); // 1.5%

        // Set execution fee
        setActor(owner);
        fuzz_registry_setProtocolExecutionFee(75); // 0.75%

        // Set swing factor
        setActor(owner);
        fuzz_registry_setProtocolMaxSwingFactor(100); // 1%
    }

    function test_story_registry_fees_affect_operations() public {
        // Configure fees
        setActor(owner);
        fuzz_registry_setProtocolManagementFee(200); // 2%

        setActor(owner);
        fuzz_registry_setProtocolExecutionFee(100); // 1%

        // User deposits with fees applied
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        // Time passes
        vm.warp(block.timestamp + 365 days);

        // Pay management fees
        setActor(owner);
        fuzz_node_payManagementFees(1);
    }

    // ==============================================================
    // NODE ADMIN - COMPONENT MANAGEMENT
    // ==============================================================

    function test_story_admin_addComponent() public {
        setActor(owner);
        fuzz_node_addComponent(5);
    }

    function test_story_admin_add_remove_component() public {
        // Add component
        setActor(owner);
        fuzz_node_addComponent(6);

        // Remove component
        setActor(owner);
        fuzz_node_removeComponent(6, false);
    }

    function test_story_admin_updateComponentAllocation() public {
        setActor(owner);
        fuzz_node_updateComponentAllocation(0);
    }

    function test_story_admin_updateReserveRatio() public {
        setActor(owner);
        fuzz_node_updateTargetReserveRatio(3);
    }

    function test_story_admin_rebalance_configuration() public {
        // Update component allocations
        setActor(owner);
        fuzz_node_updateComponentAllocation(0);

        setActor(owner);
        fuzz_node_updateComponentAllocation(1);

        // Update reserve ratio
        setActor(owner);
        fuzz_node_updateTargetReserveRatio(4);

        // Rebalancer rebalances to new targets
        setActor(rebalancer);
        fuzz_node_startRebalance(1);
    }

    // ==============================================================
    // NODE ADMIN - ROUTER MANAGEMENT
    // ==============================================================

    function test_story_admin_addRouter() public {
        setActor(owner);
        fuzz_node_addRouter(2);
    }

    function test_story_admin_add_remove_router() public {
        // Add router
        setActor(owner);
        fuzz_node_addRouter(3);

        // Remove router
        setActor(owner);
        fuzz_node_removeRouter(3);
    }

    // ==============================================================
    // NODE ADMIN - REBALANCER MANAGEMENT
    // ==============================================================

    function test_story_admin_addRebalancer() public {
        setActor(owner);
        fuzz_node_addRebalancer(1);
    }

    function test_story_admin_add_remove_rebalancer() public {
        // Add rebalancer
        setActor(owner);
        fuzz_node_addRebalancer(2);

        // Remove rebalancer
        setActor(owner);
        fuzz_node_removeRebalancer(2);
    }

    // ==============================================================
    // NODE ADMIN - LIQUIDATION QUEUE
    // ==============================================================

    function test_story_admin_setLiquidationQueue() public {
        setActor(owner);
        fuzz_node_setLiquidationQueue(1);
    }

    function test_story_admin_liquidationQueue_affects_redemptions() public {
        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(25e18);

        // Owner sets liquidation queue
        setActor(owner);
        fuzz_node_setLiquidationQueue(2);

        // User requests redemption
        setActor(USERS[0]);
        fuzz_requestRedeem(12e18);

        // Rebalancer fulfills using queue
        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(0, 0);

        setActor(USERS[0]);
        fuzz_withdraw(0, 10e18);
    }

    // ==============================================================
    // NODE ADMIN - QUOTER & SETTINGS
    // ==============================================================

    function test_story_admin_setQuoter() public {
        setActor(owner);
        fuzz_node_setQuoter();
    }

    function test_story_admin_setRebalanceCooldown() public {
        setActor(owner);
        fuzz_node_setRebalanceCooldown(1 days);
    }

    function test_story_admin_setRebalanceWindow() public {
        setActor(owner);
        fuzz_node_setRebalanceWindow(12 hours);
    }

    function test_story_admin_rebalance_timing_config() public {
        // Set cooldown
        setActor(owner);
        fuzz_node_setRebalanceCooldown(2 days);

        // Set window
        setActor(owner);
        fuzz_node_setRebalanceWindow(6 hours);

        // Rebalancer operates within new timing
        setActor(rebalancer);
        fuzz_node_startRebalance(2);
    }

    // ==============================================================
    // NODE ADMIN - FEE CONFIGURATION
    // ==============================================================

    function test_story_admin_setAnnualManagementFee() public {
        setActor(owner);
        fuzz_node_setAnnualManagementFee(150); // 1.5%
    }

    function test_story_admin_setMaxDepositSize() public {
        setActor(owner);
        fuzz_node_setMaxDepositSize(100_000e18);
    }

    function test_story_admin_setNodeOwnerFeeAddress() public {
        setActor(owner);
        fuzz_node_setNodeOwnerFeeAddress(1);
    }

    function test_story_admin_fee_configuration_flow() public {
        // Set management fee
        setActor(owner);
        fuzz_node_setAnnualManagementFee(200); // 2%

        // Set max deposit
        setActor(owner);
        fuzz_node_setMaxDepositSize(500_000e18);

        // Set fee address
        setActor(owner);
        fuzz_node_setNodeOwnerFeeAddress(2);

        // Users deposit
        setActor(USERS[0]);
        fuzz_deposit(50e18);

        // Time passes
        vm.warp(block.timestamp + 365 days);

        // Pay fees
        setActor(owner);
        fuzz_node_payManagementFees(2);
    }

    // ==============================================================
    // NODE ADMIN - SWING PRICING
    // ==============================================================

    function test_story_admin_enableSwingPricing() public {
        setActor(owner);
        fuzz_node_enableSwingPricing(5, true);
    }

    function test_story_admin_swing_pricing_lifecycle() public {
        // Enable swing pricing
        setActor(owner);
        fuzz_node_enableSwingPricing(3, true);

        // Users deposit with swing pricing
        setActor(USERS[0]);
        fuzz_deposit(15e18);

        setActor(USERS[1]);
        fuzz_deposit(12e18);

        // Disable swing pricing
        setActor(owner);
        fuzz_node_enableSwingPricing(3, false);

        // Users continue operations
        setActor(USERS[2]);
        fuzz_deposit(10e18);
    }

    // ==============================================================
    // POLICY MANAGEMENT
    // ==============================================================

    function test_story_admin_addPolicies() public {
        setActor(owner);
        fuzz_node_addPolicies(1);
    }

    function test_story_admin_add_remove_policies() public {
        // Add policies
        setActor(owner);
        fuzz_node_addPolicies(2);

        // Submit policy data
        setActor(owner);
        fuzz_node_submitPolicyData(2);

        // Remove policies
        setActor(owner);
        fuzz_node_removePolicies(2);
    }

    function test_story_admin_policies_affect_operations() public {
        // Add policies
        setActor(owner);
        fuzz_node_addPolicies(3);

        // Users interact (policies check)
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        setActor(USERS[1]);
        fuzz_mint(15e18);

        // Submit policy data
        setActor(owner);
        fuzz_node_submitPolicyData(3);
    }

    function test_story_registry_setPoliciesRoot() public {
        setActor(owner);
        fuzz_registry_setPoliciesRoot(1);
    }

    // ==============================================================
    // RESCUE & EMERGENCY OPERATIONS
    // ==============================================================

    function test_story_admin_rescueTokens() public {
        // Some tokens accidentally sent to node
        setActor(USERS[0]);
        fuzz_donate(0, 0, 5e18);

        // Owner rescues
        setActor(owner);
        fuzz_node_rescueTokens(4e18);
    }

    // ==============================================================
    // COMPLEX ADMIN SCENARIOS
    // ==============================================================

    function test_story_complete_protocol_configuration() public {
        // Registry setup
        setActor(owner);
        fuzz_registry_setProtocolFeeAddress(1);

        setActor(owner);
        fuzz_registry_setProtocolManagementFee(100);

        setActor(owner);
        fuzz_registry_setProtocolExecutionFee(50);

        setActor(owner);
        fuzz_registry_setProtocolMaxSwingFactor(150);

        // Node configuration
        setActor(owner);
        fuzz_node_setAnnualManagementFee(200);

        setActor(owner);
        fuzz_node_setMaxDepositSize(1_000_000e18);

        setActor(owner);
        fuzz_node_setRebalanceCooldown(1 days);

        setActor(owner);
        fuzz_node_setRebalanceWindow(12 hours);

        // Component configuration
        setActor(owner);
        fuzz_node_updateComponentAllocation(0);

        setActor(owner);
        fuzz_node_updateTargetReserveRatio(5);

        setActor(owner);
        fuzz_node_setLiquidationQueue(3);

        // Enable swing pricing
        setActor(owner);
        fuzz_node_enableSwingPricing(4, true);

        // Add policies
        setActor(owner);
        fuzz_node_addPolicies(5);

        // Protocol is now fully configured - users can operate
        setActor(USERS[0]);
        fuzz_deposit(30e18);

        setActor(USERS[1]);
        fuzz_mint(25e18);
    }

    function test_story_protocol_reconfiguration_under_load() public {
        // Users are active
        setActor(USERS[0]);
        fuzz_deposit(40e18);

        setActor(USERS[1]);
        fuzz_deposit(30e18);

        // Admin reconfigures while users active
        setActor(owner);
        fuzz_node_setAnnualManagementFee(150);

        setActor(USERS[2]);
        fuzz_deposit(20e18);

        setActor(owner);
        fuzz_node_updateComponentAllocation(0);

        setActor(USERS[3]);
        fuzz_deposit(15e18);

        setActor(owner);
        fuzz_node_setRebalanceWindow(6 hours);

        // Rebalancer operates
        setActor(rebalancer);
        fuzz_node_startRebalance(3);

        // More user activity
        setActor(USERS[0]);
        fuzz_requestRedeem(20e18);

        // Admin continues configuration
        setActor(owner);
        fuzz_node_enableSwingPricing(6, true);

        // Fulfill redemption
        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        setActor(USERS[0]);
        fuzz_withdraw(0, 18e18);
    }

    // ==============================================================
    // OWNERSHIP TRANSFERS
    // ==============================================================

    function test_story_node_transferOwnership() public {
        setActor(owner);
        fuzz_node_transferOwnership(1);
    }

    function test_story_registry_transferOwnership() public {
        setActor(owner);
        fuzz_registry_transferOwnership(2);
    }

    function test_story_complete_ownership_transfer() public {
        // Transfer registry ownership
        setActor(owner);
        fuzz_registry_transferOwnership(1);

        // Transfer node ownership
        setActor(owner);
        fuzz_node_transferOwnership(1);

        // Transfer digift factory ownership
        setActor(owner);
        fuzz_digiftFactory_transferOwnership(1);
    }

    // ==============================================================
    // UPGRADES
    // ==============================================================

    function test_story_registry_upgradeToAndCall() public {
        setActor(owner);
        fuzz_registry_upgradeToAndCall(1);
    }

    function test_story_digiftFactory_upgrade() public {
        setActor(owner);
        fuzz_digiftFactory_upgrade(1);
    }
}
