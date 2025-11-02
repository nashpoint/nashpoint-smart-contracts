# Foundry Handler Integration Tests

## Overview

This directory contains **integration tests** for the fuzzing handlers. These tests verify that handler functions can be called without errors in realistic user story scenarios.

## Purpose

**Goal**: Ensure fuzzing handlers work correctly by testing happy-path user flows

**Not a goal**: Achieve full coverage or test edge cases (that's for echidna/medusa fuzzing)

## Structure

Each `Foundry*.sol` file corresponds to a `Fuzz*.sol` handler contract:

| Foundry Test File | Handler Contract | Focus Area |
|-------------------|------------------|------------|
| `FoundryNode.t.sol` | `FuzzNode.sol` | User deposit/mint/redeem/withdraw flows |
| `FoundryERC4626Router.t.sol` | `FuzzERC4626Router.sol` | Rebalancer vault management |
| `FoundryERC7540Router.t.sol` | `FuzzERC7540Router.sol` | Async vault operations |
| `FoundryRewardsRouters.t.sol` | `FuzzFluidRewardsRouter.sol`<br/>`FuzzIncentraRouter.sol`<br/>`FuzzMerklRouter.sol` | Protocol reward claiming |
| `FoundryOneInchRouter.t.sol` | `FuzzOneInchRouter.sol` | Incentive token swaps |
| `FoundryDigift.t.sol` | `FuzzDigiftAdapter.sol`<br/>`FuzzDigiftAdapterFactory.sol`<br/>`FuzzDigiftEventVerifier.sol` | Digift ecosystem |
| `FoundryAdmin.t.sol` | `FuzzNodeAdmin.sol`<br/>`FuzzNodeRegistry.sol`<br/>`FuzzNodeFactory.sol` | Protocol administration |

## Test Pattern

Each test follows the user story pattern:

```solidity
function test_story_deposit_redeem_withdraw() public {
    // User deposits
    setActor(USERS[0]);
    fuzz_deposit(10e18);

    // User requests redeem
    setActor(USERS[0]);
    fuzz_requestRedeem(5e18);

    // Rebalancer fulfills
    setActor(rebalancer);
    fuzz_fulfillRedeem(0);

    // User withdraws
    setActor(USERS[0]);
    fuzz_withdraw(0, 4e18);
}
```

### Naming Convention

- Prefix: `test_story_`
- Name describes the user flow: `deposit_transfer_redeem`
- Each test is one cohesive scenario

## Test Categories

### 1. Basic Operations
Single-step handler calls to verify basic functionality.

**Example**: `test_story_deposit()`, `test_story_invest_single_component()`

### 2. Lifecycle Flows
Complete user journeys from start to finish.

**Example**: `test_story_deposit_request_fulfill_withdraw()`

### 3. Multi-User Scenarios
Multiple actors interacting simultaneously.

**Example**: `test_story_partial_redemption_multiple_users()`

### 4. Complex Scenarios
Combined operations across multiple modules.

**Example**: `test_story_full_protocol_lifecycle_with_rewards()`

## Running Tests

### Run all Foundry handler tests:
```bash
forge test --match-path "test/fuzzing/foundry/*.sol"
```

### Run specific test file:
```bash
forge test --match-path "test/fuzzing/foundry/FoundryNode.t.sol"
```

### Run specific test:
```bash
forge test --match-test "test_story_deposit_redeem_withdraw"
```

### Run with verbosity:
```bash
forge test --match-path "test/fuzzing/foundry/*.sol" -vv
```

## Test Statistics

| File | Test Count | Coverage Area |
|------|-----------|---------------|
| FoundryNode.t.sol | ~25 tests | User operations |
| FoundryERC4626Router.t.sol | ~15 tests | Vault management |
| FoundryERC7540Router.t.sol | ~15 tests | Async vaults |
| FoundryRewardsRouters.t.sol | ~12 tests | Rewards |
| FoundryOneInchRouter.t.sol | ~12 tests | Swaps |
| FoundryDigift.t.sol | ~15 tests | Digift |
| FoundryAdmin.t.sol | ~20 tests | Admin |
| **Total** | **~114 tests** | **Full protocol** |

## Development Workflow

### Adding New Tests

1. Identify a user story from unit tests (e.g., `test/unit/Node.t.sol`)
2. Extract the flow pattern
3. Convert to handler calls
4. Add to appropriate `Foundry*.t.sol` file

### Example Conversion

**From unit test**:
```solidity
// test/unit/Node.t.sol
function test_userDepositsAndRedeems() public {
    deal(address(asset), user, 100e18);
    vm.startPrank(user);
    asset.approve(address(node), 100e18);
    uint256 shares = node.deposit(100e18, user);
    node.requestRedeem(shares, user, user);
    vm.stopPrank();
}
```

**To Foundry test**:
```solidity
// test/fuzzing/foundry/FoundryNode.t.sol
function test_story_deposit_and_redeem() public {
    setActor(USERS[0]);
    fuzz_deposit(100e18);

    setActor(USERS[0]);
    fuzz_requestRedeem(100e18);
}
```

## Key Differences from Unit Tests

| Aspect | Unit Tests | Foundry Handler Tests |
|--------|-----------|---------------------|
| Setup | Per-test setup | Shared FuzzSetup |
| Calls | Direct contract calls | Handler functions |
| Assertions | Explicit assertions | Implicit (no revert = success) |
| Scope | Single function | User stories |
| Purpose | Verify correctness | Verify handler wiring |

## Integration with Fuzzing

These tests serve as:

1. **Smoke tests** for handlers before fuzzing campaigns
2. **Reference implementations** for valid call sequences
3. **Regression tests** when handlers are modified
4. **Documentation** of intended user flows

## Maintenance

When adding new handlers:

1. Add corresponding Foundry test file
2. Extract user stories from unit tests
3. Create 5-10 representative scenarios
4. Ensure compilation passes: `forge build`
5. Verify all tests pass: `forge test --match-path "test/fuzzing/foundry/YourNewFile.t.sol"`

## Troubleshooting

### Test fails with "Actor not set"
- Ensure `setActor()` is called before each handler function
- Check that actor is in `USERS` array

### Test fails with "Insufficient balance"
- Verify `fuzzSetup()` allocated enough initial balance
- Check `INITIAL_USER_BALANCE` in `FuzzStorageVariables.sol`

### Test fails with "NotOwner" or "NotRebalancer"
- Verify correct actor is set for privileged operations
- Owner operations: `setActor(owner)`
- Rebalancer operations: `setActor(rebalancer)`

## Best Practices

1. ✅ **One story per test** - Each test should represent a single, cohesive user journey
2. ✅ **Realistic sequences** - Follow patterns that actual users would execute
3. ✅ **Clear naming** - Test name should describe the story
4. ✅ **Comment sections** - Use section headers to organize related tests
5. ✅ **Avoid assertions** - Let the fuzzing engine handle invariants; these tests just verify "no revert"

## Example User Stories by Module

### Node (User-Facing)
- Deposit → Redeem → Withdraw
- Mint → Transfer → New owner redeems
- Set operator → Operator acts on behalf

### ERC4626Router (Rebalancer)
- Invest → Liquidate cycles
- Multi-component rebalancing
- Fulfill user redemptions

### ERC7540Router (Async)
- Invest → MintClaimable → RequestWithdrawal → Execute
- Concurrent deposit/withdrawal requests

### Rewards
- Periodic reward harvesting
- Claim → Swap → Reinvest
- Multi-protocol optimization

### OneInch
- Whitelist → Swap
- Sequential swaps
- Rewards → Swap → Reinvest

### Digift
- Request deposit → Forward → Settle → Mint
- Request redeem → Forward → Settle → Withdraw
- Transfer shares between users

### Admin
- Configure fees → User operations affected
- Add/remove components → Rebalance
- Policy management → User interactions

## Related Files

- `test/fuzzing/FuzzGuided.sol` - Base contract for all handlers
- `test/fuzzing/FuzzSetup.sol` - Protocol deployment and setup
- `test/fuzzing/helpers/` - Preconditions and postconditions
- `test/FoundryPlayground.sol` - Original playground (legacy)

## Contributing

When adding tests:
1. Follow the existing pattern
2. Use meaningful story names
3. Group related tests in sections
4. Add comments for complex flows
5. Keep tests focused and concise
