# Echidna Coverage Report

**Generated:** 2025-11-04 16:49:24
**Coverage File:** `echidna-corpus/covered.1762271321.txt`
**Timestamp:** 1762271321

## 📊 Overall Summary

| Metric | Value |
|--------|-------|
| **Total Contracts** | 20 |
| **Contracts Below 70%** | 17 |
| **Overall Line Coverage** | 6.81% |
| **Total Lines** | 6059 |
| **Covered Lines** | 413 |

⚠️ **Status:** 17 contract(s) below 70% coverage threshold

## 🔍 Coverage Analysis Against Scope

✅ All contracts in scope have coverage data.

## 📋 Contracts Coverage by Package

### 📦 Package:  src

| Contract | Coverage | Status | Functions | Details |
|----------|----------|--------|-----------|---------|
| 🔴 **Escrow** | 0% | ❌ Fail | 0 | [View](#escrow) |
| 🟡 **Node** | 67.66% | ❌ Fail | 45 | [View](#node) |
| 🟢 **NodeFactory** | 75% | ✅ Pass | 1 | [View](#nodefactory) |
| 🟢 **NodeRegistry** | 93.48% | ✅ Pass | 13 | [View](#noderegistry) |
| 🟡 **ERC4626Router** | 68.09% | ❌ Fail | 6 | [View](#erc4626router) |
| 🟠 **ERC7540Router** | 41.18% | ❌ Fail | 10 | [View](#erc7540router) |
| 🔴 **FluidRewardsRouter** | 20% | ❌ Fail | 1 | [View](#fluidrewardsrouter) |
| 🔴 **IncentraRouter** | 25% | ❌ Fail | 1 | [View](#incentrarouter) |
| 🔴 **MerklRouter** | 20% | ❌ Fail | 1 | [View](#merklrouter) |
| 🔴 **OneInchV6RouterV1** | 19.35% | ❌ Fail | 3 | [View](#oneinchv6routerv1) |
| 🔴 **QuoterV1** | 0% | ❌ Fail | 0 | [View](#quoterv1) |
| 🟡 **BaseComponentRouter** | 62.16% | ❌ Fail | 7 | [View](#basecomponentrouter) |
| 🔴 **BaseQuoter** | 0% | ❌ Fail | 0 | [View](#basequoter) |
| 🔴 **ErrorsLib** | 0% | ❌ Fail | 0 | [View](#errorslib) |
| 🔴 **EventsLib** | 0% | ❌ Fail | 0 | [View](#eventslib) |
| 🔴 **MathLib** | 0% | ❌ Fail | 0 | [View](#mathlib) |
| 🔴 **RegistryAccessControl** | 0% | ❌ Fail | 0 | [View](#registryaccesscontrol) |
| 🟠 **DigiftAdapter** | 42.94% | ❌ Fail | 22 | [View](#digiftadapter) |
| 🟢 **DigiftAdapterFactory** | 100% | ✅ Pass | 1 | [View](#digiftadapterfactory) |
| 🟠 **DigiftEventVerifier** | 30% | ❌ Fail | 4 | [View](#digifteventverifier) |



## 🔍 Detailed Contract Analysis

### Escrow

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: src/Escrow.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 0      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 0      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 0      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 0      │
└────────────────────────────┴────────┘

❌ Warning: Coverage 0% below threshold 70%
```

</details>

### Node

**Coverage:** 67.66%
`█████████████████████████████████░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 45 |
| Line Coverage | 67.66% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `addPolicies` | false | false | 1 |
| 1 | `removePolicies` | false | false | 1 |
| 2 | `removeComponent` | false | false | 7 |
| 3 | `removeRouter` | false | false | 3 |
| 4 | `addRebalancer` | true | false | 1 |
| 5 | `removeRebalancer` | false | false | 3 |
| 6 | `setNodeOwnerFeeAddress` | false | false | 4 |
| 7 | `rescueTokens` | false | false | 4 |
| 8 | `_payManagementFees` | true | false | 1 |
| 9 | `subtractProtocolExecutionFee` | true | false | 4 |
| 10 | `fulfillRedeemFromReserve` | true | false | 1 |
| 11 | `finalizeRedemption` | false | false | 2 |
| 12 | `requestRedeem` | true | false | 3 |
| 13 | `deposit` | true | false | 2 |
| 14 | `mint` | true | false | 3 |
| 15 | `withdraw` | true | false | 12 |
| 16 | `redeem` | true | false | 12 |
| 17 | `transfer` | true | false | 1 |
| 18 | `_fulfillRedeemFromReserve` | true | false | 8 |
| 19 | `_finalizeRedemption` | false | false | 11 |
| 20 | `_validateOwner` | true | false | 2 |
| 21 | `_runPolicies` | true | false | 1 |

## 🔍 Uncovered Code Lines

### Function: `addPolicies`

```solidity
❌ Untouched lines:
```

```solidity
NodeLib.addPolicies(registry, policies, sigPolicy, proof, proofFlags, sigs, policies_);
```

### Function: `removePolicies`

```solidity
❌ Untouched lines:
```

```solidity
NodeLib.removePolicies(policies, sigPolicy, sigs, policies_);
```

### Function: `removeComponent`

```solidity
❌ Untouched lines:
```

```solidity
if (!_isComponent(component)) revert ErrorsLib.NotSet();
```

```solidity
address router = componentAllocations[component].router;
```

```solidity
revert ErrorsLib.NonZeroBalance();
```

```solidity
revert ErrorsLib.NotBlacklisted();
```

```solidity
NodeLib.remove(components, component);
```

```solidity
delete componentAllocations[component];
```

```solidity
emit EventsLib.ComponentRemoved(component);
```

### Function: `removeRouter`

```solidity
❌ Untouched lines:
```

```solidity
if (!isRouter[oldRouter]) revert ErrorsLib.NotSet();
```

```solidity
isRouter[oldRouter] = false;
```

```solidity
emit EventsLib.RouterRemoved(oldRouter);
```

### Function: `addRebalancer`

```solidity
❌ Untouched lines:
```

```solidity
revert ErrorsLib.NotWhitelisted();
```

### Function: `removeRebalancer`

```solidity
❌ Untouched lines:
```

```solidity
if (!isRebalancer[oldRebalancer]) revert ErrorsLib.NotSet();
```

```solidity
isRebalancer[oldRebalancer] = false;
```

```solidity
emit EventsLib.RebalancerRemoved(oldRebalancer);
```

### Function: `setNodeOwnerFeeAddress`

```solidity
❌ Untouched lines:
```

```solidity
_nonZeroAddress(newNodeOwnerFeeAddress);
```

```solidity
if (newNodeOwnerFeeAddress == nodeOwnerFeeAddress) revert ErrorsLib.AlreadySet();
```

```solidity
nodeOwnerFeeAddress = newNodeOwnerFeeAddress;
```

```solidity
emit EventsLib.NodeOwnerFeeAddressSet(newNodeOwnerFeeAddress);
```

### Function: `rescueTokens`

```solidity
❌ Untouched lines:
```

```solidity
if (token == asset) revert ErrorsLib.InvalidToken();
```

```solidity
if (_isComponent(token)) revert ErrorsLib.InvalidToken();
```

```solidity
IERC20(token).safeTransfer(recipient, amount);
```

```solidity
emit EventsLib.RescueTokens(token, recipient, amount);
```

### Function: `_payManagementFees`

```solidity
❌ Untouched lines:
```

```solidity
revert ErrorsLib.NotEnoughAssetsToPayFees(feeForPeriod, IERC20(asset).balanceOf(address(this)));
```

### Function: `subtractProtocolExecutionFee`

```solidity
❌ Untouched lines:
```

```solidity
cacheTotalAssets -= executionFee;
```

```solidity
IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), executionFee);
```

```solidity
_runPolicies();
```

```solidity
emit EventsLib.ExecutionFeeTaken(executionFee);
```

### Function: `fulfillRedeemFromReserve`

```solidity
❌ Untouched lines:
```

```solidity
_runPolicies();
```

### Function: `finalizeRedemption`

```solidity
❌ Untouched lines:
```

```solidity
_finalizeRedemption(controller, assetsToReturn, sharesPending, sharesAdjusted);
```

```solidity
_runPolicies();
```

### Function: `requestRedeem`

```solidity
❌ Untouched lines:
```

```solidity
uint256 adjustedAssets = quoter.calculateRedeemPenalty(
```

```solidity
shares, getCashAfterRedemptions(), totalAssets(), maxSwingFactor, targetReserveRatio
```

```solidity
adjustedShares = Math.min(convertToShares(adjustedAssets), shares);
```

### Function: `deposit`

```solidity
❌ Untouched lines:
```

```solidity
revert ErrorsLib.ExceedsMaxDeposit();
```

```solidity
return shares;
```

### Function: `mint`

```solidity
❌ Untouched lines:
```

```solidity
revert ErrorsLib.ExceedsMaxMint();
```

```solidity
_runPolicies();
```

```solidity
return assets;
```

### Function: `withdraw`

```solidity
❌ Untouched lines:
```

```solidity
_validateController(controller);
```

```solidity
Request storage request = requests[controller];
```

```solidity
uint256 maxAssets = maxWithdraw(controller);
```

```solidity
uint256 maxShares = maxRedeem(controller);
```

```solidity
if (assets > maxAssets) revert ErrorsLib.ExceedsMaxWithdraw();
```

```solidity
shares = Math.mulDiv(assets, maxShares, maxAssets, Math.Rounding.Ceil);
```

```solidity
request.claimableRedeemRequest -= shares;
```

```solidity
request.claimableAssets -= assets;
```

```solidity
IERC20(asset).safeTransferFrom(escrow, receiver, assets);
```

```solidity
_runPolicies();
```

```solidity
emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
```

```solidity
return shares;
```

### Function: `redeem`

```solidity
❌ Untouched lines:
```

```solidity
_validateController(controller);
```

```solidity
Request storage request = requests[controller];
```

```solidity
uint256 maxAssets = maxWithdraw(controller);
```

```solidity
uint256 maxShares = maxRedeem(controller);
```

```solidity
if (shares > maxShares) revert ErrorsLib.ExceedsMaxRedeem();
```

```solidity
assets = Math.mulDiv(shares, maxAssets, maxShares);
```

```solidity
request.claimableRedeemRequest -= shares;
```

```solidity
request.claimableAssets -= assets;
```

```solidity
IERC20(asset).safeTransferFrom(escrow, receiver, assets);
```

```solidity
_runPolicies();
```

```solidity
emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
```

```solidity
return assets;
```

### Function: `transfer`

```solidity
❌ Untouched lines:
```

```solidity
_runPolicies();
```

### Function: `_fulfillRedeemFromReserve`

```solidity
❌ Untouched lines:
```

```solidity
uint256 balance = Math.max(IERC20(asset).balanceOf(address(this)), 1);
```

```solidity
uint256 assetsToReturn = convertToAssets(request.sharesAdjusted);
```

```solidity
uint256 sharesPending = request.pendingRedeemRequest;
```

```solidity
uint256 sharesAdjusted = request.sharesAdjusted;
```

```solidity
sharesPending = (sharesPending * balance - 1) / assetsToReturn + 1;
```

```solidity
sharesAdjusted = (sharesAdjusted * balance - 1) / assetsToReturn + 1;
```

```solidity
assetsToReturn = balance;
```

```solidity
_finalizeRedemption(controller, assetsToReturn, sharesPending, sharesAdjusted);
```

### Function: `_finalizeRedemption`

```solidity
❌ Untouched lines:
```

```solidity
Request storage request = requests[controller];
```

```solidity
_burn(escrow, sharesPending);
```

```solidity
request.pendingRedeemRequest -= sharesPending;
```

```solidity
request.claimableRedeemRequest += sharesPending;
```

```solidity
request.claimableAssets += assetsToReturn;
```

```solidity
request.sharesAdjusted -= sharesAdjusted;
```

```solidity
sharesExiting -= sharesAdjusted;
```

```solidity
cacheTotalAssets -= assetsToReturn;
```

```solidity
revert ErrorsLib.ExceedsAvailableReserve();
```

```solidity
IERC20(asset).safeTransfer(escrow, assetsToReturn);
```

```solidity
emit EventsLib.RedeemClaimable(controller, REQUEST_ID, assetsToReturn, sharesPending);
```

### Function: `_validateOwner`

```solidity
❌ Untouched lines:
```

```solidity
revert ErrorsLib.InvalidOwner();
```

```solidity
_spendAllowance(owner, msg.sender, shares);
```

### Function: `_runPolicies`

```solidity
❌ Untouched lines:
```

```solidity
IPolicy(policies_[i]).onCheck(msg.sender, msg.data);
```

```solidity
❌ Warning: Coverage 67.66% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: src/Node.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 45     │
│ fullyCoveredFunctions      │ 23     │
│ coveredLines               │ 182    │
│ revertedLines              │ 0      │
│ untouchedLines             │ 87     │
│ functionCoveragePercentage │ 51.11  │
│ lineCoveragePercentage     │ 67.66  │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬────────────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName                   │ touched │ reverted │ untouchedLines │
├─────────┼────────────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'addPolicies'                  │ false   │ false    │ 1              │
│ 1       │ 'removePolicies'               │ false   │ false    │ 1              │
│ 2       │ 'removeComponent'              │ false   │ false    │ 7              │
│ 3       │ 'removeRouter'                 │ false   │ false    │ 3              │
│ 4       │ 'addRebalancer'                │ true    │ false    │ 1              │
│ 5       │ 'removeRebalancer'             │ false   │ false    │ 3              │
│ 6       │ 'setNodeOwnerFeeAddress'       │ false   │ false    │ 4              │
│ 7       │ 'rescueTokens'                 │ false   │ false    │ 4              │
│ 8       │ '_payManagementFees'           │ true    │ false    │ 1              │
│ 9       │ 'subtractProtocolExecutionFee' │ true    │ false    │ 4              │
│ 10      │ 'fulfillRedeemFromReserve'     │ true    │ false    │ 1              │
│ 11      │ 'finalizeRedemption'           │ false   │ false    │ 2              │
│ 12      │ 'requestRedeem'                │ true    │ false    │ 3              │
│ 13      │ 'deposit'                      │ true    │ false    │ 2              │
│ 14      │ 'mint'                         │ true    │ false    │ 3              │
│ 15      │ 'withdraw'                     │ true    │ false    │ 12             │
│ 16      │ 'redeem'                       │ true    │ false    │ 12             │
│ 17      │ 'transfer'                     │ true    │ false    │ 1              │
│ 18      │ '_fulfillRedeemFromReserve'    │ true    │ false    │ 8              │
│ 19      │ '_finalizeRedemption'          │ false   │ false    │ 11             │
│ 20      │ '_validateOwner'               │ true    │ false    │ 2              │
│ 21      │ '_runPolicies'                 │ true    │ false    │ 1              │
└─────────┴────────────────────────────────┴─────────┴──────────┴────────────────┘

Function: addPolicies
❌ Untouched lines:
NodeLib.addPolicies(registry, policies, sigPolicy, proof, proofFlags, sigs, policies_);

Function: removePolicies
❌ Untouched lines:
NodeLib.removePolicies(policies, sigPolicy, sigs, policies_);

Function: removeComponent
❌ Untouched lines:
if (!_isComponent(component)) revert ErrorsLib.NotSet();
address router = componentAllocations[component].router;
revert ErrorsLib.NonZeroBalance();
revert ErrorsLib.NotBlacklisted();
NodeLib.remove(components, component);
delete componentAllocations[component];
emit EventsLib.ComponentRemoved(component);

Function: removeRouter
❌ Untouched lines:
if (!isRouter[oldRouter]) revert ErrorsLib.NotSet();
isRouter[oldRouter] = false;
emit EventsLib.RouterRemoved(oldRouter);

Function: addRebalancer
❌ Untouched lines:
revert ErrorsLib.NotWhitelisted();

Function: removeRebalancer
❌ Untouched lines:
if (!isRebalancer[oldRebalancer]) revert ErrorsLib.NotSet();
isRebalancer[oldRebalancer] = false;
emit EventsLib.RebalancerRemoved(oldRebalancer);

Function: setNodeOwnerFeeAddress
❌ Untouched lines:
_nonZeroAddress(newNodeOwnerFeeAddress);
if (newNodeOwnerFeeAddress == nodeOwnerFeeAddress) revert ErrorsLib.AlreadySet();
nodeOwnerFeeAddress = newNodeOwnerFeeAddress;
emit EventsLib.NodeOwnerFeeAddressSet(newNodeOwnerFeeAddress);

Function: rescueTokens
❌ Untouched lines:
if (token == asset) revert ErrorsLib.InvalidToken();
if (_isComponent(token)) revert ErrorsLib.InvalidToken();
IERC20(token).safeTransfer(recipient, amount);
emit EventsLib.RescueTokens(token, recipient, amount);

Function: _payManagementFees
❌ Untouched lines:
revert ErrorsLib.NotEnoughAssetsToPayFees(feeForPeriod, IERC20(asset).balanceOf(address(this)));

Function: subtractProtocolExecutionFee
❌ Untouched lines:
cacheTotalAssets -= executionFee;
IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), executionFee);
_runPolicies();
emit EventsLib.ExecutionFeeTaken(executionFee);

Function: fulfillRedeemFromReserve
❌ Untouched lines:
_runPolicies();

Function: finalizeRedemption
❌ Untouched lines:
_finalizeRedemption(controller, assetsToReturn, sharesPending, sharesAdjusted);
_runPolicies();

Function: requestRedeem
❌ Untouched lines:
uint256 adjustedAssets = quoter.calculateRedeemPenalty(
shares, getCashAfterRedemptions(), totalAssets(), maxSwingFactor, targetReserveRatio
adjustedShares = Math.min(convertToShares(adjustedAssets), shares);

Function: deposit
❌ Untouched lines:
revert ErrorsLib.ExceedsMaxDeposit();
return shares;

Function: mint
❌ Untouched lines:
revert ErrorsLib.ExceedsMaxMint();
_runPolicies();
return assets;

Function: withdraw
❌ Untouched lines:
_validateController(controller);
Request storage request = requests[controller];
uint256 maxAssets = maxWithdraw(controller);
uint256 maxShares = maxRedeem(controller);
if (assets > maxAssets) revert ErrorsLib.ExceedsMaxWithdraw();
shares = Math.mulDiv(assets, maxShares, maxAssets, Math.Rounding.Ceil);
request.claimableRedeemRequest -= shares;
request.claimableAssets -= assets;
IERC20(asset).safeTransferFrom(escrow, receiver, assets);
_runPolicies();
emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
return shares;

Function: redeem
❌ Untouched lines:
_validateController(controller);
Request storage request = requests[controller];
uint256 maxAssets = maxWithdraw(controller);
uint256 maxShares = maxRedeem(controller);
if (shares > maxShares) revert ErrorsLib.ExceedsMaxRedeem();
assets = Math.mulDiv(shares, maxAssets, maxShares);
request.claimableRedeemRequest -= shares;
request.claimableAssets -= assets;
IERC20(asset).safeTransferFrom(escrow, receiver, assets);
_runPolicies();
emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
return assets;

Function: transfer
❌ Untouched lines:
_runPolicies();

Function: _fulfillRedeemFromReserve
❌ Untouched lines:
uint256 balance = Math.max(IERC20(asset).balanceOf(address(this)), 1);
uint256 assetsToReturn = convertToAssets(request.sharesAdjusted);
uint256 sharesPending = request.pendingRedeemRequest;
uint256 sharesAdjusted = request.sharesAdjusted;
sharesPending = (sharesPending * balance - 1) / assetsToReturn + 1;
sharesAdjusted = (sharesAdjusted * balance - 1) / assetsToReturn + 1;
assetsToReturn = balance;
_finalizeRedemption(controller, assetsToReturn, sharesPending, sharesAdjusted);

Function: _finalizeRedemption
❌ Untouched lines:
Request storage request = requests[controller];
_burn(escrow, sharesPending);
request.pendingRedeemRequest -= sharesPending;
request.claimableRedeemRequest += sharesPending;
request.claimableAssets += assetsToReturn;
request.sharesAdjusted -= sharesAdjusted;
sharesExiting -= sharesAdjusted;
cacheTotalAssets -= assetsToReturn;
revert ErrorsLib.ExceedsAvailableReserve();
IERC20(asset).safeTransfer(escrow, assetsToReturn);
emit EventsLib.RedeemClaimable(controller, REQUEST_ID, assetsToReturn, sharesPending);

Function: _validateOwner
❌ Untouched lines:
revert ErrorsLib.InvalidOwner();
_spendAllowance(owner, msg.sender, shares);

Function: _runPolicies
❌ Untouched lines:
IPolicy(policies_[i]).onCheck(msg.sender, msg.data);

❌ Warning: Coverage 67.66% below threshold 70%
```

</details>

### NodeFactory

**Coverage:** 75%
`█████████████████████████████████████░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 75% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `invest` | true | false | 4 |
| 1 | `liquidate` | false | false | 4 |
| 2 | `fulfillRedeemRequest` | true | false | 5 |
| 3 | `_redeem` | false | false | 2 |

## 🔍 Uncovered Code Lines

```solidity
📄 File: routers/ERC4626Router.sol
```

```solidity
┌────────────────────────────┬────────┐
```

```solidity
├────────────────────────────┼────────┤
```

```solidity
└────────────────────────────┴────────┘
```

```solidity
⚠️ Not fully covered functions:
```

```solidity
┌─────────┬────────────────────────┬─────────┬──────────┬────────────────┐
```

```solidity
├─────────┼────────────────────────┼─────────┼──────────┼────────────────┤
```

```solidity
└─────────┴────────────────────────┴─────────┴──────────┴────────────────┘
```

### Function: `invest`

```solidity
❌ Untouched lines:
```

```solidity
revert ExceedsMaxComponentDeposit(component, depositAmount, IERC4626(component).maxDeposit(address(node)));
```

```solidity
revert InsufficientSharesReturned(component, 0, expectedShares);
```

```solidity
revert InsufficientSharesReturned(component, sharesReturned, expectedShares);
```

```solidity
revert InsufficientSharesReturned(component, sharesReturned, minSharesOut);
```

### Function: `liquidate`

```solidity
❌ Untouched lines:
```

```solidity
assetsReturned = _liquidate(node, component, shares);
```

```solidity
revert InsufficientAssetsReturned(component, assetsReturned, minAssetsOut);
```

```solidity
emit LiquidatedFromComponent(node, component, assetsReturned);
```

```solidity
return assetsReturned;
```

### Function: `fulfillRedeemRequest`

```solidity
❌ Untouched lines:
```

```solidity
(sharesPending, sharesAdjusted) =
```

```solidity
_calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested, sharesAdjusted);
```

```solidity
INode(node).finalizeRedemption(controller, assetsReturned, sharesPending, sharesAdjusted);
```

```solidity
emit FulfilledRedeemRequest(node, component, assetsReturned);
```

```solidity
return assetsReturned;
```

### Function: `_redeem`

```solidity
❌ Untouched lines:
```

```solidity
bytes memory result = INode(node).execute(component, abi.encodeCall(IERC4626.redeem, (shares, node, node)));
```

```solidity
return abi.decode(result, (uint256));
```

```solidity
❌ Warning: Coverage 68.09% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: routers/ERC4626Router.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 6      │
│ fullyCoveredFunctions      │ 2      │
│ coveredLines               │ 32     │
│ revertedLines              │ 0      │
│ untouchedLines             │ 15     │
│ functionCoveragePercentage │ 33.33  │
│ lineCoveragePercentage     │ 68.09  │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName           │ touched │ reverted │ untouchedLines │
├─────────┼────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'invest'               │ true    │ false    │ 4              │
│ 1       │ 'liquidate'            │ false   │ false    │ 4              │
│ 2       │ 'fulfillRedeemRequest' │ true    │ false    │ 5              │
│ 3       │ '_redeem'              │ false   │ false    │ 2              │
└─────────┴────────────────────────┴─────────┴──────────┴────────────────┘

Function: invest
❌ Untouched lines:
revert ExceedsMaxComponentDeposit(component, depositAmount, IERC4626(component).maxDeposit(address(node)));
revert InsufficientSharesReturned(component, 0, expectedShares);
revert InsufficientSharesReturned(component, sharesReturned, expectedShares);
revert InsufficientSharesReturned(component, sharesReturned, minSharesOut);

Function: liquidate
❌ Untouched lines:
assetsReturned = _liquidate(node, component, shares);
revert InsufficientAssetsReturned(component, assetsReturned, minAssetsOut);
emit LiquidatedFromComponent(node, component, assetsReturned);
return assetsReturned;

Function: fulfillRedeemRequest
❌ Untouched lines:
(sharesPending, sharesAdjusted) =
_calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested, sharesAdjusted);
INode(node).finalizeRedemption(controller, assetsReturned, sharesPending, sharesAdjusted);
emit FulfilledRedeemRequest(node, component, assetsReturned);
return assetsReturned;

Function: _redeem
❌ Untouched lines:
bytes memory result = INode(node).execute(component, abi.encodeCall(IERC4626.redeem, (shares, node, node)));
return abi.decode(result, (uint256));

❌ Warning: Coverage 68.09% below threshold 70%
```

</details>

### NodeRegistry

**Coverage:** 93.48%
`██████████████████████████████████████████████░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 13 |
| Line Coverage | 93.48% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `fulfillRedeemRequest` | false | false | 11 |
| 1 | `investInAsyncComponent` | true | false | 1 |
| 2 | `mintClaimableShares` | true | false | 5 |
| 3 | `requestAsyncWithdrawal` | false | false | 5 |
| 4 | `executeAsyncWithdrawal` | false | false | 1 |
| 5 | `_requestRedeem` | false | false | 5 |
| 6 | `_withdraw` | false | false | 2 |
| 7 | `_executeAsyncWithdrawal` | false | false | 10 |

## 🔍 Uncovered Code Lines

### Function: `fulfillRedeemRequest`

```solidity
❌ Untouched lines:
```

```solidity
(uint256 sharesPending,,, uint256 sharesAdjusted) = INode(node).requests(controller);
```

```solidity
uint256 assetsRequested = INode(node).convertToAssets(sharesAdjusted);
```

```solidity
INode(node).enforceLiquidationOrder(component, assetsRequested);
```

```solidity
uint256 maxClaimableRedeemRequest = IERC7540Redeem(component).claimableRedeemRequest(0, node);
```

```solidity
uint256 maxClaimableAssets = IERC7575(component).convertToAssets(maxClaimableRedeemRequest);
```

```solidity
assetsReturned = _executeAsyncWithdrawal(node, component, Math.min(assetsRequested, maxClaimableAssets));
```

```solidity
(sharesPending, sharesAdjusted) =
```

```solidity
_calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested, sharesAdjusted);
```

```solidity
INode(node).finalizeRedemption(controller, assetsReturned, sharesPending, sharesAdjusted);
```

```solidity
emit FulfilledRedeemRequest(node, component, assetsReturned);
```

```solidity
return assetsReturned;
```

### Function: `investInAsyncComponent`

```solidity
❌ Untouched lines:
```

```solidity
revert IncorrectRequestId(requestId);
```

### Function: `mintClaimableShares`

```solidity
❌ Untouched lines:
```

```solidity
uint256 balanceAfter = IERC20(share).balanceOf(address(node));
```

```solidity
sharesReceived = balanceAfter - balanceBefore;
```

```solidity
revert InsufficientSharesReturned(component, sharesReceived, claimableShares);
```

```solidity
emit MintedClaimableShares(node, component, sharesReceived);
```

```solidity
return sharesReceived;
```

### Function: `requestAsyncWithdrawal`

```solidity
❌ Untouched lines:
```

```solidity
address shareToken = IERC7575(component).share();
```

```solidity
revert ExceedsAvailableShares(node, component, shares);
```

```solidity
uint256 requestId = _requestRedeem(node, component, shares);
```

```solidity
revert IncorrectRequestId(requestId);
```

```solidity
emit RequestedAsyncWithdrawal(node, component, shares);
```

### Function: `executeAsyncWithdrawal`

```solidity
❌ Untouched lines:
```

```solidity
assetsReceived = _executeAsyncWithdrawal(node, component, assets);
```

### Function: `_requestRedeem`

```solidity
❌ Untouched lines:
```

```solidity
address shareToken = IERC7575(component).share();
```

```solidity
_safeApprove(node, shareToken, component, shares);
```

```solidity
bytes memory result =
```

```solidity
INode(node).execute(component, abi.encodeCall(IERC7540Redeem.requestRedeem, (shares, node, node)));
```

```solidity
return abi.decode(result, (uint256));
```

### Function: `_withdraw`

```solidity
❌ Untouched lines:
```

```solidity
bytes memory result = INode(node).execute(component, abi.encodeCall(IERC7575.withdraw, (assets, node, node)));
```

```solidity
return abi.decode(result, (uint256));
```

### Function: `_executeAsyncWithdrawal`

```solidity
❌ Untouched lines:
```

```solidity
revert ExceedsAvailableAssets(node, component, assets);
```

```solidity
address asset = IERC7575(node).asset();
```

```solidity
uint256 balanceBefore = IERC20(asset).balanceOf(address(node));
```

```solidity
_withdraw(node, component, assets);
```

```solidity
uint256 balanceAfter = IERC20(asset).balanceOf(address(node));
```

```solidity
revert InsufficientAssetsReturned(component, 0, assets);
```

```solidity
assetsReceived = balanceAfter - balanceBefore;
```

```solidity
revert InsufficientAssetsReturned(component, assetsReceived, assets);
```

```solidity
emit AsyncWithdrawalExecuted(node, component, assetsReceived);
```

```solidity
return assetsReceived;
```

```solidity
❌ Warning: Coverage 41.18% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: routers/ERC7540Router.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 10     │
│ fullyCoveredFunctions      │ 2      │
│ coveredLines               │ 28     │
│ revertedLines              │ 0      │
│ untouchedLines             │ 40     │
│ functionCoveragePercentage │ 20     │
│ lineCoveragePercentage     │ 41.18  │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬───────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName              │ touched │ reverted │ untouchedLines │
├─────────┼───────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'fulfillRedeemRequest'    │ false   │ false    │ 11             │
│ 1       │ 'investInAsyncComponent'  │ true    │ false    │ 1              │
│ 2       │ 'mintClaimableShares'     │ true    │ false    │ 5              │
│ 3       │ 'requestAsyncWithdrawal'  │ false   │ false    │ 5              │
│ 4       │ 'executeAsyncWithdrawal'  │ false   │ false    │ 1              │
│ 5       │ '_requestRedeem'          │ false   │ false    │ 5              │
│ 6       │ '_withdraw'               │ false   │ false    │ 2              │
│ 7       │ '_executeAsyncWithdrawal' │ false   │ false    │ 10             │
└─────────┴───────────────────────────┴─────────┴──────────┴────────────────┘

Function: fulfillRedeemRequest
❌ Untouched lines:
(uint256 sharesPending,,, uint256 sharesAdjusted) = INode(node).requests(controller);
uint256 assetsRequested = INode(node).convertToAssets(sharesAdjusted);
INode(node).enforceLiquidationOrder(component, assetsRequested);
uint256 maxClaimableRedeemRequest = IERC7540Redeem(component).claimableRedeemRequest(0, node);
uint256 maxClaimableAssets = IERC7575(component).convertToAssets(maxClaimableRedeemRequest);
assetsReturned = _executeAsyncWithdrawal(node, component, Math.min(assetsRequested, maxClaimableAssets));
(sharesPending, sharesAdjusted) =
_calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested, sharesAdjusted);
INode(node).finalizeRedemption(controller, assetsReturned, sharesPending, sharesAdjusted);
emit FulfilledRedeemRequest(node, component, assetsReturned);
return assetsReturned;

Function: investInAsyncComponent
❌ Untouched lines:
revert IncorrectRequestId(requestId);

Function: mintClaimableShares
❌ Untouched lines:
uint256 balanceAfter = IERC20(share).balanceOf(address(node));
sharesReceived = balanceAfter - balanceBefore;
revert InsufficientSharesReturned(component, sharesReceived, claimableShares);
emit MintedClaimableShares(node, component, sharesReceived);
return sharesReceived;

Function: requestAsyncWithdrawal
❌ Untouched lines:
address shareToken = IERC7575(component).share();
revert ExceedsAvailableShares(node, component, shares);
uint256 requestId = _requestRedeem(node, component, shares);
revert IncorrectRequestId(requestId);
emit RequestedAsyncWithdrawal(node, component, shares);

Function: executeAsyncWithdrawal
❌ Untouched lines:
assetsReceived = _executeAsyncWithdrawal(node, component, assets);

Function: _requestRedeem
❌ Untouched lines:
address shareToken = IERC7575(component).share();
_safeApprove(node, shareToken, component, shares);
bytes memory result =
INode(node).execute(component, abi.encodeCall(IERC7540Redeem.requestRedeem, (shares, node, node)));
return abi.decode(result, (uint256));

Function: _withdraw
❌ Untouched lines:
bytes memory result = INode(node).execute(component, abi.encodeCall(IERC7575.withdraw, (assets, node, node)));
return abi.decode(result, (uint256));

Function: _executeAsyncWithdrawal
❌ Untouched lines:
revert ExceedsAvailableAssets(node, component, assets);
address asset = IERC7575(node).asset();
uint256 balanceBefore = IERC20(asset).balanceOf(address(node));
_withdraw(node, component, assets);
uint256 balanceAfter = IERC20(asset).balanceOf(address(node));
revert InsufficientAssetsReturned(component, 0, assets);
assetsReceived = balanceAfter - balanceBefore;
revert InsufficientAssetsReturned(component, assetsReceived, assets);
emit AsyncWithdrawalExecuted(node, component, assetsReceived);
return assetsReceived;

❌ Warning: Coverage 41.18% below threshold 70%
```

</details>

### ERC4626Router

**Coverage:** 68.09%
`██████████████████████████████████░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 6 |
| Line Coverage | 68.09% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `claim` | false | false | 4 |

## 🔍 Uncovered Code Lines

### Function: `claim`

```solidity
❌ Untouched lines:
```

```solidity
INode(node).execute(
```

```solidity
distributor,
```

```solidity
abi.encodeCall(IFluidDistributor.claim, (node, cumulativeAmount, 1, positionId, cycle, merkleProof, ""))
```

```solidity
emit FluidRewardsClaimed(node, cycle, cumulativeAmount);
```

```solidity
❌ Warning: Coverage 20% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: routers/FluidRewardsRouter.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 1      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 1      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 4      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 20     │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬──────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName │ touched │ reverted │ untouchedLines │
├─────────┼──────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'claim'      │ false   │ false    │ 4              │
└─────────┴──────────────┴─────────┴──────────┴────────────────┘

Function: claim
❌ Untouched lines:
INode(node).execute(
distributor,
abi.encodeCall(IFluidDistributor.claim, (node, cumulativeAmount, 1, positionId, cycle, merkleProof, ""))
emit FluidRewardsClaimed(node, cycle, cumulativeAmount);

❌ Warning: Coverage 20% below threshold 70%
```

</details>

### ERC7540Router

**Coverage:** 41.18%
`████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 10 |
| Line Coverage | 41.18% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `claim` | false | false | 3 |

## 🔍 Uncovered Code Lines

### Function: `claim`

```solidity
❌ Untouched lines:
```

```solidity
INode(node).execute(
```

```solidity
distributor, abi.encodeCall(IIncentraDistributor.claimAll, (node, campaignAddrs, campaignRewards))
```

```solidity
emit IncentraRewardsClaimed(node);
```

```solidity
❌ Warning: Coverage 25% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: routers/IncentraRouter.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 1      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 1      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 3      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 25     │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬──────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName │ touched │ reverted │ untouchedLines │
├─────────┼──────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'claim'      │ false   │ false    │ 3              │
└─────────┴──────────────┴─────────┴──────────┴────────────────┘

Function: claim
❌ Untouched lines:
INode(node).execute(
distributor, abi.encodeCall(IIncentraDistributor.claimAll, (node, campaignAddrs, campaignRewards))
emit IncentraRewardsClaimed(node);

❌ Warning: Coverage 25% below threshold 70%
```

</details>

### FluidRewardsRouter

**Coverage:** 20%
`██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 20% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `claim` | false | false | 4 |

## 🔍 Uncovered Code Lines

### Function: `claim`

```solidity
❌ Untouched lines:
```

```solidity
address[] memory users = new address[](tokens.length);
```

```solidity
users[i] = node;
```

```solidity
INode(node).execute(distributor, abi.encodeCall(IMerklDistributor.claim, (users, tokens, amounts, proofs)));
```

```solidity
emit MerklRewardsClaimed(node, tokens, amounts);
```

```solidity
❌ Warning: Coverage 20% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: routers/MerklRouter.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 1      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 1      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 4      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 20     │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬──────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName │ touched │ reverted │ untouchedLines │
├─────────┼──────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'claim'      │ false   │ false    │ 4              │
└─────────┴──────────────┴─────────┴──────────┴────────────────┘

Function: claim
❌ Untouched lines:
address[] memory users = new address[](tokens.length);
users[i] = node;
INode(node).execute(distributor, abi.encodeCall(IMerklDistributor.claim, (users, tokens, amounts, proofs)));
emit MerklRewardsClaimed(node, tokens, amounts);

❌ Warning: Coverage 20% below threshold 70%
```

</details>

### IncentraRouter

**Coverage:** 25%
`████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 25% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `setIncentiveWhitelistStatus` | false | false | 3 |
| 1 | `setExecutorWhitelistStatus` | false | false | 3 |
| 2 | `swap` | true | false | 19 |

## 🔍 Uncovered Code Lines

### Function: `setIncentiveWhitelistStatus`

```solidity
❌ Untouched lines:
```

```solidity
if (incentive == address(0)) revert ErrorsLib.ZeroAddress();
```

```solidity
isIncentiveWhitelisted[incentive] = status;
```

```solidity
emit IncentiveWhitelisted(incentive, status);
```

### Function: `setExecutorWhitelistStatus`

```solidity
❌ Untouched lines:
```

```solidity
if (executor == address(0)) revert ErrorsLib.ZeroAddress();
```

```solidity
isExecutorWhitelisted[executor] = status;
```

```solidity
emit ExecutorWhitelisted(executor, status);
```

### Function: `swap`

```solidity
❌ Untouched lines:
```

```solidity
address asset = INode(node).asset();
```

```solidity
require(asset != incentive, IncentiveIsAsset());
```

```solidity
require(!INode(node).isComponent(incentive), IncentiveIsComponent());
```

```solidity
require(isIncentiveWhitelisted[incentive], IncentiveNotWhitelisted());
```

```solidity
require(isExecutorWhitelisted[executor], ExecutorNotWhitelisted());
```

```solidity
require(IERC20(incentive).balanceOf(node) >= incentiveAmount, IncentiveInsufficientAmount());
```

```solidity
_safeApprove(node, incentive, ONE_INCH_AGGREGATION_ROUTER_V6, incentiveAmount);
```

```solidity
IAggregationRouterV6.SwapDescription memory swapDescription = IAggregationRouterV6.SwapDescription({
```

```solidity
srcToken: incentive,
```

```solidity
srcReceiver: executor,
```

```solidity
dstReceiver: node,
```

```solidity
minReturnAmount: minAssetsOut,
```

```solidity
flags: 0
```

```solidity
bytes memory result = INode(node).execute(
```

```solidity
ONE_INCH_AGGREGATION_ROUTER_V6,
```

```solidity
(uint256 returnAmount, uint256 spentAmount) = abi.decode(result, (uint256, uint256));
```

```solidity
require(spentAmount == incentiveAmount, IncentiveIncompleteSwap());
```

```solidity
uint256 returnAmountAfterFee = _subtractExecutionFee(returnAmount, node);
```

```solidity
emit Compounded(node, incentive, incentiveAmount, returnAmount, returnAmountAfterFee);
```

```solidity
❌ Warning: Coverage 19.35% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: routers/OneInchV6RouterV1.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 3      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 6      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 25     │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 19.35  │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬───────────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName                  │ touched │ reverted │ untouchedLines │
├─────────┼───────────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'setIncentiveWhitelistStatus' │ false   │ false    │ 3              │
│ 1       │ 'setExecutorWhitelistStatus'  │ false   │ false    │ 3              │
│ 2       │ 'swap'                        │ true    │ false    │ 19             │
└─────────┴───────────────────────────────┴─────────┴──────────┴────────────────┘

Function: setIncentiveWhitelistStatus
❌ Untouched lines:
if (incentive == address(0)) revert ErrorsLib.ZeroAddress();
isIncentiveWhitelisted[incentive] = status;
emit IncentiveWhitelisted(incentive, status);

Function: setExecutorWhitelistStatus
❌ Untouched lines:
if (executor == address(0)) revert ErrorsLib.ZeroAddress();
isExecutorWhitelisted[executor] = status;
emit ExecutorWhitelisted(executor, status);

Function: swap
❌ Untouched lines:
address asset = INode(node).asset();
require(asset != incentive, IncentiveIsAsset());
require(!INode(node).isComponent(incentive), IncentiveIsComponent());
require(isIncentiveWhitelisted[incentive], IncentiveNotWhitelisted());
require(isExecutorWhitelisted[executor], ExecutorNotWhitelisted());
require(IERC20(incentive).balanceOf(node) >= incentiveAmount, IncentiveInsufficientAmount());
_safeApprove(node, incentive, ONE_INCH_AGGREGATION_ROUTER_V6, incentiveAmount);
IAggregationRouterV6.SwapDescription memory swapDescription = IAggregationRouterV6.SwapDescription({
srcToken: incentive,
srcReceiver: executor,
dstReceiver: node,
minReturnAmount: minAssetsOut,
flags: 0
bytes memory result = INode(node).execute(
ONE_INCH_AGGREGATION_ROUTER_V6,
(uint256 returnAmount, uint256 spentAmount) = abi.decode(result, (uint256, uint256));
require(spentAmount == incentiveAmount, IncentiveIncompleteSwap());
uint256 returnAmountAfterFee = _subtractExecutionFee(returnAmount, node);
emit Compounded(node, incentive, incentiveAmount, returnAmount, returnAmountAfterFee);

❌ Warning: Coverage 19.35% below threshold 70%
```

</details>

### MerklRouter

**Coverage:** 20%
`██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 20% |

<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: quoters/QuoterV1.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 0      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 0      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 0      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 0      │
└────────────────────────────┴────────┘

❌ Warning: Coverage 0% below threshold 70%
```

</details>

### OneInchV6RouterV1

**Coverage:** 19.35%
`█████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 3 |
| Line Coverage | 19.35% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `setBlacklistStatus` | true | false | 2 |
| 1 | `batchSetWhitelistStatus` | false | false | 7 |
| 2 | `setTolerance` | false | false | 2 |
| 3 | `_subtractExecutionFee` | true | false | 3 |

## 🔍 Uncovered Code Lines

### Function: `setBlacklistStatus`

```solidity
❌ Untouched lines:
```

```solidity
if (component == address(0)) revert ErrorsLib.ZeroAddress();
```

```solidity
isBlacklisted[component] = status;
```

### Function: `batchSetWhitelistStatus`

```solidity
❌ Untouched lines:
```

```solidity
if (components.length != statuses.length) revert ErrorsLib.LengthMismatch();
```

```solidity
uint256 length = components.length;
```

```solidity
if (components[i] == address(0)) revert ErrorsLib.ZeroAddress();
```

```solidity
isWhitelisted[components[i]] = statuses[i];
```

```solidity
emit EventsLib.ComponentWhitelisted(components[i], statuses[i]);
```

```solidity
unchecked {
```

```solidity
++i;
```

### Function: `setTolerance`

```solidity
❌ Untouched lines:
```

```solidity
tolerance = newTolerance;
```

```solidity
emit EventsLib.ToleranceUpdated(newTolerance);
```

### Function: `_subtractExecutionFee`

```solidity
❌ Untouched lines:
```

```solidity
uint256 transactionAfterFee = transactionAmount - executionFee;
```

```solidity
INode(node).subtractProtocolExecutionFee(executionFee);
```

```solidity
return transactionAfterFee;
```

```solidity
❌ Warning: Coverage 62.16% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: libraries/BaseComponentRouter.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 7      │
│ fullyCoveredFunctions      │ 3      │
│ coveredLines               │ 23     │
│ revertedLines              │ 0      │
│ untouchedLines             │ 14     │
│ functionCoveragePercentage │ 42.86  │
│ lineCoveragePercentage     │ 62.16  │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬───────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName              │ touched │ reverted │ untouchedLines │
├─────────┼───────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'setBlacklistStatus'      │ true    │ false    │ 2              │
│ 1       │ 'batchSetWhitelistStatus' │ false   │ false    │ 7              │
│ 2       │ 'setTolerance'            │ false   │ false    │ 2              │
│ 3       │ '_subtractExecutionFee'   │ true    │ false    │ 3              │
└─────────┴───────────────────────────┴─────────┴──────────┴────────────────┘

Function: setBlacklistStatus
❌ Untouched lines:
if (component == address(0)) revert ErrorsLib.ZeroAddress();
isBlacklisted[component] = status;

Function: batchSetWhitelistStatus
❌ Untouched lines:
if (components.length != statuses.length) revert ErrorsLib.LengthMismatch();
uint256 length = components.length;
if (components[i] == address(0)) revert ErrorsLib.ZeroAddress();
isWhitelisted[components[i]] = statuses[i];
emit EventsLib.ComponentWhitelisted(components[i], statuses[i]);
unchecked {
++i;

Function: setTolerance
❌ Untouched lines:
tolerance = newTolerance;
emit EventsLib.ToleranceUpdated(newTolerance);

Function: _subtractExecutionFee
❌ Untouched lines:
uint256 transactionAfterFee = transactionAmount - executionFee;
INode(node).subtractProtocolExecutionFee(executionFee);
return transactionAfterFee;

❌ Warning: Coverage 62.16% below threshold 70%
```

</details>

### QuoterV1

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: libraries/BaseQuoter.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 0      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 0      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 0      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 0      │
└────────────────────────────┴────────┘

❌ Warning: Coverage 0% below threshold 70%
```

</details>

### BaseComponentRouter

**Coverage:** 62.16%
`███████████████████████████████░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 7 |
| Line Coverage | 62.16% |

<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: libraries/ErrorsLib.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 0      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 0      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 0      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 0      │
└────────────────────────────┴────────┘

❌ Warning: Coverage 0% below threshold 70%
```

</details>

### BaseQuoter

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: libraries/EventsLib.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 0      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 0      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 0      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 0      │
└────────────────────────────┴────────┘

❌ Warning: Coverage 0% below threshold 70%
```

</details>

### ErrorsLib

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: libraries/MathLib.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 0      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 0      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 0      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 0      │
└────────────────────────────┴────────┘

❌ Warning: Coverage 0% below threshold 70%
```

</details>

### EventsLib

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: libraries/RegistryAccessControl.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 0      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 0      │
│ revertedLines              │ 0      │
│ untouchedLines             │ 0      │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 0      │
└────────────────────────────┴────────┘

❌ Warning: Coverage 0% below threshold 70%
```

</details>

### MathLib

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `setPriceDeviation` | false | false | 3 |
| 1 | `setSettlementDeviation` | false | false | 3 |
| 2 | `setPriceUpdateDeviation` | false | false | 2 |
| 3 | `setMinDepositAmount` | false | false | 2 |
| 4 | `setMinRedeemAmount` | false | false | 2 |
| 5 | `forceUpdateLastPrice` | false | false | 3 |
| 6 | `updateLastPrice` | false | false | 3 |
| 7 | `requestDeposit` | true | false | 1 |
| 8 | `settleDeposit` | true | false | 18 |
| 9 | `mint` | true | false | 9 |
| 10 | `requestRedeem` | true | false | 4 |
| 11 | `settleRedeem` | true | false | 25 |
| 12 | `withdraw` | false | false | 12 |
| 13 | `forwardRequestsToDigift` | true | false | 5 |
| 14 | `deposit` | false | false | 1 |
| 15 | `deposit` | false | false | 1 |
| 16 | `mint` | false | false | 1 |
| 17 | `redeem` | false | false | 1 |
| 18 | `setOperator` | false | false | 1 |

## 🔍 Uncovered Code Lines

### Function: `setPriceDeviation`

```solidity
❌ Untouched lines:
```

```solidity
require(value <= WAD, InvalidPercentage());
```

```solidity
emit PriceDeviationChange(priceDeviation, value);
```

```solidity
priceDeviation = value;
```

### Function: `setSettlementDeviation`

```solidity
❌ Untouched lines:
```

```solidity
require(value <= WAD, InvalidPercentage());
```

```solidity
emit SettlementDeviationChange(settlementDeviation, value);
```

```solidity
settlementDeviation = value;
```

### Function: `setPriceUpdateDeviation`

```solidity
❌ Untouched lines:
```

```solidity
emit PriceUpdateDeviationChange(priceUpdateDeviation, value);
```

```solidity
priceUpdateDeviation = value;
```

### Function: `setMinDepositAmount`

```solidity
❌ Untouched lines:
```

```solidity
emit MinDepositAmountChange(minDepositAmount, value);
```

```solidity
minDepositAmount = value;
```

### Function: `setMinRedeemAmount`

```solidity
❌ Untouched lines:
```

```solidity
emit MinRedeemAmountChange(minRedeemAmount, value);
```

```solidity
minRedeemAmount = value;
```

### Function: `forceUpdateLastPrice`

```solidity
❌ Untouched lines:
```

```solidity
uint256 price = dFeedPriceOracle.getPrice();
```

```solidity
lastPrice = price;
```

```solidity
emit LastPriceUpdate(price);
```

### Function: `updateLastPrice`

```solidity
❌ Untouched lines:
```

```solidity
uint256 price = _getPrice();
```

```solidity
lastPrice = price;
```

```solidity
emit LastPriceUpdate(price);
```

### Function: `requestDeposit`

```solidity
❌ Untouched lines:
```

```solidity
return REQUEST_ID;
```

### Function: `settleDeposit`

```solidity
❌ Untouched lines:
```

```solidity
require(
```

```solidity
MathLib.withinRange(vars.globalPendingDepositRequest, vars.settlementValue, settlementDeviation),
```

```solidity
NodeState storage node = _nodeState[nodes[i]];
```

```solidity
uint256 nodePendingDepositRequest = node.pendingDepositRequest;
```

```solidity
require(nodePendingDepositRequest > 0, NoPendingDepositRequest(nodes[i]));
```

```solidity
uint256 assetsToReimburse = nodePendingDepositRequest.mulDiv(assets, vars.globalPendingDepositRequest);
```

```solidity
uint256 sharesToMint = nodePendingDepositRequest.mulDiv(shares, vars.globalPendingDepositRequest);
```

```solidity
vars.totalPendingDepositRequestCheck += nodePendingDepositRequest;
```

```solidity
vars.totalSharesToMint += sharesToMint;
```

```solidity
vars.totalAssetsToReimburse += assetsToReimburse;
```

```solidity
if (vars.totalSharesToMint < shares
```

```solidity
sharesToMint += shares - vars.totalSharesToMint;
```

```solidity
assetsToReimburse += assets - vars.totalAssetsToReimburse;
```

```solidity
node.claimableDepositRequest = nodePendingDepositRequest;
```

```solidity
node.pendingDepositRequest = 0;
```

```solidity
node.maxMint = sharesToMint;
```

```solidity
node.pendingDepositReimbursement = assetsToReimburse;
```

```solidity
emit DepositSettled(nodes[i], sharesToMint, assetsToReimburse);
```

### Function: `mint`

```solidity
❌ Untouched lines:
```

```solidity
require(node.maxMint == shares, MintAllSharesOnly());
```

```solidity
assets = node.claimableDepositRequest;
```

```solidity
uint256 assetsToReimburse = node.pendingDepositReimbursement;
```

```solidity
node.claimableDepositRequest = 0;
```

```solidity
node.maxMint = 0;
```

```solidity
node.pendingDepositReimbursement = 0;
```

```solidity
_mint(msg.sender, shares);
```

```solidity
IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);
```

```solidity
emit Deposit(controller, receiver, assets - assetsToReimburse, shares);
```

### Function: `requestRedeem`

```solidity
❌ Untouched lines:
```

```solidity
_nodeState[msg.sender].pendingRedeemRequest = shares;
```

```solidity
_globalState.accumulatedRedemption += shares;
```

```solidity
_spendAllowance(msg.sender, address(this), shares);
```

```solidity
_transfer(msg.sender, address(this), shares);
```

### Function: `settleRedeem`

```solidity
❌ Untouched lines:
```

```solidity
(uint256 shares, uint256 assets) = digiftEventVerifier.verifySettlementEvent(
```

```solidity
verifyArgs,
```

```solidity
DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), stToken, asset
```

```solidity
SettleRedeemVars memory vars;
```

```solidity
vars.globalPendingRedeemRequest = _globalState.pendingRedeemRequest;
```

```solidity
vars.settlementValue = convertToShares(assets) + shares;
```

```solidity
require(vars.globalPendingRedeemRequest > 0, NothingToSettle());
```

```solidity
require(
```

```solidity
MathLib.withinRange(vars.globalPendingRedeemRequest, vars.settlementValue, settlementDeviation),
```

```solidity
NodeState storage node = _nodeState[nodes[i]];
```

```solidity
uint256 nodePendingRedeemRequest = node.pendingRedeemRequest;
```

```solidity
require(nodePendingRedeemRequest > 0, NoPendingRedeemRequest(nodes[i]));
```

```solidity
uint256 assetsToReturn = nodePendingRedeemRequest.mulDiv(assets, vars.globalPendingRedeemRequest);
```

```solidity
uint256 sharesToReimburse = nodePendingRedeemRequest.mulDiv(shares, vars.globalPendingRedeemRequest);
```

```solidity
vars.totalPendingRedeemRequestCheck += nodePendingRedeemRequest;
```

```solidity
vars.totalAssetsToReturn += assetsToReturn;
```

```solidity
vars.totalSharesToReimburse += sharesToReimburse;
```

```solidity
if (vars.totalAssetsToReturn < assets
```

```solidity
assetsToReturn += assets - vars.totalAssetsToReturn;
```

```solidity
sharesToReimburse += shares - vars.totalSharesToReimburse;
```

```solidity
node.claimableRedeemRequest = nodePendingRedeemRequest;
```

```solidity
node.pendingRedeemRequest = 0;
```

```solidity
node.maxWithdraw = assetsToReturn;
```

```solidity
node.pendingRedeemReimbursement = sharesToReimburse;
```

```solidity
emit RedeemSettled(nodes[i], sharesToReimburse, assetsToReturn);
```

### Function: `withdraw`

```solidity
❌ Untouched lines:
```

```solidity
require(_nodeState[msg.sender].claimableRedeemRequest > 0, RedeemRequestNotFulfilled());
```

```solidity
require(_nodeState[msg.sender].maxWithdraw == assets, WithdrawAllAssetsOnly());
```

```solidity
shares = _nodeState[msg.sender].claimableRedeemRequest;
```

```solidity
uint256 sharesToReimburse = _nodeState[msg.sender].pendingRedeemReimbursement;
```

```solidity
uint256 sharesToBurn = shares - sharesToReimburse;
```

```solidity
_nodeState[msg.sender].claimableRedeemRequest = 0;
```

```solidity
_nodeState[msg.sender].maxWithdraw = 0;
```

```solidity
_nodeState[msg.sender].pendingRedeemReimbursement = 0;
```

```solidity
_burn(address(this), sharesToBurn);
```

```solidity
_transfer(address(this), msg.sender, sharesToReimburse);
```

```solidity
IERC20(asset).safeTransfer(msg.sender, assets);
```

```solidity
emit Withdraw(msg.sender, receiver, controller, assets, shares - sharesToReimburse);
```

### Function: `forwardRequestsToDigift`

```solidity
❌ Untouched lines:
```

```solidity
_globalState.accumulatedRedemption = 0;
```

```solidity
_globalState.pendingRedeemRequest = pendingShares;
```

```solidity
IERC20(stToken).safeIncreaseAllowance(address(subRedManagement), pendingShares);
```

```solidity
subRedManagement.redeem(stToken, asset, pendingShares, block.timestamp + 1);
```

```solidity
emit DigiftRedeemed(pendingShares);
```

### Function: `deposit`

```solidity
❌ Untouched lines:
```

```solidity
revert Unsupported();
```

### Function: `deposit`

```solidity
❌ Untouched lines:
```

```solidity
revert Unsupported();
```

### Function: `mint`

```solidity
❌ Untouched lines:
```

```solidity
revert Unsupported();
```

### Function: `redeem`

```solidity
❌ Untouched lines:
```

```solidity
revert Unsupported();
```

### Function: `setOperator`

```solidity
❌ Untouched lines:
```

```solidity
revert Unsupported();
```

```solidity
❌ Warning: Coverage 42.94% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: digift/DigiftAdapter.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 22     │
│ fullyCoveredFunctions      │ 3      │
│ coveredLines               │ 73     │
│ revertedLines              │ 0      │
│ untouchedLines             │ 97     │
│ functionCoveragePercentage │ 13.64  │
│ lineCoveragePercentage     │ 42.94  │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬───────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName              │ touched │ reverted │ untouchedLines │
├─────────┼───────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'setPriceDeviation'       │ false   │ false    │ 3              │
│ 1       │ 'setSettlementDeviation'  │ false   │ false    │ 3              │
│ 2       │ 'setPriceUpdateDeviation' │ false   │ false    │ 2              │
│ 3       │ 'setMinDepositAmount'     │ false   │ false    │ 2              │
│ 4       │ 'setMinRedeemAmount'      │ false   │ false    │ 2              │
│ 5       │ 'forceUpdateLastPrice'    │ false   │ false    │ 3              │
│ 6       │ 'updateLastPrice'         │ false   │ false    │ 3              │
│ 7       │ 'requestDeposit'          │ true    │ false    │ 1              │
│ 8       │ 'settleDeposit'           │ true    │ false    │ 18             │
│ 9       │ 'mint'                    │ true    │ false    │ 9              │
│ 10      │ 'requestRedeem'           │ true    │ false    │ 4              │
│ 11      │ 'settleRedeem'            │ true    │ false    │ 25             │
│ 12      │ 'withdraw'                │ false   │ false    │ 12             │
│ 13      │ 'forwardRequestsToDigift' │ true    │ false    │ 5              │
│ 14      │ 'deposit'                 │ false   │ false    │ 1              │
│ 15      │ 'deposit'                 │ false   │ false    │ 1              │
│ 16      │ 'mint'                    │ false   │ false    │ 1              │
│ 17      │ 'redeem'                  │ false   │ false    │ 1              │
│ 18      │ 'setOperator'             │ false   │ false    │ 1              │
└─────────┴───────────────────────────┴─────────┴──────────┴────────────────┘

Function: setPriceDeviation
❌ Untouched lines:
require(value <= WAD, InvalidPercentage());
emit PriceDeviationChange(priceDeviation, value);
priceDeviation = value;

Function: setSettlementDeviation
❌ Untouched lines:
require(value <= WAD, InvalidPercentage());
emit SettlementDeviationChange(settlementDeviation, value);
settlementDeviation = value;

Function: setPriceUpdateDeviation
❌ Untouched lines:
emit PriceUpdateDeviationChange(priceUpdateDeviation, value);
priceUpdateDeviation = value;

Function: setMinDepositAmount
❌ Untouched lines:
emit MinDepositAmountChange(minDepositAmount, value);
minDepositAmount = value;

Function: setMinRedeemAmount
❌ Untouched lines:
emit MinRedeemAmountChange(minRedeemAmount, value);
minRedeemAmount = value;

Function: forceUpdateLastPrice
❌ Untouched lines:
uint256 price = dFeedPriceOracle.getPrice();
lastPrice = price;
emit LastPriceUpdate(price);

Function: updateLastPrice
❌ Untouched lines:
uint256 price = _getPrice();
lastPrice = price;
emit LastPriceUpdate(price);

Function: requestDeposit
❌ Untouched lines:
return REQUEST_ID;

Function: settleDeposit
❌ Untouched lines:
require(
MathLib.withinRange(vars.globalPendingDepositRequest, vars.settlementValue, settlementDeviation),
NodeState storage node = _nodeState[nodes[i]];
uint256 nodePendingDepositRequest = node.pendingDepositRequest;
require(nodePendingDepositRequest > 0, NoPendingDepositRequest(nodes[i]));
uint256 assetsToReimburse = nodePendingDepositRequest.mulDiv(assets, vars.globalPendingDepositRequest);
uint256 sharesToMint = nodePendingDepositRequest.mulDiv(shares, vars.globalPendingDepositRequest);
vars.totalPendingDepositRequestCheck += nodePendingDepositRequest;
vars.totalSharesToMint += sharesToMint;
vars.totalAssetsToReimburse += assetsToReimburse;
if (vars.totalSharesToMint < shares
sharesToMint += shares - vars.totalSharesToMint;
assetsToReimburse += assets - vars.totalAssetsToReimburse;
node.claimableDepositRequest = nodePendingDepositRequest;
node.pendingDepositRequest = 0;
node.maxMint = sharesToMint;
node.pendingDepositReimbursement = assetsToReimburse;
emit DepositSettled(nodes[i], sharesToMint, assetsToReimburse);

Function: mint
❌ Untouched lines:
require(node.maxMint == shares, MintAllSharesOnly());
assets = node.claimableDepositRequest;
uint256 assetsToReimburse = node.pendingDepositReimbursement;
node.claimableDepositRequest = 0;
node.maxMint = 0;
node.pendingDepositReimbursement = 0;
_mint(msg.sender, shares);
IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);
emit Deposit(controller, receiver, assets - assetsToReimburse, shares);

Function: requestRedeem
❌ Untouched lines:
_nodeState[msg.sender].pendingRedeemRequest = shares;
_globalState.accumulatedRedemption += shares;
_spendAllowance(msg.sender, address(this), shares);
_transfer(msg.sender, address(this), shares);

Function: settleRedeem
❌ Untouched lines:
(uint256 shares, uint256 assets) = digiftEventVerifier.verifySettlementEvent(
verifyArgs,
DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), stToken, asset
SettleRedeemVars memory vars;
vars.globalPendingRedeemRequest = _globalState.pendingRedeemRequest;
vars.settlementValue = convertToShares(assets) + shares;
require(vars.globalPendingRedeemRequest > 0, NothingToSettle());
require(
MathLib.withinRange(vars.globalPendingRedeemRequest, vars.settlementValue, settlementDeviation),
NodeState storage node = _nodeState[nodes[i]];
uint256 nodePendingRedeemRequest = node.pendingRedeemRequest;
require(nodePendingRedeemRequest > 0, NoPendingRedeemRequest(nodes[i]));
uint256 assetsToReturn = nodePendingRedeemRequest.mulDiv(assets, vars.globalPendingRedeemRequest);
uint256 sharesToReimburse = nodePendingRedeemRequest.mulDiv(shares, vars.globalPendingRedeemRequest);
vars.totalPendingRedeemRequestCheck += nodePendingRedeemRequest;
vars.totalAssetsToReturn += assetsToReturn;
vars.totalSharesToReimburse += sharesToReimburse;
if (vars.totalAssetsToReturn < assets
assetsToReturn += assets - vars.totalAssetsToReturn;
sharesToReimburse += shares - vars.totalSharesToReimburse;
node.claimableRedeemRequest = nodePendingRedeemRequest;
node.pendingRedeemRequest = 0;
node.maxWithdraw = assetsToReturn;
node.pendingRedeemReimbursement = sharesToReimburse;
emit RedeemSettled(nodes[i], sharesToReimburse, assetsToReturn);

Function: withdraw
❌ Untouched lines:
require(_nodeState[msg.sender].claimableRedeemRequest > 0, RedeemRequestNotFulfilled());
require(_nodeState[msg.sender].maxWithdraw == assets, WithdrawAllAssetsOnly());
shares = _nodeState[msg.sender].claimableRedeemRequest;
uint256 sharesToReimburse = _nodeState[msg.sender].pendingRedeemReimbursement;
uint256 sharesToBurn = shares - sharesToReimburse;
_nodeState[msg.sender].claimableRedeemRequest = 0;
_nodeState[msg.sender].maxWithdraw = 0;
_nodeState[msg.sender].pendingRedeemReimbursement = 0;
_burn(address(this), sharesToBurn);
_transfer(address(this), msg.sender, sharesToReimburse);
IERC20(asset).safeTransfer(msg.sender, assets);
emit Withdraw(msg.sender, receiver, controller, assets, shares - sharesToReimburse);

Function: forwardRequestsToDigift
❌ Untouched lines:
_globalState.accumulatedRedemption = 0;
_globalState.pendingRedeemRequest = pendingShares;
IERC20(stToken).safeIncreaseAllowance(address(subRedManagement), pendingShares);
subRedManagement.redeem(stToken, asset, pendingShares, block.timestamp + 1);
emit DigiftRedeemed(pendingShares);

Function: deposit
❌ Untouched lines:
revert Unsupported();

Function: deposit
❌ Untouched lines:
revert Unsupported();

Function: mint
❌ Untouched lines:
revert Unsupported();

Function: redeem
❌ Untouched lines:
revert Unsupported();

Function: setOperator
❌ Untouched lines:
revert Unsupported();

❌ Warning: Coverage 42.94% below threshold 70%
```

</details>

### RegistryAccessControl

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `setWhitelist` | false | false | 2 |
| 1 | `setBlockHash` | false | false | 2 |
| 2 | `verifySettlementEvent` | true | false | 27 |
| 3 | `_getBlockHash` | false | false | 4 |

## 🔍 Uncovered Code Lines

### Function: `setWhitelist`

```solidity
❌ Untouched lines:
```

```solidity
whitelist[digiftAdapter] = status;
```

```solidity
emit WhitelistChange(digiftAdapter, status);
```

### Function: `setBlockHash`

```solidity
❌ Untouched lines:
```

```solidity
blockHashes[blockNumber] = blockHash;
```

```solidity
emit BlockHashSet(blockNumber, blockHash);
```

### Function: `verifySettlementEvent`

```solidity
❌ Untouched lines:
```

```solidity
require(whitelist[msg.sender], NotWhitelisted());
```

```solidity
Vars memory vars;
```

```solidity
vars.blockHash = keccak256(fargs.headerRlp);
```

```solidity
vars.eventSignature = nargs.eventType == EventType.SUBSCRIBE ? SETTLE_SUBSCRIBER_TOPIC : SETTLE_REDEMPTION_TOPIC;
```

```solidity
if (_getBlockHash(fargs.blockNumber) != vars.blockHash) revert BadHeader();
```

```solidity
vars.receiptsRoot = bytes32(RLPReader.readBytes(RLPReader.readList(fargs.headerRlp)[5]));
```

```solidity
vars.logs = RLPReader.readList(
```

```solidity
RLPReader.readList(_stripTypedPrefix(MerkleTrie.get(fargs.txIndex, fargs.proof, vars.receiptsRoot)))[3]
```

```solidity
vars.log = RLPReader.readList(vars.logs[i]);
```

```solidity
if (address(bytes20(RLPReader.readBytes(vars.log[0]))) != nargs.emittingAddress) continue;
```

```solidity
RLPReader.RLPItem[] memory topics = RLPReader.readList(vars.log[1]);
```

```solidity
if (bytes32(RLPReader.readBytes(topics[0])) != vars.eventSignature) continue;
```

```solidity
address stToken,
```

```solidity
RLPReader.readBytes(vars.log[2]), (address, address[], uint256[], address[], uint256[], uint256[])
```

```solidity
if (stToken != nargs.securityToken) continue;
```

```solidity
vars.investorIndex = type(uint256).max;
```

```solidity
vars.investorIndex = j;
```

```solidity
break;
```

```solidity
if (vars.investorIndex == type(uint256).max) continue; // Caller not in investor list
```

```solidity
if (currencyTokenList[vars.investorIndex] != nargs.currencyToken) continue;
```

```solidity
vars.logHash = _hashLog(vars.blockHash, vars.receiptsRoot, fargs.txIndex, i);
```

```solidity
if (usedLogs[vars.logHash]) revert LogAlreadyUsed();
```

```solidity
usedLogs[vars.logHash] = true;
```

```solidity
emit Verified(
```

```solidity
msg.sender,
```

```solidity
return (quantityList[vars.investorIndex], amountList[vars.investorIndex]);
```

```solidity
revert NoEvent();
```

### Function: `_getBlockHash`

```solidity
❌ Untouched lines:
```

```solidity
bytes32 blockHash = blockhash(blockNumber);
```

```solidity
blockHash = blockHashes[blockNumber];
```

```solidity
if (blockHash == 0) revert MissedWindow();
```

```solidity
return blockHash;
```

```solidity
❌ Warning: Coverage 30% below threshold 70%
```


<details>
<summary>📊 Full Coverage Report</summary>

```
📄 File: digift/DigiftEventVerifier.sol
══════════════════════════════════════════════════
┌────────────────────────────┬────────┐
│ (index)                    │ Values │
├────────────────────────────┼────────┤
│ totalFunctions             │ 4      │
│ fullyCoveredFunctions      │ 0      │
│ coveredLines               │ 15     │
│ revertedLines              │ 0      │
│ untouchedLines             │ 35     │
│ functionCoveragePercentage │ 0      │
│ lineCoveragePercentage     │ 30     │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬─────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName            │ touched │ reverted │ untouchedLines │
├─────────┼─────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'setWhitelist'          │ false   │ false    │ 2              │
│ 1       │ 'setBlockHash'          │ false   │ false    │ 2              │
│ 2       │ 'verifySettlementEvent' │ true    │ false    │ 27             │
│ 3       │ '_getBlockHash'         │ false   │ false    │ 4              │
└─────────┴─────────────────────────┴─────────┴──────────┴────────────────┘

Function: setWhitelist
❌ Untouched lines:
whitelist[digiftAdapter] = status;
emit WhitelistChange(digiftAdapter, status);

Function: setBlockHash
❌ Untouched lines:
blockHashes[blockNumber] = blockHash;
emit BlockHashSet(blockNumber, blockHash);

Function: verifySettlementEvent
❌ Untouched lines:
require(whitelist[msg.sender], NotWhitelisted());
Vars memory vars;
vars.blockHash = keccak256(fargs.headerRlp);
vars.eventSignature = nargs.eventType == EventType.SUBSCRIBE ? SETTLE_SUBSCRIBER_TOPIC : SETTLE_REDEMPTION_TOPIC;
if (_getBlockHash(fargs.blockNumber) != vars.blockHash) revert BadHeader();
vars.receiptsRoot = bytes32(RLPReader.readBytes(RLPReader.readList(fargs.headerRlp)[5]));
vars.logs = RLPReader.readList(
RLPReader.readList(_stripTypedPrefix(MerkleTrie.get(fargs.txIndex, fargs.proof, vars.receiptsRoot)))[3]
vars.log = RLPReader.readList(vars.logs[i]);
if (address(bytes20(RLPReader.readBytes(vars.log[0]))) != nargs.emittingAddress) continue;
RLPReader.RLPItem[] memory topics = RLPReader.readList(vars.log[1]);
if (bytes32(RLPReader.readBytes(topics[0])) != vars.eventSignature) continue;
address stToken,
RLPReader.readBytes(vars.log[2]), (address, address[], uint256[], address[], uint256[], uint256[])
if (stToken != nargs.securityToken) continue;
vars.investorIndex = type(uint256).max;
vars.investorIndex = j;
break;
if (vars.investorIndex == type(uint256).max) continue; // Caller not in investor list
if (currencyTokenList[vars.investorIndex] != nargs.currencyToken) continue;
vars.logHash = _hashLog(vars.blockHash, vars.receiptsRoot, fargs.txIndex, i);
if (usedLogs[vars.logHash]) revert LogAlreadyUsed();
usedLogs[vars.logHash] = true;
emit Verified(
msg.sender,
return (quantityList[vars.investorIndex], amountList[vars.investorIndex]);
revert NoEvent();

Function: _getBlockHash
❌ Untouched lines:
bytes32 blockHash = blockhash(blockNumber);
blockHash = blockHashes[blockNumber];
if (blockHash == 0) revert MissedWindow();
return blockHash;

❌ Warning: Coverage 30% below threshold 70%
```

</details>

### DigiftAdapter

**Coverage:** 42.94%
`█████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 22 |
| Line Coverage | 42.94% |

### DigiftAdapterFactory

**Coverage:** 100%
`██████████████████████████████████████████████████`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 100% |

### DigiftEventVerifier

**Coverage:** 30%
`███████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 4 |
| Line Coverage | 30% |

## 💡 Recommendations

The following contracts need attention to meet the 70% coverage threshold:

- **Escrow**: Needs 70% improvement (current: 0%)
- **Node**: Needs 2.34% improvement (current: 67.66%)
- **ERC4626Router**: Needs 1.91% improvement (current: 68.09%)
- **ERC7540Router**: Needs 28.82% improvement (current: 41.18%)
- **FluidRewardsRouter**: Needs 50% improvement (current: 20%)
- **IncentraRouter**: Needs 45% improvement (current: 25%)
- **MerklRouter**: Needs 50% improvement (current: 20%)
- **OneInchV6RouterV1**: Needs 50.65% improvement (current: 19.35%)
- **QuoterV1**: Needs 70% improvement (current: 0%)
- **BaseComponentRouter**: Needs 7.84% improvement (current: 62.16%)
- **BaseQuoter**: Needs 70% improvement (current: 0%)
- **ErrorsLib**: Needs 70% improvement (current: 0%)
- **EventsLib**: Needs 70% improvement (current: 0%)
- **MathLib**: Needs 70% improvement (current: 0%)
- **RegistryAccessControl**: Needs 70% improvement (current: 0%)
- **DigiftAdapter**: Needs 27.06% improvement (current: 42.94%)
- **DigiftEventVerifier**: Needs 40% improvement (current: 30%)

### Next Steps:
1. Focus on contracts with coverage below 30% first
2. Add test cases for uncovered functions
3. Review and test edge cases
4. Run echidna with longer campaign for better coverage

---
*Report generated by echidna-coverage-analyzer.sh*
