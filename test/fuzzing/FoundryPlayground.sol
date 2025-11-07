// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzGuided.sol";
import "forge-std/console2.sol";

/**
 * @notice Tests removed due to handler deletion:
 * - All fuzz_fulfillRedeem tests (Category 3 - onlyRebalancer, deleted)
 * - All fuzz_digiftFactory_* tests (deleted)
 * - fuzz_digiftVerifier_setWhitelist tests (Category 2 - moved to admin)
 * - fuzz_digiftVerifier_setBlockHash tests (Category 2 - moved to admin)
 * - All fuzz_router4626_* tests (deleted)
 * - All fuzz_router7540_* tests (deleted)
 * - All other router function tests (deleted)
 * - All admin/owner-only handler tests (deleted)
 *
 * @notice Remaining tests only call user-facing handlers:
 * - fuzz_deposit, fuzz_mint, fuzz_requestRedeem, fuzz_withdraw
 * - fuzz_setOperator, fuzz_node_approve, fuzz_node_transfer, fuzz_node_transferFrom, fuzz_node_redeem
 * - fuzz_donate, fuzz_digiftVerifier_verifySettlement, fuzz_nodeFactory_deploy
 */
contract FoundryPlayground is FuzzGuided {
    function setUp() public {
        vm.warp(1524785992); //echidna starting time
        fuzzSetup();
    }

    function test_handler_deposit() public {
        setActor(USERS[0]);
        fuzz_deposit(1e18);
    }

    function test_handler_mint() public {
        setActor(USERS[1]);
        fuzz_mint(5e17);
    }

    function test_handler_requestRedeem() public {
        setActor(USERS[0]);
        fuzz_deposit(2e18);

        setActor(USERS[0]);
        fuzz_requestRedeem(1e18);
    }

    function test_digift_deposit_flow() public {
        setActor(USERS[0]);
        fuzz_deposit(5e18);

        setActor(rebalancer);
        address[] memory asyncComponents = componentsByRouterForTest(address(router7540));
        uint256 digiftIndex;
        for (uint256 i = 0; i < asyncComponents.length; i++) {
            if (asyncComponents[i] == address(digiftAdapter)) {
                digiftIndex = i;
                break;
            }
        }
        fuzz_admin_router7540_invest(digiftIndex);

        setActor(rebalancer);
        fuzz_admin_digift_forwardRequests(1);

        setActor(rebalancer);
        fuzz_admin_digift_settleDeposit(2);

        fuzz_digift_mint(3);
    }

    function test_digift_redemption_flow() public {
        setActor(USERS[0]);
        fuzz_deposit(6e18);

        setActor(rebalancer);
        address[] memory asyncComponents = componentsByRouterForTest(address(router7540));
        uint256 digiftIndex;
        for (uint256 i = 0; i < asyncComponents.length; i++) {
            if (asyncComponents[i] == address(digiftAdapter)) {
                digiftIndex = i;
                break;
            }
        }
        fuzz_admin_router7540_invest(digiftIndex);

        setActor(rebalancer);
        fuzz_admin_digift_forwardRequests(1);

        setActor(rebalancer);
        fuzz_admin_digift_settleDeposit(2);

        fuzz_digift_mint(3);

        setActor(rebalancer);
        fuzz_admin_router7540_requestAsyncWithdrawal(digiftIndex, 0);

        setActor(rebalancer);
        fuzz_admin_digift_forwardRequests(4);

        setActor(rebalancer);
        fuzz_admin_digift_settleRedeem(6); // Use seed not divisible by 5 to avoid forced failure

        setActor(rebalancer);
        fuzz_admin_router7540_executeAsyncWithdrawal(digiftIndex, 0);
    }

    function test_router4626_liquidate_flow() public {
        setActor(USERS[1]);
        fuzz_deposit(8e18);

        address[] memory syncComponents = componentsByRouterForTest(address(router4626));
        uint256 vaultIndex;
        for (uint256 i = 0; i < syncComponents.length; i++) {
            if (syncComponents[i] == address(vault)) {
                vaultIndex = i;
                break;
            }
        }

        setActor(rebalancer);
        fuzz_admin_router4626_invest(vaultIndex, 0);

        setActor(rebalancer);
        fuzz_admin_router4626_liquidate(vaultIndex, 0);
    }

    function test_handler_setOperator() public {
        setActor(USERS[0]);
        fuzz_setOperator(1, true);
    }

    function test_handler_node_approve() public {
        setActor(USERS[0]);
        fuzz_node_approve(3, 1e18);
    }

    function test_handler_node_transfer() public {
        setActor(USERS[0]);
        fuzz_node_transfer(2, 5e17);
    }

    function test_handler_node_transferFrom() public {
        setActor(USERS[1]);
        fuzz_node_transferFrom(4, 7e17);
    }

    function test_handler_node_redeem() public {
        setActor(USERS[2]);
        fuzz_node_redeem(9);
    }

    function test_handler_donate() public {
        setActor(USERS[2]);
        fuzz_donate(0, 1, 1e18);
    }

    function test_handler_fluid_claimRewards() public {
        setActor(rebalancer);
        fuzz_fluid_claimRewards(1, 1, 1e6);
    }

    function test_handler_incentra_claimRewards() public {
        setActor(rebalancer);
        fuzz_incentra_claimRewards(2, 5e6);
    }

    function test_handler_merkl_claimRewards() public {
        setActor(rebalancer);
        fuzz_merkl_claimRewards(3e18);
    }

    function test_full_user_redemption_cycle() public {
        setActor(USERS[0]);
        fuzz_deposit(20e18);

        address[] memory asyncComponents = componentsByRouterForTest(address(router7540));
        uint256 digiftIndex;
        for (uint256 i = 0; i < asyncComponents.length; i++) {
            if (asyncComponents[i] == address(digiftAdapter)) {
                digiftIndex = i;
                break;
            }
        }

        console2.log("step", "invest");
        setActor(rebalancer);
        fuzz_admin_router7540_invest(digiftIndex);

        console2.log("step", "user request redeem");
        setActor(USERS[0]);
        fuzz_requestRedeem(5e18);

        console2.log("step", "request async withdraw");
        setActor(rebalancer);
        fuzz_admin_router7540_requestAsyncWithdrawal(digiftIndex, 0);

        console2.log("step", "forward redeem");
        setActor(rebalancer);
        fuzz_admin_digift_forwardRequests(3);

        console2.log("step", "settle redeem");
        setActor(rebalancer);
        fuzz_admin_digift_settleRedeem(4);

        console2.log("step", "execute async withdraw");
        setActor(rebalancer);
        fuzz_admin_router7540_executeAsyncWithdrawal(digiftIndex, 0);

        console2.log("step", "fulfill redeem");
        setActor(rebalancer);
        fuzz_admin_router7540_fulfillRedeemRequest(0, digiftIndex);

        console2.log("step", "execute async withdraw");
        console2.log("step", "user withdraw");
        setActor(USERS[0]);
        fuzz_withdraw(0, 0);
    }

    function test_guided_node_withdraw() public {
        fuzz_guided_node_withdraw(0, 5e18, 2e18, 1e18);
    }

    function test_handler_digiftVerifier_verifySettlement_subscribe() public {
        fuzz_digiftVerifier_verifySettlement(9, true);
    }

    function test_handler_digiftVerifier_verifySettlement_redeem() public {
        fuzz_digiftVerifier_verifySettlement(11, false);
    }

    function test_handler_nodeFactory_deploy() public {
        setActor(USERS[0]);
        fuzz_nodeFactory_deploy(11);
    }

    /**
     * @notice Test node reserve fulfillment (happy path)
     * @dev The precondition ensures node has sufficient assets to fulfill redemption
     *      Note: Reserve drain error path (seed % 5 == 0) is tested by fuzzing campaign
     */
    function test_node_fulfillRedeem_from_reserve() public {
        setActor(rebalancer);
        fuzz_admin_node_fulfillRedeem(3); // seed=3, not divisible by 5, has sufficient reserve
    }

    /**
     * @notice Note: withdraw/redeem preconditions have been enhanced
     * @dev Updated preconditions in PreconditionsNode.sol:
     *      - withdrawPreconditions: Scans for controllers that already have claimable assets (populated
     *        by dedicated handlers) and branches on assetsSeed % 10
     *        - 90% of calls: withdraw within bounds (happy path)
     *        - 10% of calls: attempt claimableAssets + 1 to trigger ExceedsMaxWithdraw
     *      - nodeRedeemPreconditions: Similar branching for shares using the same claimable lookup
     *        - 90% of calls: redeem within bounds (happy path)
     *        - 10% of calls: attempt claimableShares + 1 to trigger ExceedsMaxRedeem
     *
     *      These enhancements ensure the fuzzing campaign exercises:
     *      - src/Node.sol:513 withdraw function body (previously blocked by assets==0 guard)
     *      - src/Node.sol:541 redeem function body (previously blocked by shares==0 guard)
     *      - Error paths: ExceedsMaxWithdraw and ExceedsMaxRedeem
     *
     *      Standalone tests omitted as they require complex multi-step state setup that
     *      is better handled by the full fuzzing campaign context.
     */

    /**
     * @notice Test OneInch router swap (rebalancer operation)
     * @dev Exercises:
     *      - src/routers/OneInchV6RouterV1.sol:111 swap function
     *      - src/routers/OneInchV6RouterV1.sol:151 _subtractExecutionFee
     *      Preconditions automatically:
     *      - Whitelists incentive token and executor
     *      - Mints incentive tokens to node
     *      - Encodes proper swap calldata for mock
     */
    function test_oneinch_swap() public {
        setActor(rebalancer);
        fuzz_admin_oneinch_swap(42);
    }
}
