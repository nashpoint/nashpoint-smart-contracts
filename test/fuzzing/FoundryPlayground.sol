// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzGuided.sol";

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
        fuzz_admin_digift_settleRedeem(5);

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
}
