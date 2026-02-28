# WTAdapter

WTAdapter is an ERC7540 async adapter for WisdomTree funds. Nodes submit async requests, managers settle them by proving WT `Transfer` logs, and adapter shares are minted/burned from those settlements.

## Roles

- Registry owner: whitelists managers/nodes, sets limits/deviations, updates WT receiver/sender addresses.
- Manager: forwards batches, settles deposit/redeem/dividend proofs, controls price freeze, updates cached price.
- Node: requests deposit/redeem, then claims via `mint` / `withdraw`.

## Core flow

- Deposit: `requestDeposit` (assets escrowed) -> `forwardRequests` (assets sent to `receiverAddress`) -> `settleDeposit` (verifies fund mint from zero) -> node `mint` (must mint exact `maxMint`).
- Redeem: `requestRedeem` (shares escrowed) -> `forwardRequests` (fund shares sent to `receiverAddress`) -> `settleRedeem` (verifies asset transfer from `senderAddress`) -> node `withdraw` (must withdraw exact `maxWithdraw`, burns used shares).
- Dividend (DRIP shares only): `settleDividend` requires no pending forwarded batches and a strictly sorted unique `nodes` list. It verifies fund mint-to-adapter and mints shares pro-rata by:
  `weight = balanceOf(node) + pendingRedeemRequest + maxMint`
  with dust assigned to the last node.

## Dividend constraints

- Settlement reverts with `NotAllNodesSettled` when provided nodes do not match the full accounted set.
- Emits `DividendPaid(node, sharesOut)` for each paid node and `DividendSettled(fundShares, minted)` once per settlement.

## Price freeze

- `startPriceFreeze(duration)` (max 7 days) blocks `forwardRequests` and `updateLastPrice`.
- While `priceFreezeActive && block.timestamp <= priceFreezeUntil`, conversions use cached `lastFundPrice`.
- Manager must call `endPriceFreeze`; timeout alone does not unblock operations.

## Upgradeability

- `WTAdapterFactory` uses `UpgradeableBeacon`; a beacon upgrade updates all deployed WT adapters.
