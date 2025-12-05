// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";
import "./Properties_OneInch.sol";
import "./Properties_Node.sol";
import "./Properties_Digift.sol";
import "./Properties_Registry.sol";
import "./Properties_Factory.sol";
import "./Properties_Reward.sol";
import "../logicalCoverage/LogicalCoverageBase.sol";

contract Properties is
    Properties_ERR,
    Properties_OneInch,
    Properties_Node,
    Properties_Digift,
    Properties_Registry,
    Properties_Factory,
    Properties_Reward,
    LogicalCoverageBase
{
    function invariant_INV_01() internal returns (bool) {
        uint256 totalSupply = node.totalSupply();
        uint256 exitingShares = node.sharesExiting();

        fl.gte(
            totalSupply,
            exitingShares,
            "INV_01: sharesExiting cannot exceed total supply"
        );
        return true;
    }
}
