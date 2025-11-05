# Echidna Coverage Report

**Generated:** 2025-11-05 14:39:15
**Coverage File:** `echidna-corpus/covered.1762349274.txt`
**Timestamp:** 1762349274

## 📊 Overall Summary

| Metric | Value |
|--------|-------|
| **Total Contracts** | 14 |
| **Contracts Below 70%** | 5 |
| **Overall Line Coverage** | 74.53% |
| **Total Lines** | 750 |
| **Covered Lines** | 559 |

⚠️ **Status:** 5 contract(s) below 70% coverage threshold

## 🔍 Coverage Analysis Against Scope

✅ All contracts in scope have coverage data.

## 📋 Contracts Coverage by Package

### 📦 Package:  src

| Contract | Coverage | Status | Functions | Details |
|----------|----------|--------|-----------|---------|
| 🟢 **Node** | 86.35% | ✅ Pass | 45 | [View](#node) |
| 🟢 **NodeFactory** | 75% | ✅ Pass | 1 | [View](#nodefactory) |
| 🟢 **NodeRegistry** | 86.96% | ✅ Pass | 13 | [View](#noderegistry) |
| 🟢 **ERC4626Router** | 75% | ✅ Pass | 6 | [View](#erc4626router) |
| 🟡 **ERC7540Router** | 60% | ❌ Fail | 10 | [View](#erc7540router) |
| 🟢 **FluidRewardsRouter** | 100% | ✅ Pass | 1 | [View](#fluidrewardsrouter) |
| 🟢 **IncentraRouter** | 100% | ✅ Pass | 1 | [View](#incentrarouter) |
| 🟢 **MerklRouter** | 83.33% | ✅ Pass | 1 | [View](#merklrouter) |
| 🟢 **OneInchV6RouterV1** | 100% | ✅ Pass | 3 | [View](#oneinchv6routerv1) |
| 🔴 **QuoterV1** | 0% | ❌ Fail | 0 | [View](#quoterv1) |
| 🟡 **BaseComponentRouter** | 59.46% | ❌ Fail | 7 | [View](#basecomponentrouter) |
| 🟡 **DigiftAdapter** | 67.63% | ❌ Fail | 22 | [View](#digiftadapter) |
| 🟢 **DigiftAdapterFactory** | 100% | ✅ Pass | 1 | [View](#digiftadapterfactory) |
| 🟠 **DigiftEventVerifier** | 30% | ❌ Fail | 4 | [View](#digifteventverifier) |



## 🔍 Detailed Contract Analysis

### Node

**Coverage:** 86.35%
`███████████████████████████████████████████░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 45 |
| Line Coverage | 86.35% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `fulfillRedeemRequest` | true | false | 8 |
| 1 | `investInAsyncComponent` | true | false | 1 |
| 2 | `mintClaimableShares` | true | false | 6 |
| 3 | `requestAsyncWithdrawal` | true | false | 3 |
| 4 | `_mint` | true | false | 1 |
| 5 | `_requestRedeem` | true | false | 1 |
| 6 | `_withdraw` | true | false | 1 |
| 7 | `_executeAsyncWithdrawal` | true | false | 7 |

## 🔍 Uncovered Code Lines

```solidity
📄 File: routers/ERC7540Router.sol
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
┌─────────┬───────────────────────────┬─────────┬──────────┬────────────────┐
```

```solidity
├─────────┼───────────────────────────┼─────────┼──────────┼────────────────┤
```

```solidity
└─────────┴───────────────────────────┴─────────┴──────────┴────────────────┘
```

### Function: `fulfillRedeemRequest`

```solidity
❌ Untouched lines:
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
revert InsufficientSharesReturned(component, 0, claimableShares);
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
revert ExceedsAvailableShares(node, component, shares);
```

```solidity
revert IncorrectRequestId(requestId);
```

```solidity
emit RequestedAsyncWithdrawal(node, component, shares);
```

### Function: `_mint`

```solidity
❌ Untouched lines:
```

```solidity
return abi.decode(result, (uint256));
```

### Function: `_requestRedeem`

```solidity
❌ Untouched lines:
```

```solidity
return abi.decode(result, (uint256));
```

### Function: `_withdraw`

```solidity
❌ Untouched lines:
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
❌ Warning: Coverage 60% below threshold 70%
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
│ coveredLines               │ 42     │
│ revertedLines              │ 0      │
│ untouchedLines             │ 28     │
│ functionCoveragePercentage │ 20     │
│ lineCoveragePercentage     │ 60     │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬───────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName              │ touched │ reverted │ untouchedLines │
├─────────┼───────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'fulfillRedeemRequest'    │ true    │ false    │ 8              │
│ 1       │ 'investInAsyncComponent'  │ true    │ false    │ 1              │
│ 2       │ 'mintClaimableShares'     │ true    │ false    │ 6              │
│ 3       │ 'requestAsyncWithdrawal'  │ true    │ false    │ 3              │
│ 4       │ '_mint'                   │ true    │ false    │ 1              │
│ 5       │ '_requestRedeem'          │ true    │ false    │ 1              │
│ 6       │ '_withdraw'               │ true    │ false    │ 1              │
│ 7       │ '_executeAsyncWithdrawal' │ true    │ false    │ 7              │
└─────────┴───────────────────────────┴─────────┴──────────┴────────────────┘

Function: fulfillRedeemRequest
❌ Untouched lines:
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
revert InsufficientSharesReturned(component, 0, claimableShares);
sharesReceived = balanceAfter - balanceBefore;
revert InsufficientSharesReturned(component, sharesReceived, claimableShares);
emit MintedClaimableShares(node, component, sharesReceived);
return sharesReceived;

Function: requestAsyncWithdrawal
❌ Untouched lines:
revert ExceedsAvailableShares(node, component, shares);
revert IncorrectRequestId(requestId);
emit RequestedAsyncWithdrawal(node, component, shares);

Function: _mint
❌ Untouched lines:
return abi.decode(result, (uint256));

Function: _requestRedeem
❌ Untouched lines:
return abi.decode(result, (uint256));

Function: _withdraw
❌ Untouched lines:
return abi.decode(result, (uint256));

Function: _executeAsyncWithdrawal
❌ Untouched lines:
revert ExceedsAvailableAssets(node, component, assets);
uint256 balanceAfter = IERC20(asset).balanceOf(address(node));
revert InsufficientAssetsReturned(component, 0, assets);
assetsReceived = balanceAfter - balanceBefore;
revert InsufficientAssetsReturned(component, assetsReceived, assets);
emit AsyncWithdrawalExecuted(node, component, assetsReceived);
return assetsReceived;

❌ Warning: Coverage 60% below threshold 70%
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

## 🔍 Uncovered Code Lines

```solidity
📄 File: quoters/QuoterV1.sol
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
❌ Warning: Coverage 0% below threshold 70%
```


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

### NodeRegistry

**Coverage:** 86.96%
`███████████████████████████████████████████░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 13 |
| Line Coverage | 86.96% |

## ⚠️ Uncovered Functions

| Index | Function Name | Touched | Reverted | Untouched Lines |
|-------|---------------|---------|----------|----------------|
| 0 | `setBlacklistStatus` | false | false | 3 |
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

```solidity
emit EventsLib.ComponentBlacklisted(component, status);
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
❌ Warning: Coverage 59.46% below threshold 70%
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
│ coveredLines               │ 22     │
│ revertedLines              │ 0      │
│ untouchedLines             │ 15     │
│ functionCoveragePercentage │ 42.86  │
│ lineCoveragePercentage     │ 59.46  │
└────────────────────────────┴────────┘

⚠️ Not fully covered functions:
┌─────────┬───────────────────────────┬─────────┬──────────┬────────────────┐
│ (index) │ functionName              │ touched │ reverted │ untouchedLines │
├─────────┼───────────────────────────┼─────────┼──────────┼────────────────┤
│ 0       │ 'setBlacklistStatus'      │ false   │ false    │ 3              │
│ 1       │ 'batchSetWhitelistStatus' │ false   │ false    │ 7              │
│ 2       │ 'setTolerance'            │ false   │ false    │ 2              │
│ 3       │ '_subtractExecutionFee'   │ true    │ false    │ 3              │
└─────────┴───────────────────────────┴─────────┴──────────┴────────────────┘

Function: setBlacklistStatus
❌ Untouched lines:
if (component == address(0)) revert ErrorsLib.ZeroAddress();
isBlacklisted[component] = status;
emit EventsLib.ComponentBlacklisted(component, status);

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

❌ Warning: Coverage 59.46% below threshold 70%
```

</details>

### ERC4626Router

**Coverage:** 75%
`█████████████████████████████████████░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 6 |
| Line Coverage | 75% |

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
| 7 | `settleDeposit` | true | false | 2 |
| 8 | `mint` | true | false | 1 |
| 9 | `settleRedeem` | true | false | 18 |
| 10 | `withdraw` | false | false | 12 |
| 11 | `deposit` | false | false | 1 |
| 12 | `deposit` | false | false | 1 |
| 13 | `mint` | false | false | 1 |
| 14 | `redeem` | false | false | 1 |
| 15 | `setOperator` | false | false | 1 |

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

### Function: `settleDeposit`

```solidity
❌ Untouched lines:
```

```solidity
sharesToMint += shares - vars.totalSharesToMint;
```

```solidity
assetsToReimburse += assets - vars.totalAssetsToReimburse;
```

### Function: `mint`

```solidity
❌ Untouched lines:
```

```solidity
IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);
```

### Function: `settleRedeem`

```solidity
❌ Untouched lines:
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
❌ Warning: Coverage 67.63% below threshold 70%
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
│ fullyCoveredFunctions      │ 6      │
│ coveredLines               │ 117    │
│ revertedLines              │ 0      │
│ untouchedLines             │ 56     │
│ functionCoveragePercentage │ 27.27  │
│ lineCoveragePercentage     │ 67.63  │
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
│ 7       │ 'settleDeposit'           │ true    │ false    │ 2              │
│ 8       │ 'mint'                    │ true    │ false    │ 1              │
│ 9       │ 'settleRedeem'            │ true    │ false    │ 18             │
│ 10      │ 'withdraw'                │ false   │ false    │ 12             │
│ 11      │ 'deposit'                 │ false   │ false    │ 1              │
│ 12      │ 'deposit'                 │ false   │ false    │ 1              │
│ 13      │ 'mint'                    │ false   │ false    │ 1              │
│ 14      │ 'redeem'                  │ false   │ false    │ 1              │
│ 15      │ 'setOperator'             │ false   │ false    │ 1              │
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

Function: settleDeposit
❌ Untouched lines:
sharesToMint += shares - vars.totalSharesToMint;
assetsToReimburse += assets - vars.totalAssetsToReimburse;

Function: mint
❌ Untouched lines:
IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);

Function: settleRedeem
❌ Untouched lines:
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

❌ Warning: Coverage 67.63% below threshold 70%
```

</details>

### ERC7540Router

**Coverage:** 60%
`██████████████████████████████░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 10 |
| Line Coverage | 60% |

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

### FluidRewardsRouter

**Coverage:** 100%
`██████████████████████████████████████████████████`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 100% |

### IncentraRouter

**Coverage:** 100%
`██████████████████████████████████████████████████`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 100% |

### MerklRouter

**Coverage:** 83.33%
`█████████████████████████████████████████░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 1 |
| Line Coverage | 83.33% |

### OneInchV6RouterV1

**Coverage:** 100%
`██████████████████████████████████████████████████`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 3 |
| Line Coverage | 100% |

### QuoterV1

**Coverage:** 0%
`░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 0 |
| Line Coverage | 0% |

### BaseComponentRouter

**Coverage:** 59.46%
`█████████████████████████████░░░░░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 7 |
| Line Coverage | 59.46% |

### DigiftAdapter

**Coverage:** 67.63%
`█████████████████████████████████░░░░░░░░░░░░░░░░░`

## 📈 Coverage Statistics

| Metric | Value |
|--------|-------|
| Total Functions | 22 |
| Line Coverage | 67.63% |

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

- **ERC7540Router**: Needs 10% improvement (current: 60%)
- **QuoterV1**: Needs 70% improvement (current: 0%)
- **BaseComponentRouter**: Needs 10.54% improvement (current: 59.46%)
- **DigiftAdapter**: Needs 2.37% improvement (current: 67.63%)
- **DigiftEventVerifier**: Needs 40% improvement (current: 30%)

### Next Steps:
1. Focus on contracts with coverage below 30% first
2. Add test cases for uncovered functions
3. Review and test edge cases
4. Run echidna with longer campaign for better coverage

---
*Report generated by echidna-coverage-analyzer.sh*
