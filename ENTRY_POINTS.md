# Fuzzing Entry Points

*Generated on 2025-11-01 19:25:27*

## Executive Summary

- **Total Contracts Found**: 13
- **Total Functions Extracted**: 109
- **Contracts with Parsing Errors**: 0
- **Contracts with Compilation Errors**: 0

## Scope Analysis

- **Contracts in scope.csv**: 20
- **Contracts Found & In Scope**: 13
- **Missing from Analysis**: 8

### Missing Contracts

These contracts are in scope.csv but were not found by slither:

- `src/Escrow.sol`
- `src/libraries/BaseComponentRouter.sol`
- `src/libraries/BaseQuoter.sol`
- `src/libraries/ErrorsLib.sol`
- `src/libraries/EventsLib.sol`
- `src/libraries/MathLib.sol`
- `src/libraries/RegistryAccessControl.sol`
- `src/quoters/QuoterV1.sol`

*Note: Libraries typically don't have entry points, and some contracts may not exist.*

## 🎯 Entry Points for Fuzzing

All public/external functions (modifiers shown as comments):

### Core Contracts

#### BeaconProxy
*Path: `lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol`*

```solidity
fallback() // payable
```

#### DigiftAdapter
*Path: `src/adapters/digift/DigiftAdapter.sol`*

```solidity
approve()
deposit()
forceUpdateLastPrice() // onlyRegistryOwner
forwardRequestsToDigift() // onlyManager, nonReentrant
initialize() // initializer
mint() // onlyWhitelistedNode, actionValidation, nonReentrant
redeem()
requestDeposit() // onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant
requestRedeem() // onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant
setManager() // onlyRegistryOwner
setMinDepositAmount() // onlyRegistryOwner
setMinRedeemAmount() // onlyRegistryOwner
setNode() // onlyRegistryOwner
setOperator()
setPriceDeviation() // onlyRegistryOwner
setPriceUpdateDeviation() // onlyRegistryOwner
setSettlementDeviation() // onlyRegistryOwner
settleDeposit() // nonReentrant, onlyManager
settleRedeem() // nonReentrant, onlyManager
transfer()
transferFrom()
updateLastPrice() // onlyManager
withdraw() // onlyWhitelistedNode, actionValidation, nonReentrant
```

#### DigiftAdapterFactory
*Path: `src/adapters/digift/DigiftAdapterFactory.sol`*

```solidity
deploy() // onlyOwner
renounceOwnership() // onlyOwner
transferOwnership() // onlyOwner
upgradeTo() // onlyOwner
```

#### DigiftEventVerifier
*Path: `src/adapters/digift/DigiftEventVerifier.sol`*

```solidity
setBlockHash() // onlyRegistryOwner
setWhitelist() // onlyRegistryOwner
verifySettlementEvent()
```

#### ERC4626Router
*Path: `src/routers/ERC4626Router.sol`*

```solidity
batchSetWhitelistStatus() // onlyRegistryOwner
fulfillRedeemRequest() // nonReentrant, onlyNodeRebalancer, onlyNodeComponent
invest() // nonReentrant, onlyNodeRebalancer, onlyNodeComponent
liquidate() // nonReentrant, onlyNodeRebalancer, onlyNodeComponent
setBlacklistStatus() // onlyRegistryOwner
setTolerance() // onlyRegistryOwner
setWhitelistStatus() // onlyRegistryOwner
```

#### ERC7540Router
*Path: `src/routers/ERC7540Router.sol`*

```solidity
batchSetWhitelistStatus() // onlyRegistryOwner
executeAsyncWithdrawal() // nonReentrant, onlyNodeRebalancer, onlyNodeComponent
fulfillRedeemRequest() // nonReentrant, onlyNodeRebalancer, onlyNodeComponent
investInAsyncComponent() // onlyNodeRebalancer, onlyNodeComponent
mintClaimableShares() // nonReentrant, onlyNodeRebalancer, onlyNodeComponent
requestAsyncWithdrawal() // onlyNodeRebalancer, onlyNodeComponent
setBlacklistStatus() // onlyRegistryOwner
setTolerance() // onlyRegistryOwner
setWhitelistStatus() // onlyRegistryOwner
```

