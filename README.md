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
| Preconditions | `helpers/Preconditions/*.sol` |
| Postconditions | `helpers/Postconditions/*.sol` |
| Properties | `properties/Properties.sol` |
| Error config | `properties/Properties_ERR.sol` |
| Reproductions | `FoundryPlayground.sol` |
| Config | `echidna.yaml`, `foundry.toml` |

---

## Protocol Invariants

The suite validates critical protocol invariants:

- **GLOB_01**: Total assets must cover node balance
- **INV_01**: Exiting shares cannot exceed total supply
- Additional invariants are continuously validated during fuzzing campaigns

---

## Development

### Adding New Handlers

1. Create handler in `test/fuzzing/FuzzContractName.sol`
2. Add preconditions in `helpers/Preconditions/PreconditionsContractName.sol`
3. Add postconditions in `helpers/Postconditions/PostconditionsContractName.sol`
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
