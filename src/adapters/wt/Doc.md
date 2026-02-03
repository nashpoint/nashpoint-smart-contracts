WTAdapter wraps a WisdomTree fund into an ERC7540 async vault. It batches node requests, proves WT `Transfer` logs, and mints/burns adapter shares accordingly.

## Roles

- Registry owner: whitelists managers/nodes, tunes price/settlement limits.
- Manager: forwards batches, settles proofs, runs dividend flow, updates price cache.
- Node: initiates deposits/redeems and later claims/withdraws.

## Flows

- Deposit: `requestDeposit` → assets escrowed. `forwardRequests` sends assets to WT wallet and sets `pendingDepositRequest`. `settleDeposit` verifies mint-from-zero log, records per-node entitlements. `mint` mints exact `maxMint` shares to node (plus asset reimbursement if any).
- Redemption: `requestRedeem` escrows shares. `forwardRequests` sends shares to WT. `settleRedeem` verifies asset-transfer-from-sender log, records claimable assets and share reimbursements. `withdraw` burns used shares and transfers assets.
- Dividend (DRIP-style): `settleDividend` only when `pendingDepositRequest == 0` and `pendingRedeemRequest == 0`. Verifies mint-from-zero WT dividend to adapter, then mints adapter shares pro‑rata by weight = `balance + pendingRedeemRequest + claimableRedeemRequest + maxMint` for each supplied node; dust goes to last. Reverts if supplied node list is incomplete (`NotAllNodesSettled`).

## NAV & price behavior

- NAV accrues income; on ex‑div it drops. `_getFundPrice` enforces deviation vs `lastFundPrice`; managers/owner should refresh `lastFundPrice` around ex‑div (or set wider `priceDeviation`) to avoid reverts during settlements.

## Fairness/edge cases

- Dividends are blocked while a deposit/redeem batch is pending to avoid consuming the log in the wrong flow; once pending == 0, unclaimed deposit entitlements (`maxMint`) and parked redeem shares are included in weights so those nodes aren’t shorted.
- If Node requested redeem and mints before `settleDividend` it will loose it's part of dividend. Probability is low and impact is negligible.
- Based on the above statement - if there was one Node which completely exited the WTAdapter - dividend may be not settled and this dividend will get stuck until some new Node would create a position.
- If managers omit a node in `settleDividend`, it reverts. Large node lists can be gas-heavy; consider batching or future accumulator if needed.
- Cash dividends are not handled; only share-mint DRIP style is supported. Introducing cash would require a separate handler and price/backing adjustments.

## Upgradeability

- `WTAdapterFactory` is an `UpgradeableBeacon`; a single beacon upgrade updates all deployed adapters without touching their storage.