#### FluidRewardsRouter
*Path: `src/routers/FluidRewardsRouter.sol`*

```solidity
claim() // nonReentrant, onlyNodeRebalancer
```

#### IncentraRouter
*Path: `src/routers/IncentraRouter.sol`*

```solidity
claim() // nonReentrant, onlyNodeRebalancer
```

#### MerklRouter
*Path: `src/routers/MerklRouter.sol`*

```solidity
claim() // nonReentrant, onlyNodeRebalancer
```

#### Node
*Path: `src/Node.sol`*

```solidity
addComponent() // onlyOwner, onlyWhenNotRebalancing
addPolicies() // onlyOwner
addRebalancer() // onlyOwner
addRouter() // onlyOwner
approve()
deposit() // nonReentrant
enableSwingPricing() // onlyOwner
execute() // onlyRouter, nonReentrant, onlyWhenRebalancing
finalizeRedemption() // onlyRouter, nonReentrant
fulfillRedeemFromReserve() // onlyRebalancer, onlyWhenRebalancing, nonReentrant
initialize() // initializer
mint() // nonReentrant
multicall()
payManagementFees() // nonReentrant, onlyOwnerOrRebalancer, onlyWhenNotRebalancing
redeem() // nonReentrant
removeComponent() // onlyOwner, onlyWhenNotRebalancing
removePolicies() // onlyOwner
removeRebalancer() // onlyOwner
removeRouter() // onlyOwner
renounceOwnership() // onlyOwner
requestRedeem() // nonReentrant
rescueTokens() // onlyOwner
setAnnualManagementFee() // onlyOwner
setLiquidationQueue() // onlyOwner
setMaxDepositSize() // onlyOwner
setNodeOwnerFeeAddress() // onlyOwner
setOperator() // nonReentrant
setQuoter() // onlyOwner
setRebalanceCooldown() // onlyOwner
setRebalanceWindow() // onlyOwner
startRebalance() // onlyRebalancer, nonReentrant
submitPolicyData()
subtractProtocolExecutionFee() // onlyRouter, nonReentrant
transfer()
transferFrom()
transferOwnership() // onlyOwner
updateComponentAllocation() // onlyOwner, onlyWhenNotRebalancing
updateTargetReserveRatio() // onlyOwner, onlyWhenNotRebalancing
updateTotalAssets() // onlyOwnerOrRebalancer, nonReentrant
withdraw() // nonReentrant
```

#### NodeFactory
*Path: `src/NodeFactory.sol`*

```solidity
deployFullNode()
```

#### NodeRegistry
*Path: `src/NodeRegistry.sol`*

```solidity
addNode() // onlyFactory
initialize() // initializer
renounceOwnership() // onlyOwner
setPoliciesRoot() // onlyOwner
setProtocolExecutionFee() // onlyOwner
setProtocolFeeAddress() // onlyOwner
setProtocolManagementFee() // onlyOwner
setProtocolMaxSwingFactor() // onlyOwner
setRegistryType() // onlyOwner
transferOwnership() // onlyOwner
upgradeToAndCall() // onlyProxy, payable
```

#### OneInchV6RouterV1
*Path: `src/routers/OneInchV6RouterV1.sol`*

```solidity
batchSetWhitelistStatus() // onlyRegistryOwner
setBlacklistStatus() // onlyRegistryOwner
setExecutorWhitelistStatus() // onlyRegistryOwner
setIncentiveWhitelistStatus() // onlyRegistryOwner
setTolerance() // onlyRegistryOwner
setWhitelistStatus() // onlyRegistryOwner
swap() // nonReentrant, onlyNodeRebalancer
```

## Complete Function List

### Format for Fuzzing Tools

Copy this list directly into your fuzzing configuration:

