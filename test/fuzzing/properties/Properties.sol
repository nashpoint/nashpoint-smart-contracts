// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";
import "./Properties_OneInch.sol";
import "./Properties_Node.sol";
import "../logicalCoverage/LogicalCoverageBase.sol";

contract Properties is
    Properties_ERR,
    Properties_OneInch,
    Properties_Node,
    LogicalCoverageBase
{
    // function invariant_GLOB_01() internal returns (bool) {
    //     uint256 totalAssets = node.totalAssets();
    //     uint256 nodeAssetBalance = asset.balanceOf(address(node));

    //     fl.gte(totalAssets, nodeAssetBalance, "GLOB_01: totalAssets must cover node balance");
    //     return true;
    // }

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
