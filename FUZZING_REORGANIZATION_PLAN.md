# Fuzzing Handlers Reorganization Plan

## Overview
Reorganize fuzzing handlers based on access control categories:
1. **Category 1 (User)**: Keep in Fuzz*.sol files as-is
2. **Category 2 (Admin/Owner)**: Move to FuzzAdmin*.sol files with fuzz_admin_* prefix, then comment out
3. **Category 3 (Internal Protocol)**: DELETE completely

## Node Handlers

### FuzzNode.sol - KEEP THESE (Category 1):
- fuzz_deposit
- fuzz_mint
- fuzz_requestRedeem
- fuzz_withdraw
- fuzz_setOperator
- fuzz_node_approve
- fuzz_node_transfer
- fuzz_node_transferFrom
- fuzz_node_submitPolicyData
- fuzz_node_multicall
- fuzz_node_redeem

### FuzzNode.sol - DELETE THESE (Category 3):
- fuzz_fulfillRedeem (onlyRebalancer, onlyWhenRebalancing)
- fuzz_node_startRebalance (onlyRebalancer)
- fuzz_node_subtractProtocolExecutionFee (onlyRouter)
- fuzz_node_execute (onlyRouter)
- fuzz_node_finalizeRedemption (onlyRouter)

### FuzzNode.sol - MOVE TO ADMIN (Category 2):
- fuzz_node_payManagementFees (onlyOwnerOrRebalancer)
- fuzz_node_updateTotalAssets (onlyOwnerOrRebalancer)

### FuzzNodeAdmin.sol → FuzzAdminNode.sol:
**Action**: Rename file, add fuzz_admin_* prefix to all handlers, comment all out, and add the 2 moved handlers

**DELETE from FuzzNodeAdmin.sol (Category 3)**:
- fuzz_node_initialize (initializer - one-time only)

**KEEP ALL THESE (rename with fuzz_admin_* prefix and comment out)**:
- fuzz_node_setAnnualManagementFee → fuzz_admin_node_setAnnualManagementFee
- fuzz_node_setMaxDepositSize → fuzz_admin_node_setMaxDepositSize
- fuzz_node_setNodeOwnerFeeAddress → fuzz_admin_node_setNodeOwnerFeeAddress
- fuzz_node_setQuoter → fuzz_admin_node_setQuoter
- fuzz_node_setRebalanceCooldown → fuzz_admin_node_setRebalanceCooldown
- fuzz_node_setRebalanceWindow → fuzz_admin_node_setRebalanceWindow
- fuzz_node_setLiquidationQueue → fuzz_admin_node_setLiquidationQueue
- fuzz_node_rescueTokens → fuzz_admin_node_rescueTokens
- fuzz_node_addComponent → fuzz_admin_node_addComponent
- fuzz_node_removeComponent → fuzz_admin_node_removeComponent
- fuzz_node_updateComponentAllocation → fuzz_admin_node_updateComponentAllocation
- fuzz_node_updateTargetReserveRatio → fuzz_admin_node_updateTargetReserveRatio
- fuzz_node_enableSwingPricing → fuzz_admin_node_enableSwingPricing
- fuzz_node_addPolicies → fuzz_admin_node_addPolicies
- fuzz_node_removePolicies → fuzz_admin_node_removePolicies
- fuzz_node_addRebalancer → fuzz_admin_node_addRebalancer
- fuzz_node_removeRebalancer → fuzz_admin_node_removeRebalancer
- fuzz_node_addRouter → fuzz_admin_node_addRouter
- fuzz_node_removeRouter → fuzz_admin_node_removeRouter
- fuzz_node_renounceOwnership → fuzz_admin_node_renounceOwnership
- fuzz_node_transferOwnership → fuzz_admin_node_transferOwnership

**ADD THESE (from FuzzNode, renamed with fuzz_admin_* prefix and commented out)**:
- fuzz_node_payManagementFees → fuzz_admin_node_payManagementFees
- fuzz_node_updateTotalAssets → fuzz_admin_node_updateTotalAssets

## DigiftAdapter Handlers

### FuzzDigiftAdapter.sol - All handlers are currently commented out, need to review

**Category 1 (User) - Uncomment and keep**:
- approve, transfer, transferFrom (standard ERC20)

**Category 2 (Admin - onlyRegistryOwner) - Keep commented, move to FuzzAdminDigiftAdapter.sol with fuzz_admin_* prefix**:
- forceUpdateLastPrice
- setManager
- setMinDepositAmount
- setMinRedeemAmount
- setNode
- setPriceDeviation
- setPriceUpdateDeviation
- setSettlementDeviation

**Category 3 (Internal - onlyWhitelistedNode, onlyManager) - DELETE**:
- mint (onlyWhitelistedNode)
- requestDeposit (onlyWhitelistedNode)
- requestRedeem (onlyWhitelistedNode)
- withdraw (onlyWhitelistedNode)
- forwardRequestsToDigift (onlyManager)
- settleDeposit (onlyManager)
- settleRedeem (onlyManager)
- updateLastPrice (onlyManager)
- initialize (initializer)
- setOperator (Unsupported - DELETE)
- depositUnsupported/redeemUnsupported (testing Unsupported - DELETE)

## DigiftEventVerifier Handlers

### FuzzDigiftEventVerifier.sol

**Category 1 (User)**:
- verifySettlementEvent (public, callable by anyone)

**Category 2 (Admin - onlyRegistryOwner) - Move to FuzzAdminDigiftEventVerifier.sol with fuzz_admin_* prefix**:
- setBlockHash
- setWhitelist

