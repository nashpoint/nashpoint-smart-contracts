# Guardian Nashpoint UniversalFuzzing Suite

**Production-grade, stateful fuzzing framework for Nashpoint protocol security testing**

This fuzzing suite was developed by Guardian for comprehensive security testing of Nashpoint's core protocol contracts. It implements the UniversalFuzzing framework - a handler-based architecture with advanced revert management, explicit precondition/postcondition separation, and industrial-strength error categorization.

## Overview

### Tested Contracts

This suite provides comprehensive fuzzing coverage for Nashpoint's core protocol:

| Contract | Handlers | Focus Areas |
|----------|----------|-------------|
| **Node** | 15+ | Deposits, withdrawals, rebalancing, router management, claims |
| **NodeFactory** | 5+ | Node creation, configuration, upgrades |
| **DigiftAdapter** | 8+ | Cross-chain operations, event verification, liquidity management |
| **RewardRouters** | 4+ | Reward distribution, router configuration |
| **NodeRegistry** | 5+ | Node registration, whitelisting, operator management |
| **OneInch** | 3+ | DEX integration, swap operations |

**Total:** 40+ handlers testing complex multi-contract interactions

### Key Features

✅ **Stateful Fuzzing** - Tracks before/after state across all operations

✅ **Multi-Actor Testing** - Multiple concurrent users with randomized operations

✅ **Comprehensive Coverage** - Protocol invariants validated

✅ **Guided Scenarios** - Complex multi-step workflows

✅ **Donation Testing** - Unexpected token transfer handling

✅ **Error Categorization** - Sophisticated revert analysis

✅ **Production Ready** - Optimized configuration

---

## Quick Start

### Prerequisites

```bash
# Required
- Foundry (latest)
- Echidna 2.2.7+
- Python 3.8+ (for analysis tools)
```

### Installation

**✅ The Setup One-Liner**

```bash
git clone -b fuzz-suite https://github.com/GuardianOrg/nashpoint-smart-contracts-fuzz-1761255023649.git && \
cd nashpoint-smart-contracts-fuzz-1761255023649 && \
git submodule update --init --recursive && \
forge install perimetersec/fuzzlib --no-git && \
./patch-optimism.sh && \
forge build
```

**📋 Step-by-Step Instructions**

1. **Clone repository**

```bash
git clone -b fuzz-suite https://github.com/GuardianOrg/nashpoint-smart-contracts-fuzz-1761255023649.git
cd nashpoint-smart-contracts-fuzz-1761255023649
```

2. **Verify branch**

```bash
git branch --show-current
# Output: fuzz-suite
```

3. **Initialize submodules**

```bash
git submodule update --init --recursive
```

4. **Install fuzzlib**

```bash
forge install perimetersec/fuzzlib --no-git
```

5. **Patch Optimism library** *(required for Echidna compatibility)*

```bash
./patch-optimism.sh
```

6. **Build contracts**

```bash
forge build
```

### Running Fuzzer

```bash
# Standard fuzzing campaign
echidna test/fuzzing/Fuzz.sol --contract Fuzz --config echidna.yaml
```

### Foundry Reproductions

```bash
# Run the reproducer
forge test --mt test_coverage_ -vvvv
```

## Guardian Fuzz Central

### Custom command

```bash
pip install crytic-compile && git submodule update --init --recursive && forge install perimetersec/fuzzlib --no-git && ./patch-optimism.sh
```

### Path

```bash
test/fuzzing/Fuzz.sol --contract Fuzz
```

---

## Architecture

### Directory Structure

