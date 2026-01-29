Deploy the demo node to Arbitrum

Prerequisites:

- Install deps once: `npm install`.
- .env must include `ARBITRUM_RPC_URL` and `ARBITRUM_PRIVATE_KEY` (wallet funded with >1 USDC + gas).

Prepare the config:

- Edit `deployments/nodes/arbitrum/Demo.json`.
- Set a fresh `salt` every deployment to avoid address collisions.
- Adjust `name`/`symbol` if desired. Leave `asset` as Arbitrum USDC unless you know you need a different token.
- `seedValue` is denominated in the asset’s whole units (1 = 1 USDC). Ensure the deployer wallet holds at least that amount.
- Confirm owner/whitelist/pauser/rebalancer addresses are correct for this run.

Deploy

- Run `npm run deploy:node` (uses `FILE=Demo` on `--network arbitrum`).
- Console output: deployed node address and tx hash.