**Category 3 (Internal) - DELETE**:
- configureSettlement (if it's a helper, not actual entry point)

## DigiftAdapterFactory Handlers

### FuzzDigiftAdapterFactory.sol → FuzzAdminDigiftAdapterFactory.sol

**All handlers are Category 2 (onlyOwner) - Rename file, add fuzz_admin_* prefix, comment all out**:
- deploy → fuzz_admin_digiftFactory_deploy
- transferOwnership → fuzz_admin_digiftFactory_transferOwnership
- renounceOwnership → fuzz_admin_digiftFactory_renounceOwnership
- upgrade → fuzz_admin_digiftFactory_upgrade

## Router Handlers

### FuzzERC4626Router.sol

**Category 2 (Admin - onlyRegistryOwner) - Move to FuzzAdminERC4626Router.sol with fuzz_admin_* prefix**:
- batchWhitelist → fuzz_admin_router4626_batchWhitelist
- setWhitelist → fuzz_admin_router4626_setWhitelist
- setBlacklist → fuzz_admin_router4626_setBlacklist
- setTolerance → fuzz_admin_router4626_setTolerance

**Category 3 (Internal - onlyNodeRebalancer, onlyNodeComponent) - DELETE**:
- invest
- liquidate
- fulfillRedeem

### FuzzERC7540Router.sol

**Category 2 (Admin - onlyRegistryOwner) - Move to FuzzAdminERC7540Router.sol with fuzz_admin_* prefix**:
- batchWhitelist → fuzz_admin_router7540_batchWhitelist
- setWhitelist → fuzz_admin_router7540_setWhitelist
- setBlacklist → fuzz_admin_router7540_setBlacklist
- setTolerance → fuzz_admin_router7540_setTolerance

**Category 3 (Internal - onlyNodeRebalancer, onlyNodeComponent) - DELETE**:
- invest
- mintClaimable
- requestWithdrawal
- executeWithdrawal
- fulfillRedeem

### FuzzOneInchRouter.sol

**Category 2 (Admin - onlyRegistryOwner) - Move to FuzzAdminOneInchRouter.sol with fuzz_admin_* prefix**:
- batchWhitelist → fuzz_admin_oneInch_batchWhitelist
- setWhitelist → fuzz_admin_oneInch_setWhitelist
- setBlacklist → fuzz_admin_oneInch_setBlacklist
- setTolerance → fuzz_admin_oneInch_setTolerance
- setExecutorWhitelist → fuzz_admin_oneInch_setExecutorWhitelist
- setIncentiveWhitelist → fuzz_admin_oneInch_setIncentiveWhitelist

**Category 3 (Internal - onlyNodeRebalancer) - DELETE**:
- swap

### Reward Routers (Fluid, Incentra, Merkl)

**Category 3 (Internal - onlyNodeRebalancer) - DELETE ALL**:
All claim functions in:
- FuzzFluidRewardsRouter.sol
- FuzzIncentraRouter.sol
- FuzzMerklRouter.sol

Consider: DELETE entire files or leave empty with comment explaining why

## NodeFactory Handlers

### FuzzNodeFactory.sol

**Category 1 (User)**:
- deployFullNode (public permissionless deployment)

## NodeRegistry Handlers

### FuzzNodeRegistry.sol → FuzzAdminNodeRegistry.sol

**All handlers are Category 2 (onlyOwner) or Category 3 (onlyFactory/initializer)**

**Category 2 (Admin - onlyOwner) - Keep in FuzzAdminNodeRegistry.sol with fuzz_admin_* prefix, commented**:
- renounceOwnership → fuzz_admin_registry_renounceOwnership
- setPoliciesRoot → fuzz_admin_registry_setPoliciesRoot
- setProtocolExecutionFee → fuzz_admin_registry_setProtocolExecutionFee
- setProtocolFeeAddress → fuzz_admin_registry_setProtocolFeeAddress
- setProtocolManagementFee → fuzz_admin_registry_setProtocolManagementFee
- setProtocolMaxSwingFactor → fuzz_admin_registry_setProtocolMaxSwingFactor
- setRegistryType → fuzz_admin_registry_setRegistryType
- transferOwnership → fuzz_admin_registry_transferOwnership
- upgradeToAndCall → fuzz_admin_registry_upgradeToAndCall

**Category 3 (Internal) - DELETE**:
- addNode (onlyFactory)
- initialize (initializer)

## Preconditions & Postconditions

For each reorganization above, update the corresponding preconditions and postconditions files:
- Remove Category 3 function helpers
- Keep Category 1 and Category 2 helpers (admin helpers can stay commented in separate files if needed)

## Summary of New Files to Create

1. FuzzAdminNode.sol (rename from FuzzNodeAdmin.sol)
2. FuzzAdminDigiftAdapter.sol (new)
3. FuzzAdminDigiftEventVerifier.sol (new)
4. FuzzAdminDigiftAdapterFactory.sol (rename from FuzzDigiftAdapterFactory.sol)
5. FuzzAdminERC4626Router.sol (new)
6. FuzzAdminERC7540Router.sol (new)
7. FuzzAdminOneInchRouter.sol (new)
8. FuzzAdminNodeRegistry.sol (rename from FuzzNodeRegistry.sol)

## Summary of Files to Delete

Potentially delete if all handlers removed:
- FuzzFluidRewardsRouter.sol
- FuzzIncentraRouter.sol
- FuzzMerklRouter.sol