```
test/fuzzing/
├── Fuzz.sol                          # Main entry point (Echidna target)
├── FuzzSetup.sol                     # Nashpoint deployment & initialization
├── FuzzGuided.sol                    # Complex multi-step scenarios
│
├── Handler Contracts (Operation-specific)
│   ├── FuzzNode.sol                  # Node operations (deposits/withdrawals)
│   ├── FuzzNodeFactory.sol           # Node creation & configuration
│   ├── FuzzDigiftAdapter.sol         # Cross-chain operations
│   ├── FuzzDigiftEventVerifier.sol   # Event verification
│   ├── FuzzRewardRouters.sol         # Reward distribution
│   ├── FuzzDonate.sol                # Unexpected token transfers
│   │
│   └── FuzzAdmin/                    # Admin operations
│       ├── FuzzNodeRegistry.sol      # Node registration
│       └── FuzzOneInch.sol           # DEX integration
│
├── helpers/
│   ├── FuzzStorageVariables.sol      # Global state & config
│   ├── FuzzStructs.sol               # Parameter structs
│   ├── BeforeAfter.sol               # State snapshot system
│   ├── HelperFunctions.sol           # Utility functions
│   │
│   ├── Preconditions/                # Input validation & clamping
│   │   ├── PreconditionsBase.sol
│   │   ├── PreconditionsNode.sol
│   │   ├── PreconditionsNodeFactory.sol
│   │   ├── PreconditionsDigiftAdapter.sol
│   │   ├── PreconditionsDigiftEventVerifier.sol
│   │   ├── PreconditionsRewardRouters.sol
│   │   ├── PreconditionsNodeRegistry.sol
│   │   ├── PreconditionsOneInch.sol
│   │   └── PreconditionsDonate.sol
│   │
│   └── Postconditions/               # State validation & invariants
│       ├── PostconditionsBase.sol
│       ├── PostconditionsNode.sol
│       ├── PostconditionsNodeFactory.sol
│       ├── PostconditionsDigiftAdapter.sol
│       ├── PostconditionsDigiftEventVerifier.sol
│       ├── PostconditionsRewardRouters.sol
│       ├── PostconditionsNodeRegistry.sol
│       ├── PostconditionsOneInch.sol
│       └── PostconditionsDonate.sol
│
├── properties/
│   ├── Properties.sol                # All protocol invariants
│   ├── PropertiesBase.sol            # Base property helpers
│   ├── PropertiesDescriptions.sol    # Human-readable descriptions
│   ├── Properties_ERR.sol            # Error allowlist configuration
│   └── RevertHandler.sol             # Revert categorization engine
│
├── mocks/
│   └── MockERC20.sol                 # Test tokens
│
├── utils/
│   ├── FuzzActors.sol                # User management
│   └── FuzzConstants.sol             # Protocol constants
│
├── foundry/                          # Foundry-specific tests
│
└── FoundryPlayground.sol             # Failure reproductions
```

### Core Components

#### 1. Entry Point (`Fuzz.sol`)

Single entry point for Echidna campaigns:

```solidity
contract Fuzz is FuzzGuided {
    constructor() payable {
        fuzzSetup(true);  # Deploy Nashpoint
    }
}
```

#### 2. Setup Layer (`FuzzSetup.sol`)

Deploys complete Nashpoint protocol:

```solidity
function fuzzSetup(bool deployProtocol) internal {
    _initUsers();                          // Create test users
    if (deployProtocol) {
        deployNashpointLocal();            // Deploy all contracts
    }
    setupFuzzingArrays();                  // DONATEES, TOKENS arrays
    mintTokensToUsers();                   // Fund users with assets
    setupInitialDeposits();                // Initial node deposits
    configureRewardRouters();              // Set up reward distribution
    labelAll();                            // VM labels for debugging
}
```

**Deployed Assets:**
- **Nodes:** Multiple test nodes with varying configurations
- **Tokens:** Test ERC20 tokens for deposits and rewards
- **Users:** Funded actors with initial deposits
- **Adapters:** Cross-chain integration components

#### 3. Handler Pattern

All operations follow the same structure:

```solidity
// In FuzzNode.sol
function fuzz_deposit(
    uint256 assetsSeed,
    uint256 receiverSeed
) public setCurrentActor {
    // 1. PRECONDITIONS - Validate & clamp inputs
    NodeDepositParams memory params = depositPreconditions(
        assetsSeed, receiverSeed
    );

    // 2. SETUP ACTORS - Track affected addresses
    address[] memory actorsToUpdate = new address[](2);
    actorsToUpdate[0] = currentActor;
    actorsToUpdate[1] = params.receiver;

    // 3. BEFORE SNAPSHOT - Save state
    _before(actorsToUpdate);

    // 4. EXECUTE - Call via FuzzLib proxy
    (bool success, bytes memory returnData) = fl.doFunctionCall(
        address(node),
        abi.encodeWithSelector(
            node.deposit.selector,
            params.assets,
            params.receiver
        ),
        currentActor
    );

    // 5. POSTCONDITIONS - Validate results
    depositPostconditions(success, returnData, actorsToUpdate, params);
}
```

