// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzNodeFactory.sol";

/**
 * @title FoundryNodeFactory
 * @notice Foundry tests for FuzzNodeFactory handlers - testing node deployment scenarios
 * @dev Tests verify that handlers can properly call functions without errors
 *      Each test represents a happy path user story with 3+ handler calls
 */
contract FoundryNodeFactory is FuzzNodeFactory {
    /**
     * @notice Setup function to initialize the fuzzing environment
     */
    function setUp() public {
        fuzzSetup();
        clearNodeContextOverrideForTest();
    }

    /**
     * @notice Test multiple node deployments
     * @dev Different actors deploy nodes with various configurations
     */
    function test_handler_deploy_multiple_nodes() public {
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(4);
    }

    /**
     * @notice Test sequential deployments by same user
     * @dev Single user deploys multiple nodes with different seeds
     */
    function test_handler_deploy_sequential_same_user() public {
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(4);
    }

    /**
     * @notice Test node deployments with varied seeds
     * @dev Multiple users deploy nodes with different parameter combinations
     */
    function test_handler_deploy_varied_seeds() public {
        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(4);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(1);
    }

    /**
     * @notice Test deployments with reverse order
     * @dev Tests deployment with reverse seed order
     */
    function test_handler_deploy_reverse_order() public {
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(4);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);
    }

    /**
     * @notice Test alternating user deployments
     * @dev Users take turns deploying nodes
     */
    function test_handler_deploy_alternating_users() public {
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(4);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(1);
    }

    /**
     * @notice Test rapid sequential deployments
     * @dev Multiple quick deployments with same user repeating seeds
     */
    function test_handler_deploy_rapid_sequence() public {
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(4);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);
    }

    /**
     * @notice Test mixed user deployment pattern
     * @dev Various users deploy with different seeds
     */
    function test_handler_deploy_mixed_pattern() public {
        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(4);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(3);
    }

    /**
     * @notice Test deployment with cyclic pattern
     * @dev Deploys nodes using cyclic seed pattern
     */
    function test_handler_deploy_cyclic_pattern() public {
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(4);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(1);
    }

    /**
     * @notice Test deployment with repeated pattern
     * @dev Deploys nodes using repeated seed values
     */
    function test_handler_deploy_repeated_pattern() public {
        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(2);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(3);
    }

    /**
     * @notice Test deployment with user rotation
     * @dev Deploys nodes with rotating users and seeds
     */
    function test_handler_deploy_user_rotation() public {
        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(3);

        setActor(USERS[3]);
        fuzz_nodeFactory_deploy(4);

        setActor(USERS[1]);
        fuzz_nodeFactory_deploy(1);

        setActor(USERS[2]);
        fuzz_nodeFactory_deploy(2);
    }
}
