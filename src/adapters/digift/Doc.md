This contract wraps DigiFT stTokens in an ERC7540-compatible vault. It handles the full lifecycle of deposit and redemption requests, coordinates settlement with the DigiFT SubRedManagement contract and validates settlement proofs before funds move.

## Components
- **DigiftAdapter**: Beacon-implementation ERC20 that tracks per-node state. It accepts deposit and redemption requests, aggregates them globally and mints/burns adapter shares after settlement.
- **DigiftAdapterFactory**: Beacon factory that deploys new adapter proxies. Each proxy points at the shared implementation while keeping isolated storage and configuration.
- **DigiftEventVerifier**: Proof verifier that checks DigiFT `SettleSubscriber` and `SettleRedemption` events against Merkle Patricia trie proofs. It prevents double claims by tracking log hashes and enforces registry-gated access.

## Upgradeability Model
- The factory inherits `UpgradeableBeacon`, so the owner governs the implementation used by every deployed adapter proxy.
- `deploy` instantiates a `BeaconProxy` pointing to the beacon and runs `DigiftAdapter.initialize` with caller-supplied `InitArgs` (token metadata, asset/oracle addresses, price guardrails).
- Upgrades are executed once on the beacon and propagate to all adapter proxies without touching their storage.

## Roles and Access Control
- **Registry owner** manages manager/node whitelists and tuning knobs (`setPriceDeviation`, `setPriceUpdateDeviation`, `setManager`, `setNode`).
- **Managers** (whitelisted accounts) bridge on-chain actions with DigiFT: updating cached prices, forwarding aggregated requests, and settling events.
- **Nodes** (whitelisted registry nodes) originate deposit/redemption requests and later claim the settled results.

## Price Controls
- The adapter caches DigiFT prices (`lastPrice`) and guards updates via `priceDeviation` and `priceUpdateDeviation`. Managers call `updateLastPrice`, while the owner can force refresh when exceptional deviation occurs.
- Asset-side pricing uses an external oracle and the same staleness guard.

## Deposit Lifecycle
1. **Request**: A whitelisted node invokes `requestDeposit`, transferring assets into the adapter. The node’s `NodeState` records the pending amount and the global accumulator increases.
2. **Forward**: A manager batches requests using `forwardRequestsToDigift`, which subscribes the aggregated assets via `subRedManagement`. Pending volume moves from `accumulatedDeposit` to `pendingDepositRequest` while the SubRedManagement contract holds the funds.
3. **Verify & Settle**: After DigiFT emits `SettleSubscriber`, a manager calls `settleDeposit` with:
   - `nodes`: array of nodes to settle.
   - `verifyArgs`: Merkle proof bundle consumed by `DigiftEventVerifier` to confirm the on-chain event.
   The verifier decodes the settlement amounts and the adapter prorates shares/assets across nodes, updates per-node state, and emits `DepositSettled` events.
4. **Mint**: Each node completes the flow with `mint`, which requires minting the exact `maxMint` value. Any excess asset reimbursement recorded during settlement is returned before the adapter emits the canonical `Deposit` event.

## Redemption Lifecycle
1. **Request**: A node uses `requestRedeem`, transferring adapter shares into escrow and increasing global redemption accumulation.
2. **Forward**: Managers relay redemptions to DigiFT via `forwardRequestsToDigift`. Shares move from `accumulatedRedemption` to `pendingRedeemRequest` and are approved for the SubRedManagement contract.
3. **Verify & Settle**: Post `SettleRedemption`, managers call `settleRedeem` with proof data. The adapter verifies the DigiFT log, allocates returned assets and reimbursable shares, and emits `RedeemSettled` per node.
4. **Withdraw**: Nodes call `withdraw` (requires `maxWithdraw` amount), which burns the utilized shares, returns any reimbursed shares and transfers the settled assets.

## Event Verification Flow
- Managers batch Merkle proof inputs into `DigiftEventVerifier.verifySettlementEvent`, which:
  1. Validates the supplied block header against stored or recent block hashes.
  2. Reconstructs the receipt Merkle path to find the DigiFT settlement log.
  3. Checks the log signature, emitting contract, token addresses and investor against the expected values.
  4. Computes a log hash and rejects any reuse (double-spend protection).
- Upon success it returns the stToken and asset amounts, which the adapter uses for proportional settlement. A `Verified` event records the proof metadata for auditing.

## State Tracking and Guards
- `NodeState` keeps pending, claimable, and reimbursement amounts for both deposits and redemptions, preventing overlapping requests (`_nothingPending`).
- `GlobalState` tracks total accumulated deposits/redemptions awaiting forwarding and the currently pending volume waiting for DigiFT settlement.
- Additional checks enforce full execution (`MintAllSharesOnly`, `WithdrawAllAssetsOnly`) so reconciliations remain exact and `NothingToSettle` prevents settlement without pending volume.
