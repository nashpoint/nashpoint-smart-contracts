// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title IBaseRouter
 * @author ODND Studios
 */
interface IBaseRouter {
    /* APPROVALS */
    /// @notice approves a tokens spending limit via the Node.execute function.
    /// @param node The address of the node.
    /// @param token The address of the token.
    /// @param spender The address of the spender.
    /// @param amount The amount to approve.
    function approve(address node, address token, address spender, uint256 amount) external;
}
