# Categorized Entry Points

## Category 1: End User Functions
**Functions that are directly accessible to end users (depositors, vault token holders)**

### Node (src/Node.sol)
- **approve** - ERC20 approval for vault shares
- **deposit** [nonReentrant] - Deposit assets into vault
- **mint** [nonReentrant] - Mint vault shares
- **multicall** - Batch multiple calls in one transaction
- **redeem** [nonReentrant] - Redeem vault shares for assets
- **requestRedeem** [nonReentrant] - Request async redemption
- **setOperator** [nonReentrant] - Set operator for ERC7540
- **submitPolicyData** - Submit data for policy validation
- **transfer** - ERC20 transfer of vault shares
- **transferFrom** - ERC20 transferFrom of vault shares
- **withdraw** [nonReentrant] - Withdraw assets from vault

### DigiftAdapter (src/adapters/digift/DigiftAdapter.sol)
- **approve** - ERC20 approval for adapter shares
- **transfer** - ERC20 transfer of adapter shares
- **transferFrom** - ERC20 transferFrom of adapter shares

### DigiftEventVerifier (src/adapters/digift/DigiftEventVerifier.sol)
- **verifySettlementEvent** - Public function to verify Digift settlement events (callable by anyone for verification)

### NodeFactory (src/NodeFactory.sol)
- **deployFullNode** - Public function to deploy a new node (permissionless deployment)

---

## Category 2: Protocol Owner & Admin Functions
**Functions that should be managed by protocol owners, registry owners, node owners, or authorized managers**

### Node Owner Functions (onlyOwner)

#### Node (src/Node.sol)
- **addComponent** [onlyOwner, onlyWhenNotRebalancing] - Add new component to node
- **addPolicies** [onlyOwner] - Add policy contracts
- **addRebalancer** [onlyOwner] - Authorize rebalancer address
- **addRouter** [onlyOwner] - Add router contract
- **enableSwingPricing** [onlyOwner] - Enable/disable swing pricing
- **removeComponent** [onlyOwner, onlyWhenNotRebalancing] - Remove component from node
- **removePolicies** [onlyOwner] - Remove policy contracts
- **removeRebalancer** [onlyOwner] - Revoke rebalancer authorization
- **removeRouter** [onlyOwner] - Remove router contract
- **renounceOwnership** [onlyOwner] - Renounce node ownership
- **rescueTokens** [onlyOwner] - Rescue stuck tokens
- **setAnnualManagementFee** [onlyOwner] - Set management fee rate
- **setLiquidationQueue** [onlyOwner] - Set component liquidation order
- **setMaxDepositSize** [onlyOwner] - Set maximum deposit limit
- **setNodeOwnerFeeAddress** [onlyOwner] - Set fee recipient address
- **setQuoter** [onlyOwner] - Set quoter contract
- **setRebalanceCooldown** [onlyOwner] - Set rebalance cooldown period
- **setRebalanceWindow** [onlyOwner] - Set rebalance window duration
- **transferOwnership** [onlyOwner] - Transfer node ownership
- **updateComponentAllocation** [onlyOwner, onlyWhenNotRebalancing] - Update component weights
- **updateTargetReserveRatio** [onlyOwner, onlyWhenNotRebalancing] - Update reserve target

#### DigiftAdapterFactory (src/adapters/digift/DigiftAdapterFactory.sol)
- **deploy** [onlyOwner] - Deploy new adapter instance
- **renounceOwnership** [onlyOwner] - Renounce factory ownership
- **transferOwnership** [onlyOwner] - Transfer factory ownership
- **upgradeTo** [onlyOwner] - Upgrade adapter implementation

### Registry Owner Functions (onlyRegistryOwner)

#### DigiftAdapter (src/adapters/digift/DigiftAdapter.sol)
- **forceUpdateLastPrice** [onlyRegistryOwner] - Force price update without validation
- **setManager** [onlyRegistryOwner] - Whitelist/unwhitelist managers
- **setMinDepositAmount** [onlyRegistryOwner] - Set minimum deposit threshold
- **setMinRedeemAmount** [onlyRegistryOwner] - Set minimum redeem threshold
- **setNode** [onlyRegistryOwner] - Whitelist/unwhitelist nodes
- **setPriceDeviation** [onlyRegistryOwner] - Set price deviation threshold
- **setPriceUpdateDeviation** [onlyRegistryOwner] - Set price update time limit
- **setSettlementDeviation** [onlyRegistryOwner] - Set settlement deviation threshold

