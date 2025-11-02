// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzGuided.sol";

contract FoundryPlayground is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992); //echidna starting time
        fuzzSetup();
    }

    function test_handler_deposit() public {
        setActor(USERS[0]);
        fuzz_deposit(1e18);
    }

    function test_handler_mint() public {
        setActor(USERS[1]);
        fuzz_mint(5e17);
    }

    function test_handler_requestRedeem() public {
        setActor(USERS[0]);
        fuzz_deposit(2e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(1e18);
    }

    function test_handler_fulfillRedeem() public {
        setActor(USERS[0]);
        fuzz_deposit(3e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(2e18);

        setActor(rebalancer);
        fuzz_fulfillRedeem(0);
    }

    function test_handler_fulfillRedeem_fail() public {
        setActor(rebalancer);
        fuzz_fulfillRedeem(5);
    }

    function test_handler_withdraw() public {
        setActor(USERS[0]);
        fuzz_deposit(4e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(2e18);

        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        setActor(USERS[0]);
        fuzz_withdraw(0, 1e18);
    }

    function test_handler_setOperator() public {
        setActor(USERS[0]);
        fuzz_setOperator(1, true);
    }

    function test_handler_node_approve() public {
        setActor(USERS[0]);
        fuzz_node_approve(3, 1e18);
    }

    function test_handler_node_transfer() public {
        setActor(USERS[0]);
        fuzz_node_transfer(2, 5e17);
    }

    function test_handler_node_transferFrom() public {
        setActor(USERS[1]);
        fuzz_node_transferFrom(4, 7e17);
    }

    function test_handler_node_redeem() public {
        setActor(USERS[2]);
        fuzz_node_redeem(9);
    }

    function test_handler_donate() public {
        setActor(USERS[2]);
        fuzz_donate(0, 1, 1e18);
    }

    function test_lifecycle_full_redemption() public {
        setActor(USERS[1]);
        fuzz_deposit(5e18);

        setActor(USERS[1]);
        fuzz_requestRedeem(3e18);

        setActor(rebalancer);
        fuzz_fulfillRedeem(0);

        setActor(USERS[1]);
        fuzz_withdraw(0, 2e18);
    }

    function test_handler_digiftFactory_deploy() public {
        setActor(owner);
        fuzz_digiftFactory_deploy(4);
    }

    function test_handler_digiftFactory_transferOwnership() public {
        setActor(owner);
        fuzz_digiftFactory_transferOwnership(1);
    }

    function test_handler_digiftFactory_renounceOwnership() public {
        setActor(owner);
        fuzz_digiftFactory_renounceOwnership(3);
    }

    function test_handler_digiftFactory_upgrade() public {
        setActor(owner);
        fuzz_digiftFactory_upgrade(2);
    }

    function test_handler_digiftVerifier_setWhitelist() public {
        setActor(owner);
        fuzz_digiftVerifier_setWhitelist(5, true);
    }

    function test_handler_digiftVerifier_setBlockHash() public {
        setActor(owner);
        fuzz_digiftVerifier_setBlockHash(7);
    }

    function test_handler_digiftVerifier_verifySettlement_subscribe() public {
        fuzz_digiftVerifier_verifySettlement(9, true);
    }

    function test_handler_digiftVerifier_verifySettlement_redeem() public {
        fuzz_digiftVerifier_verifySettlement(11, false);
    }

    function test_handler_router4626_invest() public {
        setActor(rebalancer);
        fuzz_router4626_invest(0, 1e20);
    }

    function test_handler_router4626_liquidate() public {
        setActor(rebalancer);
        fuzz_router4626_liquidate(1, 2e18);
    }

    function test_handler_router4626_fulfill() public {
        setActor(rebalancer);
        fuzz_router4626_fulfillRedeem(0, 2);
    }

    function test_handler_router4626_setWhitelist() public {
        setActor(owner);
        fuzz_router4626_setWhitelist(0, true);
    }

    function test_handler_router4626_setBlacklist() public {
        setActor(owner);
        fuzz_router4626_setBlacklist(1, true);
    }

    function test_handler_router4626_setTolerance() public {
        setActor(owner);
        fuzz_router4626_setTolerance(5);
    }

    function test_handler_router4626_batchWhitelist() public {
        setActor(owner);
        fuzz_router4626_batchWhitelist(3);
    }

    function test_handler_router7540_invest() public {
        setActor(rebalancer);
        fuzz_router7540_invest(0, 5e20);
    }

    function test_handler_router7540_mintClaimable() public {
        setActor(rebalancer);
        fuzz_router7540_mintClaimable(1);
    }

    function test_handler_router7540_requestWithdrawal() public {
        setActor(rebalancer);
        fuzz_router7540_requestWithdrawal(0, 2e18);
    }

    function test_handler_router7540_executeWithdrawal() public {
        setActor(rebalancer);
        fuzz_router7540_executeWithdrawal(1, 3e18);
    }

    function test_handler_router7540_fulfillRedeem() public {
        setActor(rebalancer);
        fuzz_router7540_fulfillRedeem(0, 0);
    }

    function test_handler_router7540_setWhitelist() public {
        setActor(owner);
        fuzz_router7540_setWhitelist(0, true);
    }

    function test_handler_router7540_setBlacklist() public {
        setActor(owner);
        fuzz_router7540_setBlacklist(1, true);
    }

    function test_handler_router7540_setTolerance() public {
        setActor(owner);
        fuzz_router7540_setTolerance(7);
    }

    function test_handler_router7540_batchWhitelist() public {
        setActor(owner);
        fuzz_router7540_batchWhitelist(5);
    }

    function test_handler_fluid_claim() public {
        setActor(rebalancer);
        fuzz_fluid_claim(1e18, 2, 3);
    }

    function test_handler_incentra_claim() public {
        setActor(rebalancer);
        fuzz_incentra_claim(2e18, 5, 7);
    }

    function test_handler_merkl_claim() public {
        setActor(rebalancer);
        fuzz_merkl_claim(3e18, 11);
    }

    function test_handler_oneInch_swap() public {
        setActor(rebalancer);
        fuzz_oneInch_swap(0, 5e18, 2);
    }

    function test_handler_oneInch_setIncentiveWhitelist() public {
        setActor(owner);
        fuzz_oneInch_setIncentiveWhitelist(1, true);
    }

    function test_handler_oneInch_setExecutorWhitelist() public {
        setActor(owner);
        fuzz_oneInch_setExecutorWhitelist(2, true);
    }

    function test_handler_node_setAnnualManagementFee() public {
        setActor(owner);
        fuzz_node_setAnnualManagementFee(5);
    }

    function test_handler_node_setMaxDepositSize() public {
        setActor(owner);
        fuzz_node_setMaxDepositSize(1e24);
    }

    function test_handler_node_setNodeOwnerFeeAddress() public {
        setActor(owner);
        fuzz_node_setNodeOwnerFeeAddress(7);
    }

    function test_handler_node_setQuoter() public {
        setActor(owner);
        fuzz_node_setQuoter();
    }

    function test_handler_node_setRebalanceCooldown() public {
        setActor(owner);
        fuzz_node_setRebalanceCooldown(2 days);
    }

    function test_handler_node_setRebalanceWindow() public {
        setActor(owner);
        fuzz_node_setRebalanceWindow(3 days);
    }

    function test_handler_node_setLiquidationQueue() public {
        setActor(owner);
        fuzz_node_setLiquidationQueue(4);
    }

    function test_handler_node_rescueTokens() public {
        setActor(owner);
        fuzz_node_rescueTokens(1e20);
    }

    function test_handler_node_addComponent() public {
        setActor(owner);
        fuzz_node_addComponent(6);
    }

    function test_handler_node_removeComponent() public {
        setActor(owner);
        fuzz_node_addComponent(6);

        setActor(owner);
        fuzz_node_removeComponent(6, false);
    }

    function test_handler_node_updateComponentAllocation() public {
        setActor(owner);
        fuzz_node_updateComponentAllocation(7);
    }

    function test_handler_node_updateTargetReserveRatio() public {
        setActor(owner);
        fuzz_node_updateTargetReserveRatio(5);
    }

    function test_handler_node_startRebalance() public {
        setActor(rebalancer);
        fuzz_node_startRebalance(3);
    }

    function test_handler_node_payManagementFees() public {
        setActor(owner);
        fuzz_node_payManagementFees(4);
    }

    function test_handler_node_updateTotalAssets() public {
        setActor(owner);
        fuzz_node_updateTotalAssets(2);
    }

    function test_handler_node_subtractProtocolExecutionFee() public {
        fuzz_node_subtractProtocolExecutionFee(5);
    }

    function test_handler_node_execute() public {
        fuzz_node_execute(3);
    }

    function test_handler_node_execute_fail() public {
        fuzz_node_execute(5);
    }

    function test_handler_node_submitPolicyData() public {
        fuzz_node_addPolicies(8);
        fuzz_node_submitPolicyData(6);
    }

    function test_handler_node_submitPolicyData_fail() public {
        fuzz_node_submitPolicyData(4);
    }

    function test_handler_node_finalizeRedemption() public {
        setActor(owner);
        fuzz_node_finalizeRedemption(4);
    }

    function test_handler_node_multicall() public {
        setActor(owner);
        fuzz_node_multicall(8);
    }

    function test_handler_node_multicall_fail() public {
        setActor(owner);
        fuzz_node_multicall(5);
    }

    function test_handler_node_enableSwingPricing() public {
        setActor(owner);
        fuzz_node_enableSwingPricing(7, true);
    }

    function test_handler_node_addPolicies() public {
        setActor(owner);
        fuzz_node_addPolicies(8);
    }

    function test_handler_node_removePolicies() public {
        setActor(owner);
        fuzz_node_addPolicies(8);

        setActor(owner);
        fuzz_node_removePolicies(8);
    }

    function test_handler_node_removePolicies_fail() public {
        setActor(owner);
        fuzz_node_removePolicies(3);
    }

    function test_handler_node_addRebalancer() public {
        setActor(owner);
        fuzz_node_addRebalancer(1);
    }

    function test_handler_node_removeRebalancer() public {
        setActor(owner);
        fuzz_node_removeRebalancer(0);
    }

    function test_handler_node_addRouter() public {
        setActor(owner);
        fuzz_node_addRouter(2);
    }

    function test_handler_node_removeRouter() public {
        setActor(owner);
        fuzz_node_removeRouter(0);
    }

    function test_handler_registry_setProtocolFeeAddress() public {
        setActor(owner);
        fuzz_registry_setProtocolFeeAddress(1);
    }

    function test_handler_registry_setProtocolManagementFee() public {
        setActor(owner);
        fuzz_registry_setProtocolManagementFee(1);
    }

    function test_handler_registry_setProtocolExecutionFee() public {
        setActor(owner);
        fuzz_registry_setProtocolExecutionFee(1);
    }

    function test_handler_registry_setProtocolMaxSwingFactor() public {
        setActor(owner);
        fuzz_registry_setProtocolMaxSwingFactor(1);
    }

    function test_handler_registry_setPoliciesRoot() public {
        setActor(owner);
        fuzz_registry_setPoliciesRoot(2);
    }

    function test_handler_registry_setPoliciesRoot_fail() public {
        fuzz_registry_setPoliciesRoot(3);
    }

    function test_handler_registry_setRegistryType() public {
        setActor(owner);
        fuzz_registry_setRegistryType(1);
    }

    function test_handler_registry_addNode() public {
        fuzz_registry_addNode(1);
    }

    function test_handler_registry_transferOwnership() public {
        setActor(owner);
        fuzz_registry_transferOwnership(1);
    }

    function test_handler_registry_renounceOwnership() public {
        fuzz_registry_renounceOwnership(2);
    }

    function test_handler_registry_initialize() public {
        setActor(owner);
        fuzz_registry_initialize(1);
    }

    function test_handler_registry_upgradeToAndCall() public {
        setActor(owner);
        fuzz_registry_upgradeToAndCall(1);
    }

    function test_handler_nodeFactory_deploy() public {
        setActor(USERS[0]);
        fuzz_nodeFactory_deploy(11);
    }

    function test_handler_node_renounceOwnership() public {
        fuzz_node_renounceOwnership(5);
    }

    function test_handler_node_transferOwnership() public {
        fuzz_node_transferOwnership(6);
    }

    function test_handler_node_initialize() public {
        setActor(owner);
        fuzz_node_initialize(9);
    }
}
