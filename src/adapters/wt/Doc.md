This adapter wraps WisdomTree fund shares in an ERC7540-compatible vault. It aggregates node requests, forwards them to WT, and settles based on on-chain `Transfer` events proven via `TransferEventVerifier`.

## Components
- **WTAdapter**: Beacon-implementation ERC20 that tracks per-node state via `AdapterBase`. It batches deposit/redemption requests, verifies settlement proofs, and mints/burns adapter shares.
- **WTAdapterFactory**: Beacon factory deploying new WTAdapter proxies. Each proxy shares code but keeps isolated storage/config.
- **TransferEventVerifier**: Proof verifier that checks ERC20 `Transfer` logs against Merkle Patricia trie proofs. It enforces registry-gated access and prevents double claims by tracking log hashes.

## Upgradeability Model
- The factory inherits `UpgradeableBeacon`; the beacon owner governs the implementation used by every deployed WTAdapter proxy.
- `deploy` creates a `BeaconProxy` pointing to the beacon and runs `AdapterBase.initialize` with caller-supplied `InitArgs` (token metadata, asset/fund addresses, oracles, price guardrails).
- Upgrades occur once on the beacon and propagate to all proxies without touching their storage.

## Roles and Access Control
- **Registry owner** manages manager/node whitelists and tuning knobs exposed by `AdapterBase` (price/settlement deviations, min amounts).
- **Managers** (whitelisted accounts) bridge on-chain actions with WT: updating cached prices, forwarding aggregated requests, and settling events using proofs.
- **Nodes** (whitelisted registry nodes) originate deposit/redemption requests and later claim settled results.

## Deposit Lifecycle
1. **Request**: A whitelisted node calls `requestDeposit`, transferring assets to the adapter. Pending amounts are tracked per-node and globally.
2. **Forward**: A manager calls `forwardRequests`, moving accumulated deposits to `pendingDepositRequest` and transferring assets to the WT receiver wallet via `_fundDeposit` (sends underlying asset).
3. **Verify & Settle**: After WT mints fund shares and emits a `Transfer` to the adapter, a manager calls `settleDeposit` with:
   - `nodes`: array of nodes to settle.
   - `verifyArgs`: Merkle proof bundle consumed by `TransferEventVerifier` to confirm the `Transfer` (from `address(0)`, to adapter, token = fund).
   The adapter prorates shares/assets across nodes, updates node state, and emits `DepositSettled`.
4. **Mint**: Nodes call `mint` to claim exactly `maxMint` shares; any recorded asset reimbursement is returned before emitting the ERC7540 `Deposit`.

## Redemption Lifecycle
1. **Request**: A node calls `requestRedeem`, moving adapter shares into escrow and increasing global redemption accumulation.
2. **Forward**: Managers call `forwardRequests`, moving redemption volume to `pendingRedeemRequest` and sending fund shares to the WT receiver via `_fundRedeem`.
3. **Verify & Settle**: After WT sends underlying assets back and emits a `Transfer` to the adapter, managers call `settleRedeem` with proof data. The adapter verifies the log (token = asset, from `senderAddress`), allocates returned assets plus any share reimbursement, and emits `RedeemSettled`.
4. **Withdraw**: Nodes call `withdraw` for the exact `maxWithdraw`; it burns used shares, returns any reimbursed shares, and transfers settled assets.

## Event Verification Flow
- Managers supply Merkle proof inputs to `TransferEventVerifier.verifyEvent`, which:
  1. Validates the provided block header via stored/recent block hashes.
  2. Reconstructs the receipt Merkle path to locate the `Transfer` log.
  3. Checks topics (`Transfer` selector, expected `from`/`to`) and token address against expectations.
  4. Computes a log hash and rejects reuse (double-spend protection).
- On success it returns the transferred amount; the adapter uses it for proportional settlement and emits a `Verified` event from the verifier for auditability.

## State Tracking and Guards (inherited from AdapterBase)
- `NodeState` tracks pending, claimable, and reimbursement amounts for deposits/redemptions, preventing overlapping requests.
- `GlobalState` tracks accumulated and pending volumes awaiting settlement.
- Guard rails enforce full execution (`MintAllSharesOnly`, `WithdrawAllAssetsOnly`), settlement deviation bounds (`settlementDeviation`), and prevent empty settlements (`NothingToSettle`). Price deviation/staleness checks rely on fund and asset oracles set during initialization.