#### 4. State Tracking (`BeforeAfter.sol`)

Captures comprehensive state snapshots:

```solidity
struct StateSnapshot {
    // Per-actor state
    mapping(address => ActorState) actorStates;

    // Node state
    mapping(address => uint256) nodeTotalAssets;
    mapping(address => uint256) nodeTotalSupply;
    mapping(address => uint256) nodeSharesExiting;

    // Token balances
    mapping(address => mapping(address => uint256)) tokenBalances;

    // Reward state
    mapping(address => uint256) pendingRewards;
}

struct ActorState {
    // Node shares
    mapping(address => uint256) nodeShares;

    // Withdrawal state
    uint256 pendingWithdrawals;

    // Nonces
    uint256 depositNonce;
}

StateSnapshot[2] internal states;  // [0]=before, [1]=after
```

#### 5. Error Management (`RevertHandler.sol`)

Sophisticated error categorization:

```solidity
function invariant_ERR(bytes memory returnData) internal {
    if (returnData.length == 0) {
        if (CATCH_EMPTY_REVERTS) {
            fl.t(false, ERR_01);  // "Unexpected Error"
        }
        return;
    }

    bytes4 errorSelector;
    assembly {
        errorSelector := mload(add(returnData, 0x20))
    }

    // Route to appropriate handler
    if (errorSelector == bytes4(keccak256("Panic(uint256)"))) {
        _handlePanic(returnData);
    } else if (errorSelector == bytes4(keccak256("Error(string)"))) {
        _handleError(returnData);
    } else if (returnData.length == 4) {
        _handleSoladyError(returnData);
    } else {
        _handleCustomError(returnData);
    }
}
```

---

## Coverage

### Contracts Under Test

| Contract | Functions Fuzzed | Handlers | Key Operations |
|----------|-----------------|----------|----------------|
| **Node** | 15+ | 15+ | `deposit`, `mint`, `withdraw`, `redeem`, `claimYield`, `rebalance`, `addRouter`, `removeRouter` |
| **NodeFactory** | 5+ | 5+ | `createNode`, `upgradeNode`, `setImplementation`, `configureNode` |
| **DigiftAdapter** | 8+ | 8+ | `initiateCrossChain`, `verifyEvent`, `executeLiquidity`, `claimCrossChain` |
| **RewardRouters** | 4+ | 4+ | `distributeRewards`, `configureRouter`, `claimRewards` |
| **NodeRegistry** | 5+ | 5+ | `registerNode`, `whitelistOperator`, `deregisterNode` |
| **OneInch** | 3+ | 3+ | `swap`, `configureAggregator` |

### Foundry Testing

#### FoundryPlayground.sol

Repository for reproducing Echidna findings:

```solidity
contract FoundryPlayground is FuzzGuided {
    function setUp() public {
        fuzzSetup(true);
    }

    // Reproduce specific scenarios
    function test_coverage_deposit() public {
        setActor(USERS[0]);
        fuzz_deposit(1000e18, 0);
    }

    function test_coverage_withdraw() public {
        setActor(USERS[0]);
        fuzz_deposit(5000e18, 0);

        vm.warp(block.timestamp + 1 days);

        fuzz_withdraw(1000e18, 0, 0);
    }
}
```

**⚠️ IMPORTANT:** Always use `setActor(USERS[0])` before calling handlers

---

### File Locations

| Component | Location |
|-----------|----------|
| Entry point | `test/fuzzing/Fuzz.sol` |
| Setup | `test/fuzzing/FuzzSetup.sol` |
| Handlers | `test/fuzzing/Fuzz*.sol` |
| Preconditions | `helpers/preconditions/*.sol` |
| Postconditions | `helpers/postconditions/*.sol` |
| Properties | `properties/Properties.sol` |
| Error config | `properties/Properties_ERR.sol` |
| Reproductions | `FoundryPlayground.sol` |
| Config | `echidna.yaml`, `foundry.toml` |

