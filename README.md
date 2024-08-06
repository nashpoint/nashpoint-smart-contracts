# bestia_v0

Bestia is an in-developement protocol that structures illiquid on chain credit assets into Liquid Yield Tokens, such as Real World Assets (RWAs). It implements innovative mechanisms for efficient capital allocation and risk management.

For more detailed information about the first pool that will launch on Bestia see the draft [WHITEPAPER](https://www.notion.so/punia/USDB-Whitepaper-WIP-External-a69ffd38e05f47999c1874fe8cf8a0b6)

## Key Features To Date

### 1. Asset Integration
- Supports both ERC4626 vaults for liquid assets and ERC7540 for illiquid assets/RWAs
- Mock implementation of ERC7540 to represent RWAs in the current prototype

### 2. Swing Pricing Mechanism
- Implements a dynamic pricing curve to manage deposits and withdrawals
- Protects the protocol and long-term holders from volatility and potential "bank runs"
- Adjusts the effective exchange rate based on the current reserve ratio

### 3.  Capital Allocation
- **Banker** role invests excess funds into various asset strategies
- Separate logic for investing in liquid (ERC4626) and illiquid (ERC7540) assets
- Maintains a target cash reserve ratio for liquidity management

### 4. Asynchronous Asset Handling
- Special handling for asynchronous assets (like RWAs) with pending deposits and redemptions
- Tracks pending transactions to maintain accurate total asset calculations

## Core Functions

- `totalAssets()`: Calculates the total value of all assets in the protocol
- `adjustedDeposit()` / `adjustedWithdraw()`: Apply swing pricing to deposits and withdrawals
- `investCash()`: Invests excess cash into liquid asset strategies
- `investInAsyncVault()`: Manages investments into illiquid/RWA strategies

## Technical Notes

- Built on Solidity ^0.8.20
- Custom implementation of ERC7540 for handling asynchronous assets

## Current Status

This is a work-in-progress prototype. Many of the core mechanisms are in place, but further testing and refinement are needed, especially around the integration of ERC7540 assets. As such, it is:

- Not safe
- Not gas optimized

## Next Steps

- Finalize and optimize the ERC7540 integration
- Improve the rebalancing and optimize for capital efficiency & risk management
- Integrate other RWA Protocols & Modular Architecture
- Rebasing Token for yield distribution
- Wrapped Token for defi integrations
- Factory model for permissionless pool creation
- Single vault contract for efficient rebalancing
- Decentralize rebalancing with auctions/intents

## Contributions

We welcome contributions and feedback. 

## Disclaimer

This is an experimental protocol. Use at your own risk. Not audited or ready for production use.