```
BeaconProxy:fallback  # payable
DigiftAdapter:approve
DigiftAdapter:deposit
DigiftAdapter:forceUpdateLastPrice  # onlyRegistryOwner
DigiftAdapter:forwardRequestsToDigift  # onlyManager, nonReentrant
DigiftAdapter:initialize  # initializer
DigiftAdapter:mint  # onlyWhitelistedNode, actionValidation, nonReentrant
DigiftAdapter:redeem
DigiftAdapter:requestDeposit  # onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant
DigiftAdapter:requestRedeem  # onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant
DigiftAdapter:setManager  # onlyRegistryOwner
DigiftAdapter:setMinDepositAmount  # onlyRegistryOwner
DigiftAdapter:setMinRedeemAmount  # onlyRegistryOwner
DigiftAdapter:setNode  # onlyRegistryOwner
DigiftAdapter:setOperator
DigiftAdapter:setPriceDeviation  # onlyRegistryOwner
DigiftAdapter:setPriceUpdateDeviation  # onlyRegistryOwner
DigiftAdapter:setSettlementDeviation  # onlyRegistryOwner
DigiftAdapter:settleDeposit  # nonReentrant, onlyManager
DigiftAdapter:settleRedeem  # nonReentrant, onlyManager
DigiftAdapter:transfer
DigiftAdapter:transferFrom
DigiftAdapter:updateLastPrice  # onlyManager
DigiftAdapter:withdraw  # onlyWhitelistedNode, actionValidation, nonReentrant
DigiftAdapterFactory:deploy  # onlyOwner
DigiftAdapterFactory:renounceOwnership  # onlyOwner
DigiftAdapterFactory:transferOwnership  # onlyOwner
DigiftAdapterFactory:upgradeTo  # onlyOwner
DigiftEventVerifier:setBlockHash  # onlyRegistryOwner
DigiftEventVerifier:setWhitelist  # onlyRegistryOwner
DigiftEventVerifier:verifySettlementEvent
ERC4626Router:batchSetWhitelistStatus  # onlyRegistryOwner
ERC4626Router:fulfillRedeemRequest  # nonReentrant, onlyNodeRebalancer, onlyNodeComponent
ERC4626Router:invest  # nonReentrant, onlyNodeRebalancer, onlyNodeComponent
ERC4626Router:liquidate  # nonReentrant, onlyNodeRebalancer, onlyNodeComponent
ERC4626Router:setBlacklistStatus  # onlyRegistryOwner
ERC4626Router:setTolerance  # onlyRegistryOwner
ERC4626Router:setWhitelistStatus  # onlyRegistryOwner
ERC7540Router:batchSetWhitelistStatus  # onlyRegistryOwner
ERC7540Router:executeAsyncWithdrawal  # nonReentrant, onlyNodeRebalancer, onlyNodeComponent
ERC7540Router:fulfillRedeemRequest  # nonReentrant, onlyNodeRebalancer, onlyNodeComponent
ERC7540Router:investInAsyncComponent  # onlyNodeRebalancer, onlyNodeComponent
ERC7540Router:mintClaimableShares  # nonReentrant, onlyNodeRebalancer, onlyNodeComponent
ERC7540Router:requestAsyncWithdrawal  # onlyNodeRebalancer, onlyNodeComponent
ERC7540Router:setBlacklistStatus  # onlyRegistryOwner
ERC7540Router:setTolerance  # onlyRegistryOwner
ERC7540Router:setWhitelistStatus  # onlyRegistryOwner
FluidRewardsRouter:claim  # nonReentrant, onlyNodeRebalancer
IncentraRouter:claim  # nonReentrant, onlyNodeRebalancer
MerklRouter:claim  # nonReentrant, onlyNodeRebalancer
Node:addComponent  # onlyOwner, onlyWhenNotRebalancing
Node:addPolicies  # onlyOwner
Node:addRebalancer  # onlyOwner
Node:addRouter  # onlyOwner
Node:approve
Node:deposit  # nonReentrant
Node:enableSwingPricing  # onlyOwner
Node:execute  # onlyRouter, nonReentrant, onlyWhenRebalancing
Node:finalizeRedemption  # onlyRouter, nonReentrant
Node:fulfillRedeemFromReserve  # onlyRebalancer, onlyWhenRebalancing, nonReentrant
Node:initialize  # initializer
Node:mint  # nonReentrant
Node:multicall
Node:payManagementFees  # nonReentrant, onlyOwnerOrRebalancer, onlyWhenNotRebalancing
Node:redeem  # nonReentrant
Node:removeComponent  # onlyOwner, onlyWhenNotRebalancing
Node:removePolicies  # onlyOwner
Node:removeRebalancer  # onlyOwner
Node:removeRouter  # onlyOwner
Node:renounceOwnership  # onlyOwner
Node:requestRedeem  # nonReentrant
Node:rescueTokens  # onlyOwner
Node:setAnnualManagementFee  # onlyOwner
Node:setLiquidationQueue  # onlyOwner
Node:setMaxDepositSize  # onlyOwner
Node:setNodeOwnerFeeAddress  # onlyOwner
Node:setOperator  # nonReentrant
Node:setQuoter  # onlyOwner
Node:setRebalanceCooldown  # onlyOwner
Node:setRebalanceWindow  # onlyOwner
Node:startRebalance  # onlyRebalancer, nonReentrant
Node:submitPolicyData
Node:subtractProtocolExecutionFee  # onlyRouter, nonReentrant
Node:transfer
Node:transferFrom
Node:transferOwnership  # onlyOwner
Node:updateComponentAllocation  # onlyOwner, onlyWhenNotRebalancing
Node:updateTargetReserveRatio  # onlyOwner, onlyWhenNotRebalancing
Node:updateTotalAssets  # onlyOwnerOrRebalancer, nonReentrant
Node:withdraw  # nonReentrant
NodeFactory:deployFullNode
NodeRegistry:addNode  # onlyFactory
NodeRegistry:initialize  # initializer
NodeRegistry:renounceOwnership  # onlyOwner
NodeRegistry:setPoliciesRoot  # onlyOwner
NodeRegistry:setProtocolExecutionFee  # onlyOwner
NodeRegistry:setProtocolFeeAddress  # onlyOwner
NodeRegistry:setProtocolManagementFee  # onlyOwner
NodeRegistry:setProtocolMaxSwingFactor  # onlyOwner
NodeRegistry:setRegistryType  # onlyOwner
NodeRegistry:transferOwnership  # onlyOwner
NodeRegistry:upgradeToAndCall  # onlyProxy, payable
OneInchV6RouterV1:batchSetWhitelistStatus  # onlyRegistryOwner
OneInchV6RouterV1:setBlacklistStatus  # onlyRegistryOwner
OneInchV6RouterV1:setExecutorWhitelistStatus  # onlyRegistryOwner
OneInchV6RouterV1:setIncentiveWhitelistStatus  # onlyRegistryOwner
OneInchV6RouterV1:setTolerance  # onlyRegistryOwner
OneInchV6RouterV1:setWhitelistStatus  # onlyRegistryOwner
OneInchV6RouterV1:swap  # nonReentrant, onlyNodeRebalancer
```