#### DigiftEventVerifier (src/adapters/digift/DigiftEventVerifier.sol)
- **setBlockHash** [onlyRegistryOwner] - Set trusted block hash for verification
- **setWhitelist** [onlyRegistryOwner] - Whitelist event verifier addresses

#### ERC4626Router (src/routers/ERC4626Router.sol)
- **batchSetWhitelistStatus** [onlyRegistryOwner] - Batch whitelist components
- **setBlacklistStatus** [onlyRegistryOwner] - Blacklist/unblacklist components
- **setTolerance** [onlyRegistryOwner] - Set slippage tolerance
- **setWhitelistStatus** [onlyRegistryOwner] - Whitelist/unwhitelist components

#### ERC7540Router (src/routers/ERC7540Router.sol)
- **batchSetWhitelistStatus** [onlyRegistryOwner] - Batch whitelist components
- **setBlacklistStatus** [onlyRegistryOwner] - Blacklist/unblacklist components
- **setTolerance** [onlyRegistryOwner] - Set slippage tolerance
- **setWhitelistStatus** [onlyRegistryOwner] - Whitelist/unwhitelist components

#### OneInchV6RouterV1 (src/routers/OneInchV6RouterV1.sol)
- **batchSetWhitelistStatus** [onlyRegistryOwner] - Batch whitelist components
- **setBlacklistStatus** [onlyRegistryOwner] - Blacklist/unblacklist components
- **setExecutorWhitelistStatus** [onlyRegistryOwner] - Whitelist 1inch executor
- **setIncentiveWhitelistStatus** [onlyRegistryOwner] - Whitelist incentive contracts
- **setTolerance** [onlyRegistryOwner] - Set slippage tolerance
- **setWhitelistStatus** [onlyRegistryOwner] - Whitelist/unwhitelist components

#### NodeRegistry (src/NodeRegistry.sol)
- **renounceOwnership** [onlyOwner] - Renounce registry ownership
- **setPoliciesRoot** [onlyOwner] - Set merkle root for policies
- **setProtocolExecutionFee** [onlyOwner] - Set protocol execution fee
- **setProtocolFeeAddress** [onlyOwner] - Set protocol fee recipient
- **setProtocolManagementFee** [onlyOwner] - Set protocol management fee
- **setProtocolMaxSwingFactor** [onlyOwner] - Set max swing pricing factor
- **setRegistryType** [onlyOwner] - Set registry type mapping
- **transferOwnership** [onlyOwner] - Transfer registry ownership
- **upgradeToAndCall** [onlyProxy, payable] - Upgrade registry implementation

### Mixed Owner/Rebalancer Functions

#### Node (src/Node.sol)
- **payManagementFees** [nonReentrant, onlyOwnerOrRebalancer, onlyWhenNotRebalancing] - Collect management fees
- **updateTotalAssets** [onlyOwnerOrRebalancer, nonReentrant] - Update cached total assets

---

## Category 3: Internal Protocol Functions
**Functions that should NOT be called externally - restricted to whitelisted nodes, routers, rebalancers, or internal protocol components**

### Whitelisted Node Functions (onlyWhitelistedNode)
**These are internal protocol functions for authorized node contracts to interact with adapters**

#### DigiftAdapter (src/adapters/digift/DigiftAdapter.sol)
- **mint** [onlyWhitelistedNode, actionValidation, nonReentrant] - Claim shares after deposit settlement
- **requestDeposit** [onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant] - Node requests deposit
- **requestRedeem** [onlyWhitelistedNode, nothingPending, actionValidation, nonReentrant] - Node requests redemption
- **withdraw** [onlyWhitelistedNode, actionValidation, nonReentrant] - Claim assets after redeem settlement

### Manager Functions (onlyManager)
**Internal functions for whitelisted protocol managers to execute settlements**

#### DigiftAdapter (src/adapters/digift/DigiftAdapter.sol)
- **forwardRequestsToDigift** [onlyManager, nonReentrant] - Forward batched requests to Digift
- **settleDeposit** [nonReentrant, onlyManager] - Settle deposit requests with Digift
- **settleRedeem** [nonReentrant, onlyManager] - Settle redeem requests with Digift
- **updateLastPrice** [onlyManager] - Update price cache with validation

