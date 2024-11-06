# Nashpoint
[![Foundry](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/foundry.yml/badge.svg)](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/foundry.yml) [![Slither Analysis](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/slither-actions.yml/badge.svg)](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/slither-actions.yml)
[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](LICENSE)

Node Protocol enables flexible deployment of investment nodes that can manage positions across multiple ERC4626 and ERC7540 vaults. The protocol was designed to provide a standardized way to manage complex investment strategies. Investors can deposit and redeem using the ERC7540 asynchronous tokenized vault standard.

## How it works

### Architecture

Each Node deployment consists of three core contracts that work together to manage investments:

- **Node**: An ERC7540-compatible contract that enables investors to deposit and withdraw assets. The Node manages component allocations and delegates execution to Routers.

- **QueueManager**: Handles the deposit and redemption queue logic, tracking pending requests and managing claim windows.

- **Escrow**: Securely holds assets during pending deposit and redemption operations.

The deployment and operation of Nodes is facilitated by several supporting contracts:

- **NodeFactory**: Handles the deployment of new Node instances and their associated contracts.

- **Routers**: Specialized contracts that execute operations on component vaults:
  - ERC4626Router: Manages interactions with standard ERC4626 vaults
  - ERC7540Router: Manages interactions with asynchronous ERC7540 vaults

- **Quoter**: Provides price information for Node shares by aggregating component valuations.

## Key Features

- ERC7540-compatible deposit and redemption queues
- Support for both ERC4626 and ERC7540 component vaults
- Flexible allocation management
- Permissioned routing system
- Price quotation system

## License

This project is licensed under the BUSL-1.1 License - see the [LICENSE](LICENSE) file for details.

### Technical Notes

- Built on Solidity 0.8.26
- Custom implementation of ERC7540 for handling asynchronous assets

### Getting Started

This project uses Foundry for development and testing. Follow these steps to get the project up and running on your local machine.

#### Prerequisites

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

#### Setup

1. Clone the repository:

```
git clone https://github.com/nashpoint/nashpoint-smart-contracts

cd nashpoint-smart-contracts
```
Install dependencies:

```
forge install
```
Update Foundry:

```
foundryup
```

#### Building
Compile the contracts:
```
forge build
```

#### Testing
Run the test suite locally with anvil:
```
forge test
```