## Functions by Access Level

### Public Functions (No Modifiers) - 13 total

These are the primary targets for fuzzing:

- `DigiftAdapter.approve`
- `DigiftAdapter.deposit`
- `DigiftAdapter.redeem`
- `DigiftAdapter.setOperator`
- `DigiftAdapter.transfer`
- `DigiftAdapter.transferFrom`
- `DigiftEventVerifier.verifySettlementEvent`
- `Node.approve`
- `Node.multicall`
- `Node.submitPolicyData`
- `Node.transfer`
- `Node.transferFrom`
- `NodeFactory.deployFullNode`

### Payable Functions - 2 total

These functions can receive ETH:

- `BeaconProxy.fallback`
- `NodeRegistry.upgradeToAndCall`

### Restricted Functions - 94 total

These require special permissions:

- `DigiftAdapter.forceUpdateLastPrice` [onlyRegistryOwner]
- `DigiftAdapter.forwardRequestsToDigift` [onlyManager, nonReentrant]
- `DigiftAdapter.initialize` [initializer]
- `DigiftAdapter.mint` [onlyWhitelistedNode, actionValidation, nonReentrant]
- `DigiftAdapter.requestDeposit` [onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant]
- `DigiftAdapter.requestRedeem` [onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant]
- `DigiftAdapter.setManager` [onlyRegistryOwner]
- `DigiftAdapter.setMinDepositAmount` [onlyRegistryOwner]
- `DigiftAdapter.setMinRedeemAmount` [onlyRegistryOwner]
- `DigiftAdapter.setNode` [onlyRegistryOwner]
- `DigiftAdapter.setPriceDeviation` [onlyRegistryOwner]
- `DigiftAdapter.setPriceUpdateDeviation` [onlyRegistryOwner]
- `DigiftAdapter.setSettlementDeviation` [onlyRegistryOwner]
- `DigiftAdapter.settleDeposit` [nonReentrant, onlyManager]
- `DigiftAdapter.settleRedeem` [nonReentrant, onlyManager]
- `DigiftAdapter.updateLastPrice` [onlyManager]
- `DigiftAdapter.withdraw` [onlyWhitelistedNode, actionValidation, nonReentrant]
- `DigiftAdapterFactory.deploy` [onlyOwner]
- `DigiftAdapterFactory.renounceOwnership` [onlyOwner]
- `DigiftAdapterFactory.transferOwnership` [onlyOwner]
- `DigiftAdapterFactory.upgradeTo` [onlyOwner]
- `DigiftEventVerifier.setBlockHash` [onlyRegistryOwner]
- `DigiftEventVerifier.setWhitelist` [onlyRegistryOwner]
- `ERC4626Router.batchSetWhitelistStatus` [onlyRegistryOwner]
- `ERC4626Router.fulfillRedeemRequest` [nonReentrant, onlyNodeRebalancer, onlyNodeComponent]
- `ERC4626Router.invest` [nonReentrant, onlyNodeRebalancer, onlyNodeComponent]
- `ERC4626Router.liquidate` [nonReentrant, onlyNodeRebalancer, onlyNodeComponent]
- `ERC4626Router.setBlacklistStatus` [onlyRegistryOwner]
- `ERC4626Router.setTolerance` [onlyRegistryOwner]
- `ERC4626Router.setWhitelistStatus` [onlyRegistryOwner]
- `ERC7540Router.batchSetWhitelistStatus` [onlyRegistryOwner]
- `ERC7540Router.executeAsyncWithdrawal` [nonReentrant, onlyNodeRebalancer, onlyNodeComponent]
- `ERC7540Router.fulfillRedeemRequest` [nonReentrant, onlyNodeRebalancer, onlyNodeComponent]
- `ERC7540Router.investInAsyncComponent` [onlyNodeRebalancer, onlyNodeComponent]
- `ERC7540Router.mintClaimableShares` [nonReentrant, onlyNodeRebalancer, onlyNodeComponent]
- `ERC7540Router.requestAsyncWithdrawal` [onlyNodeRebalancer, onlyNodeComponent]
- `ERC7540Router.setBlacklistStatus` [onlyRegistryOwner]
- `ERC7540Router.setTolerance` [onlyRegistryOwner]
- `ERC7540Router.setWhitelistStatus` [onlyRegistryOwner]
- `FluidRewardsRouter.claim` [nonReentrant, onlyNodeRebalancer]
- `IncentraRouter.claim` [nonReentrant, onlyNodeRebalancer]
- `MerklRouter.claim` [nonReentrant, onlyNodeRebalancer]
- `Node.addComponent` [onlyOwner, onlyWhenNotRebalancing]
- `Node.addPolicies` [onlyOwner]
- `Node.addRebalancer` [onlyOwner]
- `Node.addRouter` [onlyOwner]
- `Node.deposit` [nonReentrant]
- `Node.enableSwingPricing` [onlyOwner]
- `Node.execute` [onlyRouter, nonReentrant, onlyWhenRebalancing]
- `Node.finalizeRedemption` [onlyRouter, nonReentrant]
- `Node.fulfillRedeemFromReserve` [onlyRebalancer, onlyWhenRebalancing, nonReentrant]
- `Node.initialize` [initializer]
- `Node.mint` [nonReentrant]
- `Node.payManagementFees` [nonReentrant, onlyOwnerOrRebalancer, onlyWhenNotRebalancing]
- `Node.redeem` [nonReentrant]
- `Node.removeComponent` [onlyOwner, onlyWhenNotRebalancing]
- `Node.removePolicies` [onlyOwner]
- `Node.removeRebalancer` [onlyOwner]
- `Node.removeRouter` [onlyOwner]
- `Node.renounceOwnership` [onlyOwner]
- `Node.requestRedeem` [nonReentrant]
- `Node.rescueTokens` [onlyOwner]
- `Node.setAnnualManagementFee` [onlyOwner]
- `Node.setLiquidationQueue` [onlyOwner]
- `Node.setMaxDepositSize` [onlyOwner]
- `Node.setNodeOwnerFeeAddress` [onlyOwner]
- `Node.setOperator` [nonReentrant]
- `Node.setQuoter` [onlyOwner]
- `Node.setRebalanceCooldown` [onlyOwner]
- `Node.setRebalanceWindow` [onlyOwner]
- `Node.startRebalance` [onlyRebalancer, nonReentrant]
- `Node.subtractProtocolExecutionFee` [onlyRouter, nonReentrant]
- `Node.transferOwnership` [onlyOwner]
- `Node.updateComponentAllocation` [onlyOwner, onlyWhenNotRebalancing]
- `Node.updateTargetReserveRatio` [onlyOwner, onlyWhenNotRebalancing]
- `Node.updateTotalAssets` [onlyOwnerOrRebalancer, nonReentrant]
- `Node.withdraw` [nonReentrant]
- `NodeRegistry.addNode` [onlyFactory]
- `NodeRegistry.initialize` [initializer]
- `NodeRegistry.renounceOwnership` [onlyOwner]
- `NodeRegistry.setPoliciesRoot` [onlyOwner]
- `NodeRegistry.setProtocolExecutionFee` [onlyOwner]
- `NodeRegistry.setProtocolFeeAddress` [onlyOwner]
- `NodeRegistry.setProtocolManagementFee` [onlyOwner]
- `NodeRegistry.setProtocolMaxSwingFactor` [onlyOwner]
- `NodeRegistry.setRegistryType` [onlyOwner]
- `NodeRegistry.transferOwnership` [onlyOwner]
- `OneInchV6RouterV1.batchSetWhitelistStatus` [onlyRegistryOwner]
- `OneInchV6RouterV1.setBlacklistStatus` [onlyRegistryOwner]
- `OneInchV6RouterV1.setExecutorWhitelistStatus` [onlyRegistryOwner]
- `OneInchV6RouterV1.setIncentiveWhitelistStatus` [onlyRegistryOwner]
- `OneInchV6RouterV1.setTolerance` [onlyRegistryOwner]
- `OneInchV6RouterV1.setWhitelistStatus` [onlyRegistryOwner]
- `OneInchV6RouterV1.swap` [nonReentrant, onlyNodeRebalancer]

## Fuzzing Configuration Example

### Echidna Configuration

```yaml
# echidna.yaml
testMode: assertion
multi-abi: true
corpusDir: "echidna-corpus"
coverage: true

# Contracts to test
contracts:
  - BeaconProxy
  - DigiftAdapter
  - DigiftAdapterFactory
  - DigiftEventVerifier
  - ERC4626Router
  - ERC7540Router
  - FluidRewardsRouter
  - IncentraRouter
  - MerklRouter
  - Node
  - NodeFactory
  - NodeRegistry
  - OneInchV6RouterV1
```

## Notes

- Functions with access control modifiers are included with modifiers shown as comments
- Contracts with parsing errors may still contain valid functions that can be fuzzed
- Contracts with compilation errors need to be fixed before fuzzing
- Libraries are typically not fuzzed directly as they contain internal functions
- Focus fuzzing efforts on functions that handle user funds, state changes, or critical logic

---
*Generated by entryPoints.py*