---

## Protocol Invariants

The suite validates **100+ protocol invariants** across all components. Below is the complete catalog:

### Global Invariants

| ID | Description |
|----|-------------|
| **NODE_41** | Shares Exiting Must Not Exceed Total Supply *(checked after every operation)* |

### Node Invariants (NODE_01 - NODE_40)

#### Core Operations (NODE_01 - NODE_07)
| ID | Description |
|----|-------------|
| NODE_01 | User Share Balance Must Increase After Successful Deposit/Mint |
| NODE_02 | Escrow Share Balance Must Increase By The Redemption Request Amount |
| NODE_03 | Escrow Share Balance Must Decrease After A Redeem Is Finalized |
| NODE_04 | User Asset Balance Must Increase By Requested Asset Amount After Withdraw |
| NODE_05 | Escrow Asset Balance Must Be ≥ Sum Of All claimableAssets |
| NODE_06 | Component's Asset Ratio Should Not Exceed Target After Invest |
| NODE_07 | Node's Reserve Should Not Decrease Below Target After Invest |

#### Deposit (NODE_08 - NODE_11)
| ID | Description |
|----|-------------|
| NODE_08 | Receiver Share Balance Must Increase By Minted Shares After Deposit |
| NODE_09 | Node Asset Balance Must Increase By Deposited Assets |
| NODE_10 | Node Total Assets Must Increase By Deposited Assets |
| NODE_11 | Node Total Supply Must Increase By Minted Shares |

#### Mint (NODE_12 - NODE_15)
| ID | Description |
|----|-------------|
| NODE_12 | Receiver Share Balance Must Increase By Minted Shares |
| NODE_13 | Receiver Asset Balance Must Decrease By Assets Spent |
| NODE_14 | Node Total Assets Must Increase By Assets Spent |
| NODE_15 | Node Total Supply Must Increase By Requested Shares |

#### Request Redeem (NODE_16 - NODE_19)
| ID | Description |
|----|-------------|
| NODE_16 | Owner Share Balance Must Decrease By Requested Shares |
| NODE_17 | Pending Redeem Must Increase By Requested Shares |
| NODE_18 | Claimable Redeem Must Remain Unchanged After Request |
| NODE_19 | Claimable Assets Must Remain Unchanged After Request |

#### Fulfill Redeem (NODE_20 - NODE_21)
| ID | Description |
|----|-------------|
| NODE_20 | Pending Redeem Must Decrease After Fulfill |
| NODE_21 | Claimable Redeem Must Increase After Fulfill |

#### Withdraw (NODE_22 - NODE_23)
| ID | Description |
|----|-------------|
| NODE_22 | Claimable Assets Must Decrease By Withdrawn Amount |
| NODE_23 | Escrow Asset Balance Must Decrease By Withdrawn Amount |

#### Finalize Redemption (NODE_24 - NODE_28)
| ID | Description |
|----|-------------|
| NODE_24 | Pending Redeem Must Decrease By Finalized Shares |
| NODE_25 | Claimable Redeem Must Increase By Finalized Shares |
| NODE_26 | Claimable Assets Must Increase By Returned Assets |
| NODE_27 | Escrow Asset Balance Must Increase By Returned Assets |
| NODE_28 | Node Asset Balance Must Decrease By Returned Assets |

#### Redeem (NODE_29 - NODE_32)
| ID | Description |
|----|-------------|
| NODE_29 | Claimable Redeem Must Decrease By Redeemed Shares |
| NODE_30 | Claimable Assets Must Decrease By Returned Assets |
| NODE_31 | Receiver Asset Balance Must Increase By Returned Assets |
| NODE_32 | Escrow Asset Balance Must Decrease By Returned Assets |

#### Component Management (NODE_33 - NODE_34)
| ID | Description |
|----|-------------|
| NODE_33 | Component Must Be Registered After Add |
| NODE_34 | Component Must Be Unregistered After Remove |

#### Rescue Tokens (NODE_35 - NODE_36)
| ID | Description |
|----|-------------|
| NODE_35 | Node Balance Must Decrease By Rescued Amount |
| NODE_36 | Recipient Balance Must Increase By Rescued Amount |

