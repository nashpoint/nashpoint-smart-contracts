<h1>  
  CONSTELLATION
</h1>

Constellation is an in-development protocol that structures illiquid on chain credit assets, such as Real World Assets (RWAs), into Liquid Yield Tokens. It implements innovative mechanisms for efficient capital allocation and risk management.

For more detailed information about the first pool that will launch on see the draft [WHITEPAPER](https://www.notion.so/punia/USDB-Whitepaper-WIP-External-a69ffd38e05f47999c1874fe8cf8a0b6)

Currenty this is being built as a single 4626 vault that can handle investment logic for the user. Future features include :
- Modular smart contract design pattern for upgradeability
- Core contract for handling verification and security
- Factory Contract for deploying new vaults
- Governance and $TOKEN
- Staking Module for $TOKEN (backstop protocol liquidity)


## Features

### 1. Asset Integration
- Supports both ERC4626 vaults for liquid assets and ERC7540 for illiquid assets/RWAs
- Mock implementation of ERC7540 to represent RWAs in the current prototype

### 2. Swing Pricing Mechanism
- Implements a dynamic pricing curve to manage deposits and withdrawals
- Protects the protocol and long-term holders from volatility and potential "bank runs"
- Adjusts the effective exchange rate based on the current reserve ratio

### 3.  Capital Allocation
- **Rebalancer** role invests excess funds into various asset strategies
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

- Built on Solidity 0.8.26
- Custom implementation of ERC7540 for handling asynchronous assets

## Getting Started

This project uses Foundry for development and testing. Follow these steps to get the project up and running on your local machine.

### Prerequisites

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

### Setup

1. Clone the repository:

```
git clone https://github.com/0xCSMNT/constellation.git

cd constellation
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
Run the test suite locally with anvil:
```
forge test
```

Run the [fork tests]([url](https://github.com/0xCSMNT/constellation/blob/main/test/forked/ForkedTests.t.sol)) on Centrifuge Liquidity Pool:
```
forge test --match-contract ForkedTests --fork-url $ETHEREUM_RPC_URL --fork-block-number 20591573 --evm-version cancun
```

Forked Tests require an Ethereum mainnet RPC URL:

```
# MAINNET RPC URLS
ETHEREUM_RPC_URL=
```

#### CONTRACT & STATE OF FORK TEST:
https://etherscan.io/address/0x1d01ef1997d44206d839b78ba6813f60f1b3a970
- Taken from block 20591573
- EVM version: cancun