### Rebalancer Functions (onlyRebalancer)
**Internal functions for authorized rebalancers to manage node operations**

#### Node (src/Node.sol)
- **fulfillRedeemFromReserve** [onlyRebalancer, onlyWhenRebalancing, nonReentrant] - Fulfill redemption from reserve
- **startRebalance** [onlyRebalancer, nonReentrant] - Initiate rebalance window

### Router Functions (onlyRouter, onlyNodeRebalancer)
**Internal functions restricted to router contracts and node rebalancers**

#### Node (src/Node.sol)
- **execute** [onlyRouter, nonReentrant, onlyWhenRebalancing] - Execute router operations
- **finalizeRedemption** [onlyRouter, nonReentrant] - Finalize user redemption
- **subtractProtocolExecutionFee** [onlyRouter, nonReentrant] - Deduct protocol fee

#### ERC4626Router (src/routers/ERC4626Router.sol)
- **fulfillRedeemRequest** [nonReentrant, onlyNodeRebalancer, onlyNodeComponent] - Liquidate component for redemption
- **invest** [nonReentrant, onlyNodeRebalancer, onlyNodeComponent] - Invest in ERC4626 component
- **liquidate** [nonReentrant, onlyNodeRebalancer, onlyNodeComponent] - Liquidate ERC4626 component

#### ERC7540Router (src/routers/ERC7540Router.sol)
- **executeAsyncWithdrawal** [nonReentrant, onlyNodeRebalancer, onlyNodeComponent] - Execute async withdrawal
- **fulfillRedeemRequest** [nonReentrant, onlyNodeRebalancer, onlyNodeComponent] - Fulfill redemption from component
- **investInAsyncComponent** [onlyNodeRebalancer, onlyNodeComponent] - Invest in async component
- **mintClaimableShares** [nonReentrant, onlyNodeRebalancer, onlyNodeComponent] - Mint claimable shares
- **requestAsyncWithdrawal** [onlyNodeRebalancer, onlyNodeComponent] - Request async withdrawal

#### OneInchV6RouterV1 (src/routers/OneInchV6RouterV1.sol)
- **swap** [nonReentrant, onlyNodeRebalancer] - Execute token swap via 1inch

#### FluidRewardsRouter (src/routers/FluidRewardsRouter.sol)
- **claim** [nonReentrant, onlyNodeRebalancer] - Claim Fluid rewards

#### IncentraRouter (src/routers/IncentraRouter.sol)
- **claim** [nonReentrant, onlyNodeRebalancer] - Claim Incentra rewards

#### MerklRouter (src/routers/MerklRouter.sol)
- **claim** [nonReentrant, onlyNodeRebalancer] - Claim Merkl rewards

### Factory Functions (onlyFactory)
**Internal functions restricted to factory contract**

#### NodeRegistry (src/NodeRegistry.sol)
- **addNode** [onlyFactory] - Register new node in registry
- **initialize** [initializer] - Initialize registry (one-time setup)

### Initialization Functions
**One-time setup functions that cannot be called again after initialization**

#### DigiftAdapter (src/adapters/digift/DigiftAdapter.sol)
- **initialize** [initializer] - Initialize adapter (one-time setup)

#### Node (src/Node.sol)
- **initialize** [initializer] - Initialize node (one-time setup)

#### NodeRegistry (src/NodeRegistry.sol)
- **initialize** [initializer] - Initialize registry (one-time setup)

### Proxy Fallback Functions

#### BeaconProxy (lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol)
- **fallback** [payable] - Proxy fallback for delegate calls

---

## Excluded Functions
**Functions that are implemented but always revert as `Unsupported()` - not actual entry points**

### DigiftAdapter (src/adapters/digift/DigiftAdapter.sol)
Note: The entry points file already excludes these, but for completeness:
- deposit (both overloads) - Unsupported, use requestDeposit instead
- mint (single-param version) - Unsupported, use 3-param version
- redeem - Unsupported, use requestRedeem instead
- previewDeposit/previewMint/previewWithdraw/previewRedeem - Unsupported
- maxDeposit/maxRedeem - Unsupported
- setOperator/isOperator - Unsupported

---

## Summary by Category

- **Category 1 (End User)**: 16 functions across 4 contracts
- **Category 2 (Owner/Admin)**: 59 functions across 7 contracts
- **Category 3 (Internal Protocol)**: 31 functions across 10 contracts

**Total Active Entry Points**: 106 functions