#### Policies (NODE_37 - NODE_38)
| ID | Description |
|----|-------------|
| NODE_37 | Policy Must Be Registered After Add |
| NODE_38 | Policy Must Be Unregistered After Remove |

#### Backing Yield (NODE_39 - NODE_40)
| ID | Description |
|----|-------------|
| NODE_39 | Component Balance Must Increase By Delta After Gain Backing |
| NODE_40 | Component Balance Must Decrease By Delta After Lose Backing |

### Router 4626 Invariants (ROUTER4626_01 - ROUTER4626_09)

| ID | Description |
|----|-------------|
| ROUTER4626_01 | Invest Must Return Non-Zero Deposit Amount |
| ROUTER4626_02 | Node Component Shares Must Not Decrease After Invest |
| ROUTER4626_03 | Node Asset Balance Must Not Increase After Invest |
| ROUTER4626_04 | Liquidate Must Return Non-Zero Assets When Expected |
| ROUTER4626_05 | Node Component Shares Must Not Increase After Liquidate |
| ROUTER4626_06 | Node Asset Balance Must Not Decrease After Liquidate |
| ROUTER4626_07 | Fulfill Must Return Non-Zero Assets |
| ROUTER4626_08 | Escrow Balance Must Not Decrease After Fulfill |
| ROUTER4626_09 | Node Asset Balance Must Not Increase After Fulfill |

### Router 7540 Invariants (ROUTER7540_01 - ROUTER7540_16)

| ID | Description |
|----|-------------|
| ROUTER7540_01 | Invest Must Request Non-Zero Assets |
| ROUTER7540_02 | Pending Deposit Must Not Decrease After Invest |
| ROUTER7540_03 | Node Asset Balance Must Not Increase After Invest |
| ROUTER7540_04 | Node Component Shares Must Increase By Received Shares After Mint |
| ROUTER7540_05 | Claimable Must Not Increase After Mint |
| ROUTER7540_06 | Pending Redeem Must Not Decrease After Request Withdrawal |
| ROUTER7540_07 | Component Share Balance Must Not Increase After Request Withdrawal |
| ROUTER7540_08 | Execute Withdrawal Must Return Non-Zero Assets |
| ROUTER7540_09 | Execute Withdrawal Assets Must Match Max Withdraw Before |
| ROUTER7540_10 | Claimable Must Not Increase After Execute Withdrawal |
| ROUTER7540_11 | Node Asset Balance Must Not Decrease After Execute Withdrawal |
| ROUTER7540_12 | Max Withdraw Must Be Zero After Execute Withdrawal |
| ROUTER7540_13 | Fulfill Redeem Must Return Non-Zero Assets When Expected |
| ROUTER7540_14 | Escrow Balance Must Not Decrease After Fulfill Redeem |
| ROUTER7540_15 | Node Asset Balance Must Not Increase After Fulfill Redeem |
| ROUTER7540_16 | Component Shares Must Not Increase After Fulfill Redeem |

### Router Settings Invariants (ROUTER_01 - ROUTER_03)

| ID | Description |
|----|-------------|
| ROUTER_01 | Blacklist Status Must Match Set Value |
| ROUTER_02 | Whitelist Status Must Match Set Value |
| ROUTER_03 | Tolerance Value Must Match Set Value |

### Pool Invariants (POOL_01 - POOL_02)

| ID | Description |
|----|-------------|
| POOL_01 | Pending Deposits Must Not Increase After Process |
| POOL_02 | Pending Redemptions Must Be Zero After Process |

### Digift Adapter Invariants (DIGIFT_01 - DIGIFT_12)

| ID | Description |
|----|-------------|
| DIGIFT_01 | Global Pending Deposit Must Match Forwarded Amount |
| DIGIFT_02 | Global Pending Redeem Must Match Forwarded Amount |
| DIGIFT_03 | No Pending Deposits Must Remain After Settle |
| DIGIFT_04 | No Pending Redemptions Must Remain After Settle |
| DIGIFT_05 | Max Mintable Shares Must Be Non-Zero After Settle Deposit |
| DIGIFT_06 | Max Withdrawable Assets Must Be Non-Zero After Settle Redeem |
| DIGIFT_07 | Total Max Withdrawable Must Match Expected Assets |
| DIGIFT_08 | Withdraw Assets Must Match Max Withdraw Before |
| DIGIFT_09 | Node Balance Must Not Decrease After Withdraw |
| DIGIFT_10 | Max Withdraw Must Be Zero After Withdraw |
| DIGIFT_11 | Pending Redeem Must Increase After Request |
| DIGIFT_12 | Balance Must Not Increase After Request Redeem |

