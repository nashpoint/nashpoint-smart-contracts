# NashPoint
[![Foundry](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/foundry.yml/badge.svg)](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/foundry.yml) [![Slither Analysis](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/slither-actions.yml/badge.svg)](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/slither-actions.yml)
[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](LICENSE)

NashPoint enables flexible deployment of investment nodes that can manage positions across multiple ERC4626 and ERC7540 vaults. The protocol was designed to provide a standardized way to manage complex investment strategies. Investors can deposit and redeem using the ERC7540 asynchronous tokenized vault standard.

## Architecture

### Smart Contracts:

- **Node**: An ERC7540-compliant vault that enables investors to deposit and withdraw assets. The Node manages component allocations and delegates execution to Routers.
- **NodeRegistry**: Central registry that manages system-wide permissions for factories, routers, quoters, and rebalancers, ensuring secure access control across the protocol.
- **NodeFactory**: Handles the deployment of new Node instances and their associated contracts.
- **Escrow**: Securely holds assets during pending deposit and redemption operations.
- **QueueManager**: Handles the deposit and redemption queue logic, tracking pending requests and managing claim windows.

- **Routers**: Specialized contracts that execute operations on component vaults:
  - ERC4626Router: Manages interactions with standard ERC4626 vaults
  - ERC7540Router: Manages interactions with asynchronous ERC7540 vaults
- **Quoters**:
  - QuoterV1: Provides price information for Node shares by aggregating component valuations.

### Key Roles:
**Owner:** Owns the node. Sets the strategy by selecting the underlying assets and what proportions to allocate into them. Also sets the parameters for features like swing pricing and rebalancing frequency.
**Rebalancer:** Address set by the owner. Has allowances to execute asset management functions such as investing to a strategy or processing a user withdrawal according to the parameters defined by the owner.

## License

This project is licensed under the BUSL-1.1 License - see the [LICENSE](LICENSE) file for details.

### Technical Notes

- Built on Solidity 0.8.26
- Custom implementation of ERC7540 for handling asynchronous assets

### Development

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
