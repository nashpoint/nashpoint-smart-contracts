// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./logicalFuzzSetup.sol";
import "./logicalFuzz.sol";
import "./logicalFuzzGuided.sol";
import "./logicalNode.sol";
import "./logicalNodeReserves.sol";
import "./logicalNodeAdmin.sol";
import "./logicalNodeFactory.sol";
import "./logicalNodeRegistry.sol";
import "./logicalComponents.sol";
import "./logicalPolicies.sol";
import "./logicalRouters.sol";
import "./logicalRewardRouters.sol";
import "./logicalDigiftAdapter.sol";
import "./logicalDigiftAdmin.sol";
import "./logicalActors.sol";
import "./logicalTokens.sol";
import "./logicalEscrow.sol";
import "./logicalDonate.sol";

contract LogicalCoverageBase is
    LogicalFuzzSetup,
    LogicalFuzz,
    LogicalFuzzGuided,
    LogicalNode,
    LogicalNodeReserves,
    LogicalNodeAdmin,
    LogicalNodeFactory,
    LogicalNodeRegistry,
    LogicalComponents,
    LogicalPolicies,
    LogicalRouters,
    LogicalRewardRouters,
    LogicalDigiftAdapter,
    LogicalDigiftAdmin,
    LogicalActors,
    LogicalTokens,
    LogicalEscrow,
    LogicalDonate
{
    bool internal constant LOGICAL_COVERAGE_ENABLED = true;

    function checkLogicalCoverage(bool enable) internal {
        if (!(enable && LOGICAL_COVERAGE_ENABLED)) {
            return;
        }

        logicalFuzzSetup();
        logicalFuzz();
        logicalFuzzGuided();
        logicalNode();
        logicalNodeReserves();
        logicalNodeAdmin();
        logicalNodeFactory();
        logicalNodeRegistry();
        logicalComponents();
        logicalPolicies();
        logicalRouters();
        logicalRewardRouters();
        logicalDigiftAdapter();
        logicalDigiftAdmin();
        logicalActors();
        logicalTokens();
        logicalEscrow();
        logicalDonate();
    }
}
