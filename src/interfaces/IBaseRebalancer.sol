// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./INode.sol";

/**
 * @title IBaseRebalancer
 * @author ODND Studios
 */
interface IBaseRebalancer {
    /// @notice Returns the address of the Rebalancer's node.
    function node() external view returns (INode);

    /// @notice Returns if an address is an operator.
    /// @param operator The address to check.
    function isOperator(address operator) external view returns (bool);

    /// @notice Adds an operator.
    /// @param operator The address of the operator.
    function addOperator(address operator) external;

    /// @notice Removes an operator.
    /// @param operator The address of the operator.
    function removeOperator(address operator) external;

    /* APPROVALS */

    /// @notice approves a tokens spending limit via the Node.execute function.
    /// @param token The address of the token.
    /// @param spender The address of the spender.
    /// @param amount The amount to approve.
    function approve(address token, address spender, uint256 amount) external;
}