### Factory Invariants (FACTORY_01 - FACTORY_07)

| ID | Description |
|----|-------------|
| FACTORY_01 | Deployed Node Address Must Not Be Zero |
| FACTORY_02 | Deployed Escrow Address Must Not Be Zero |
| FACTORY_03 | Node Escrow Link Must Match Deployed Escrow |
| FACTORY_04 | Node Asset Must Match Init Args Asset |
| FACTORY_05 | Node Owner Must Match Init Args Owner |
| FACTORY_06 | Node Total Supply Must Be Zero After Deploy |
| FACTORY_07 | Node Must Be Registered In Registry After Deploy |

### Registry Invariants (REGISTRY_01 - REGISTRY_06)

| ID | Description |
|----|-------------|
| REGISTRY_01 | Protocol Fee Address Must Match Set Value |
| REGISTRY_02 | Protocol Management Fee Must Match Set Value |
| REGISTRY_03 | Protocol Execution Fee Must Match Set Value |
| REGISTRY_04 | Policies Root Must Match Set Value |
| REGISTRY_05 | Registry Type Status Must Match Set Value |
| REGISTRY_06 | Owner Must Match After Transfer |

### OneInch Invariants (ONEINCH_01 - ONEINCH_05)

| ID | Description |
|----|-------------|
| ONEINCH_01 | Asset Token Balance Of Node Must Increase After Successful Swap |
| ONEINCH_02 | All Incentive Token Input Must Be Used During Swap |
| ONEINCH_03 | Node Must Receive At Least 99% Of Min Assets Out |
| ONEINCH_04 | Node Must Spend Exact Incentive Amount |
| ONEINCH_05 | Executor Must Receive At Least Incentive Amount |

### Reward Router Invariants

#### Fluid (REWARD_FLUID_01 - REWARD_FLUID_05)
| ID | Description |
|----|-------------|
| REWARD_FLUID_01 | Claim Recipient Must Be Node Address |
| REWARD_FLUID_02 | Claim Cumulative Amount Must Match Params |
| REWARD_FLUID_03 | Claim Position ID Must Match Params |
| REWARD_FLUID_04 | Claim Cycle Must Match Params |
| REWARD_FLUID_05 | Claim Proof Hash Must Match Params |

#### Incentra (REWARD_INCENTRA_01 - REWARD_INCENTRA_03)
| ID | Description |
|----|-------------|
| REWARD_INCENTRA_01 | Last Earner Must Be Node Address |
| REWARD_INCENTRA_02 | Campaign Addresses Hash Must Match |
| REWARD_INCENTRA_03 | Rewards Hash Must Match |

#### Merkl (REWARD_MERKL_01 - REWARD_MERKL_04)
| ID | Description |
|----|-------------|
| REWARD_MERKL_01 | Users Hash Must Match Params |
| REWARD_MERKL_02 | Tokens Hash Must Match Params |
| REWARD_MERKL_03 | Amounts Hash Must Match Params |
| REWARD_MERKL_04 | Proofs Hash Must Match Params |

---

## Development

### Adding New Handlers

1. Create handler in `test/fuzzing/FuzzContractName.sol`
2. Add preconditions in `helpers/preconditions/PreconditionsContractName.sol`
3. Add postconditions in `helpers/postconditions/PostconditionsContractName.sol`
4. Update `FuzzGuided.sol` to inherit new handler
5. Test with Foundry first in `FoundryPlayground.sol`

### Debugging

Use Foundry's verbose output for detailed traces:

```bash
forge test --mt test_coverage_ -vvvvv
```

---

## Contributing

This is a Guardian-maintained fuzzing suite. For issues or improvements, please contact the Guardian team.
