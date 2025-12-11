// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzDigiftAdapter.sol";

/**
 * @title FoundryDigiftAdapter
 * @notice Foundry tests for FuzzDigiftAdapter handlers - testing ERC20 lifecycle scenarios
 * @dev Tests verify that handlers can properly call functions without errors
 *      Each test represents a happy path user story with 3+ handler calls
 */
contract FoundryDigiftAdapter is FuzzDigiftAdapter {
    /**
     * @notice Setup function to initialize the fuzzing environment
     */
    function setUp() public {
        fuzzSetup();
        clearNodeContextOverrideForTest();
    }

    /**
     * @notice Test sequential approvals
     * @dev Node approves spenders sequentially
     */
    function test_handler_sequential_approvals() public {
        fuzz_digift_approve(1, 5e17);
        fuzz_digift_approve(2, 6e17);
        fuzz_digift_approve(3, 7e17);
        fuzz_digift_approve(1, 8e17);
    }

    /**
     * @notice Test multiple approvals
     * @dev Node approves multiple spenders with different amounts
     */
    function test_handler_multiple_approvals() public {
        fuzz_digift_approve(1, 4e17);
        fuzz_digift_approve(2, 5e17);
        fuzz_digift_approve(3, 6e17);
        fuzz_digift_approve(1, 7e17);
    }

    /**
     * @notice Test approval with same spender
     * @dev Multiple approvals to the same spender
     */
    function test_handler_same_spender_approvals() public {
        fuzz_digift_approve(1, 3e17);
        fuzz_digift_approve(1, 4e17);
        fuzz_digift_approve(1, 5e17);
        fuzz_digift_approve(1, 6e17);
    }

    /**
     * @notice Test approval pattern A
     * @dev Approval pattern with different spenders
     */
    function test_handler_approval_pattern_a() public {
        fuzz_digift_approve(2, 8e17);
        fuzz_digift_approve(3, 9e17);
        fuzz_digift_approve(1, 1e18);
        fuzz_digift_approve(2, 2e18);
    }

    /**
     * @notice Test approval pattern B
     * @dev Another approval pattern
     */
    function test_handler_approval_pattern_b() public {
        fuzz_digift_approve(3, 5e17);
        fuzz_digift_approve(1, 6e17);
        fuzz_digift_approve(2, 7e17);
        fuzz_digift_approve(3, 8e17);
    }

    /**
     * @notice Test approval with incremental amounts
     * @dev Approvals with incrementing amounts
     */
    function test_handler_incremental_approvals() public {
        fuzz_digift_approve(1, 1e17);
        fuzz_digift_approve(2, 2e17);
        fuzz_digift_approve(3, 3e17);
        fuzz_digift_approve(1, 4e17);
    }

    /**
     * @notice Test approve with varying amounts
     * @dev Test different approval amounts
     */
    function test_handler_varying_approvals() public {
        fuzz_digift_approve(1, 1e17);
        fuzz_digift_approve(2, 2e17);
        fuzz_digift_approve(3, 3e17);
        fuzz_digift_approve(1, 4e17);
    }

    /**
     * @notice Test approval pattern C
     * @dev Another approval pattern with higher amounts
     */
    function test_handler_approval_pattern_c() public {
        fuzz_digift_approve(1, 9e17);
        fuzz_digift_approve(2, 1e18);
        fuzz_digift_approve(3, 1.1e18);
        fuzz_digift_approve(1, 1.2e18);
    }

    /**
     * @notice Test approval reversal pattern
     * @dev Approve different amounts to same spenders
     */
    function test_handler_approval_reversal() public {
        fuzz_digift_approve(1, 8e17);
        fuzz_digift_approve(2, 9e17);
        fuzz_digift_approve(1, 1e18);
        fuzz_digift_approve(2, 1.1e18);
    }

    /**
     * @notice Test approval with all spenders
     * @dev Approve all three spenders multiple times
     */
    function test_handler_all_spenders() public {
        fuzz_digift_approve(1, 7e17);
        fuzz_digift_approve(2, 8e17);
        fuzz_digift_approve(3, 9e17);
        fuzz_digift_approve(1, 1e18);
    }
}
