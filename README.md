# bestia_v0

Bestia is an in-development protocol that structures illiquid on chain credit assets, such as Real World Assets (RWAs), into Liquid Yield Tokens. It implements innovative mechanisms for efficient capital allocation and risk management.

For more detailed information about the first pool that will launch on Bestia see the draft [Whitepaper](https://www.notion.so/punia/USDB-Whitepaper-WIP-External-a69ffd38e05f47999c1874fe8cf8a0b6)


## Features

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

## Current Status

This is a work-in-progress prototype. Many of the core mechanisms are in place, but further testing and refinement are needed, especially around the integration of ERC7540 assets. As such, it is:

- Not safe
- Not gas optimized

## Next Steps

- [ ] Finalize and optimize the ERC7540 integration
    - [ ] Make sure the 7540Mock is fair and complete its functions
    - [ ] Fuzz & Invariant Testing
- [ ] Create Separate User-Facing Token
    - [ ] Rebasing Token for yield distribution
    - [ ] Wrapped Token for defi integrations
- [ ] Modular Architecture    
    - [ ] Split Functionality over Modules and Libraries
    - [ ] Integrate other RWA Protocols 
    - [ ] Single vault contract for efficient rebalancing
    - [ ] Factory model for permissionless pool creation

### Post Launch

- [ ] Improve the rebalancing and optimize for capital efficiency & risk management
- [ ] Decentralize rebalancing with auctions/intents

## Contributions

We welcome contributions and feedback. 

## Disclaimer

This is an experimental protocol. Use at your own risk. Not audited or ready for production use.

## Technical Notes

- Built on Solidity ^0.8.20
- Custom implementation of ERC7540 for handling asynchronous assets

## Getting Started

This project uses Foundry for development and testing. Follow these steps to get the project up and running on your local machine.

### Prerequisites

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

### Setup

1. Clone the repository:

```
git clone [https://github.com/0xCSMNT/bestia_v0.git](https://github.com/0xCSMNT/bestia_v0)

cd bestia_v0
```
Install dependencies:

```
forge install
```
Update Foundry:

```
foundryup
```

### Building
Compile the contracts:
```
forge build
```

### Testing
Run the test suite:
```
forge test
```

recreate the issue:
```
forge test --match-test testCanAddAddressToVault --fork-url $ETHEREUM_RPC_URL --fork-block-number 20591573 --evm-version cancun -vvvvv
```
