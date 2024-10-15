# NashPoint 
[![Foundry](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/foundry.yml/badge.svg)](https://github.com/nashpoint/nashpoint-smart-contracts/actions/workflows/foundry.yml)

NashPoint is a in-development onchain banking system. Asset managers can permissionlessly create nodes that can accept user funds and invest them in various DeFi and RWA assets. All logic to express the strategy is held on the Node contract - customer deposits, target weightings, rebalance cooldown, maximum deviation from target weighting, accepted rebalancer addresses etc. All actions to execute the strategy are carried out by the rebalancer. This includes executing the transactions to invest user assets, liquidating underlying assets to meet withdrawal demand, and processessing withdrawal requests by making user funds available for withdrawal.

The core unit of the protocol is the node contract that is created by the owner. Each instance of these contracts is not an isolated vault, but instead a node in a network of liquidity. All actions to execute the individual strategy of a node can all be executed at a protocol-wide level. This include investing in assets, liquidating the underlying, rebalancing towards new target weightings. Asset managers benefit from greater capital efficiency due to the combined liquidity of a multitude of nodes aggregating their liquidity. The rebalancer address can see the state of all nodes in the network at any time, and aggregate actions to push multiple nodes towards their strategy in a single transaction.

At launch NashPoint, will invest to Centrifuge liquidity pools via an ERC-7540 integration, and to any (compliant) ERC4626 vault on the Arbitrum ecosystem.

## Architecture

### Smart Contracts:
- **Node.sol** contains all of the asset managment and user interactions logic. 
- **NodeFactory.sol** is used to permissionlessly create Nodes. 
- **Escrow.sol** is unique to each Node. It holds shares and assets for user funds that are being withdrawn from the Node.

### Key Roles:
**Owner:** Owns the node. Sets the strategy by selecting the underlying assets and what proportions to allocate into them. Also sets the parameters for features like swing pricing and rebalancing frequency.

**Rebalancer:** Address set by the owner. Has allowances to execute asset management functions such as investing to a strategy or processing a user withdrawal according to the parameters defined by the owner.

## Interacting with a Node

### Deposits & Mints (ERC4626)
A Node is an async withdrawal ERC-7540 vault. Deposits follow a standard ERC-4626 interface. Users deposit assets to receive shares that are a pro-rata receipt for their holdings in the node contract.

### Withdrawals & Redemptions (ERC7540)
Withdrawals follow an ERC-7540 interface. To withdraw from the node, a user must `requestRedeem()`. During this transaction, their shares are returned to the node and held at the Escrow address. Their request is stored in a pending state until a rebalancer account processes the redemption and updates the request status to claimable. When a pending request is made claimable, the user’s shares at the escrow address are burned, and assets that can be withdrawn are moved to the escrow address. A `maxWithdrawal` allowance is set for the user by the rebalancer.

### Swing Pricing
Nodes implement a swing pricing mechanism to disincentivize speculative withdrawals. An owner can define a target percentage of the deposit asset for the node to hold. While the node holdings are below this target percentage, a discount will be applied to withdrawals to disincentivize further withdrawals. Users who request to redeem from the node will see their returned assets reduced by the swing factor. The swing factor increases on an exponential function until a maximum swing factor is applied.

The swing factor is also applied to deposits. If there is a delta between the current reserve ratio and the target reserve ratio, depositor will be rewarded with a additional shares based on the proportion of the delta their deposit helps to close.

These two applications of swing pricing in tandem should help to incentivize more a consistent stock of reserve liquidity.

#### Swing pricing owner controls:
- **TargetReserveRatio**: the ratio of the asset to hold proportional to `totalAssets()`. When Current Reserve Ratio == TargetReserveRatio, swing factor = 0.
- **MaxDiscount**: the maximum discount to be applied to a withdrawal request. When Current Reserve Ratio == 0, MaxDiscount is applied to withdrawal requests.

As an example, an owner can set `TargetReserveRatio = 10e16` (10%) and `MaxDiscount = 2e16` (2%). When there is 10% or greater deposit asset, zero swing factor will be applied to redeem requests. When there is zero cash in the reserve, a 2% discount will be applied to redeem requests. All values from a current reserve ratio of zero to `TargetReserveRatio` are defined by the function:

$$\text{Discount} = \text{maxDiscount} \times e^{\frac{\text{scalingFactor}}{\text{TargetReserveRatio}} \times \text{ReserveRatioAfterTx}}$$

The discount is also in effect for depositors. When the reserve ratio is below target, a depositor will receive shares that are discounted by the swing factor. This incentivizes users to keep the reserve ratio at or near the target. While the reserve ratio is below target, there is an arbitrage opportunity for users to take a position in the vault for below NAV price.

## Asset Management
A node is able to allocate user-deposited funds to a pre-defined portfolio of underlying assets. It contains the logic to allocate to and interact with synchronous vaults that follow the ERC-4626 standard, and asynchronous vaults that follow the ERC-7540 standard.

For more on ERC-7540, see the [EIP](https://eips.ethereum.org/EIPS/eip-7540).

#### Synchronous Asset Management (ERC-4626)
- `investInSyncVault()`
- `liquidateSyncVaultPosition()`

Both are `onlyRebalancer` functions that can be called to move capital in and out of ERC4626 positions.

#### Asynchronous Asset Management (ERC-7540)
A node implements functions that relate to each of the stages of depositing and withdrawing from a fully asynchronous 7540 vault:
- `investInAsyncVault()`
- `mintClaimableShares()`
- `requestAsyncWithdrawal()`
- `executeAsyncWithdrawal()`

These asset management functions all use the `onlyRebalancer` modifier.

The read function `getAsyncAssets()` calculates the asset value of a position in an async vault regardless of what state it is in or if it is in multiple states: e.g. some withdrawals pending, some deposits claimable etc. This is used by `totalAssets()` to calculate the NAV underlying positions in the node.

### Component Management
The contract allows for adding and managing multiple components (synchronous or asynchronous). Components are added in a specific order, which determines their withdrawal priority: synchronous components are handled first, followed by asynchronous ones.

### Current Status

This is a work-in-progress prototype. Many of the core mechanisms are in place, but further testing and refinement are needed, especially around the integration of ERC7540 assets. As such, it is:

- Not safe
- Not gas optimized

### Next Steps

- [ ] Finalize and optimize the ERC7540 integration
    - [x] Confirm the ERC7540 asset management logic is accurate to the Centrifuge integration
    - [x] Confirm the ERC7540 interface is accurate and suitable for integrators (i.e. Superform)
    - [ ] Enforce Withdrawal Queue on rebalancer liquidations logic
    - [x] Fix Logical Bug for Deposits (see TODO in Node.sol)
    - [ ] Implement Rebalance Cooldown
    - [ ] Optimize Code and use caching where neccessary
    - [x] Implement Slither static analysis
    - [ ] Fuzz & Invariant Testing
- [ ] Modular Architecture (TBD: these are just suggestions)
    - [ ] Split Functionality over Modules and Libraries
    - [ ] Factory Contract for permissionless Node creation
    - [ ] Rebalancing & Liquidations Modules (these need to be upgradable)
    - [ ] Swing Pricing Module (needs to be upgradeable)
- [ ] Other Launch Features (TBD)
    - [ ] Whitelisting
    - [ ] Fees
    

#### Post Launch

- [ ] Improve the rebalancing and optimize for capital efficiency & risk management
- [ ] Decentralize rebalancing with auctions/intents
- [ ] Governance Module: Decentralize protocol upgrades
- [ ] Token and Staking Module: Earn yield with the token by staking as a backstop

### Contributions

We welcome contributions and feedback. 

### Disclaimer

This is an experimental protocol. Use at your own risk. Not audited or ready for production use.

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

Run the [fork tests]([url](https://github.com/nashpoint/nashpoint-smart-contracts/blob/main/test/forked/ForkedTests.t.sol)) on Centrifuge Liquidity Pool:
```
forge test --match-contract ForkedTests --fork-url $ETHEREUM_RPC_URL --fork-block-number 20591573 --evm-version cancun
```

Forked Tests require an Ethereum mainnet RPC URL:

```
# MAINNET RPC URLS
ETHEREUM_RPC_URL=
```

##### CONTRACT & STATE OF FORK TEST:
https://etherscan.io/address/0x1d01ef1997d44206d839b78ba6813f60f1b3a970
- Taken from block 20591573
- EVM version: cancun
