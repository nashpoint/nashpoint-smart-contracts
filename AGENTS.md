# UniversalFuzzing - Essential Guide

Handler-based fuzzing with precondition/postcondition separation for smart contract security testing.

## Core Architecture

```
test/fuzzing/
├── Fuzz.sol                  # Entry point (Echidna targets this)
├── FuzzSetup.sol             # Deploy contracts & initialize
├── FuzzYourProtocol.sol      # Handlers for each function
├── helpers/
│   ├── FuzzStorageVariables.sol  # Global state (actors, config)
│   ├── BeforeAfter.sol           # State snapshots (_before/_after)
│   ├── preconditions/            # Input validation & clamping
│   └── postconditions/           # State validation & invariants
└── properties/
    ├── Properties.sol            # GLOB invariants (always true)
    ├── Properties_ERR.sol        # Allowed errors configuration
    └── RevertHandler.sol         # Error categorization engine
```

## Handler Pattern (5 Stages)

```solidity
function fuzz_deposit(uint256 amountSeed) public setCurrentActor {
    // 1. PRECONDITIONS - Validate & clamp inputs
    DepositParams memory params = depositPreconditions(amountSeed);

    // 2. BEFORE - Snapshot state
    _before();

    // 3. EXECUTE - Call via FuzzLib proxy (REQUIRED)
    (bool success, bytes memory returnData) = fl.doFunctionCall(
        address(protocol),
        abi.encodeWithSelector(Protocol.deposit.selector, params.amount),
        currentActor
    );

    // 4. POSTCONDITIONS - Validate results
    depositPostconditions(success, returnData, params);

    // 5. AFTER - in `postoconditions( is (success) {_after()})`

}
```

## FuzzLib Assertions (NEVER use Foundry assertions)

```solidity
fl.t(condition, "msg")          // Assert true
fl.eq(a, b, "msg")              // Assert equal
fl.gte(a, b, "msg")             // Assert >=
fl.clamp(value, min, max)       // Clamp inputs
fl.log("msg", value)            // Debug logging
```

## Property Types

| Type     | Purpose                      | Location             | Example                      |
| -------- | ---------------------------- | -------------------- | ---------------------------- |
| **GLOB** | Always true after ANY call   | `Properties.sol`     | `totalSupply == sumBalances` |
| **INV**  | Function-specific invariants | `Postconditions`     | Balance changes correctly    |
| **ERR**  | Allowed errors               | `Properties_ERR.sol` | Custom error selectors       |

### Property Implementation

```solidity
// GLOB - In Properties.sol (system-wide, always true)
function invariant_GLOB_01() internal view returns (bool) {
    fl.eq(totalSupply(), sumAllBalances(), "Conservation law");
    return true;
}

// INV - In Postconditions (function-specific)
function depositPostconditions(bool success, bytes memory returnData, DepositParams memory params) internal {
    if (success) {
        _after();
        fl.eq(
            _after.balance,
            _before.balance + params.amount,
            "Balance not updated"
        );
        onSuccessInvariantsGeneral(returnData); // ALWAYS call this
    } else {
        onFailInvariantsGeneral(returnData);     // ALWAYS call this
    }
}

// ERR - In Properties_ERR.sol
function _getAllowedCustomErrors() internal pure override returns (bytes4[] memory) {
    bytes4[] memory allowed = new bytes4[](2);
    allowed[0] = Protocol.InsufficientBalance.selector;
    allowed[1] = Protocol.Paused.selector;
    return allowed;
}
```

## Preconditions Pattern

```solidity
// In helpers/preconditions/PreconditionsYourProtocol.sol
struct DepositParams {
    uint256 amount;
    bool shouldSucceed;
}

function depositPreconditions(uint256 amountSeed) internal returns (DepositParams memory params) {
    // Clamp inputs
    params.amount = fl.clamp(amountSeed, 1, type(uint128).max);

    // Set expectations
    params.shouldSucceed = userBalance >= params.amount;
}
```

## BeforeAfter State Tracking

```solidity
// In BeforeAfter.sol
struct StateSnapshot {
    mapping(address => uint256) balances;
    uint256 totalSupply;
    uint256 exchangeRate;
}

StateSnapshot internal _before;
StateSnapshot internal _after;

function _before(address[] memory actors) internal {
    _before.totalSupply = protocol.totalSupply();
    for (uint i = 0; i < actors.length; i++) {
        _before.balances[actors[i]] = protocol.balanceOf(actors[i]);
    }
}
```

## Critical Rules

### DO ✅

- **Use `fl.doFunctionCall()` for ALL external calls** (proxy pattern)
- **Use FuzzLib assertions** (`fl.t`, `fl.eq`, etc.) not Foundry's
- **One operation per handler** (atomic)
- **Always call `onSuccessInvariantsGeneral(returnData)` in postconditions**
- **Deploy in `FuzzSetup.fuzzSetup()`** not constructors
- **Keep handlers clean** - put logic in preconditions/postconditions

### DON'T ❌

- **Don't use direct contract calls** - must go through FuzzLib proxy
- **Don't use Foundry assertions** (`assertEq`, `assertTrue`) in handlers
- **Don't put state-changing operations** in Properties.sol (view only)
- **Don't do complex calculations in `_before()`** (can revert)
- **Don't mix multiple operations** in one handler
- **Don't skip `onSuccessInvariantsGeneral()` or `onFailInvariantsGeneral()` and never ever delete it**

## Running Tests

```bash
# Echidna (primary fuzzer)
echidna test/fuzzing/Fuzz.sol --contract Fuzz --config echidna.yaml

# Foundry (reproductions)
forge test --mp test/foundry/FoundryPlayground.sol -vvvv

# Create reproduction tests
function test_coverage_deposit() public {
    setActor(USERS[0]);  // ALWAYS set actor first
    fuzz_deposit(1000e18);
}
```

## Common Mistakes

❌ **State changes in Properties**

```solidity
function invariant_GLOB_01() internal returns (bool) {
    protocol.updatePrice(); // WRONG - state change
    return protocol.price() > 0;
}
```

✅ **Use snaphotted version from BeforeAfter.sol**

```solidity
function invariant_GLOB_01() internal view returns (bool) {
   fl.gt(states[1].price, 0, "GLOB_01: Protocol price after execution should be more than zero"); // CORRECT
}
```

❌ **Foundry assertions**

```solidity
assertEq(balance, expected); // WRONG
```

✅ **FuzzLib assertions**

```solidity
fl.eq(balance, expected, "INV-01: Balance mismatch"); // CORRECT
```

❌ **Direct calls**

```solidity
protocol.deposit(amount); // WRONG - bypasses proxy
```

✅ **FuzzLib proxy**

```solidity
fl.doFunctionCall(address(protocol), abi.encodeCall(...), actor); // CORRECT
```

## Quick Setup Checklist

1. **FuzzSetup.sol** - Deploy contracts, populate `DONATEES`/`TOKENS`
2. **Preconditions** - Create params struct, clamp inputs
3. **Handler** - 5-stage pattern (precond → before → execute → postcond → after (in postconds) )
4. **Postconditions** - Validate state, call `onSuccessInvariantsGeneral()`
5. **Properties_ERR** - Add allowed custom errors
6. **Properties.sol** - Add GLOB invariants if needed

## Key Files

- **FuzzStorageVariables.sol** - `currentActor`, `USERS`, `TOKENS`, `DONATEES`
- **Properties_ERR.sol** - Allowed panic codes & custom errors
- **BeforeAfter.sol** - State snapshots for before/after comparison, state capture only in BeforeAfter
- **PreconditionsBase.sol** - Common helper functions
