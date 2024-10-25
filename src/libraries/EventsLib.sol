// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title EventsLib
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted when `escrow` is set to `newEscrow`.
    event SetEscrow(address indexed newEscrow);

    /// @notice Emitted when `newRebalancer` is added to the rebalancers.
    event AddRebalancer(address indexed newRebalancer);

    /// @notice Emitted when `oldRebalancer` is removed from the rebalancers.
    event RemoveRebalancer(address indexed oldRebalancer);

    /// @notice Emitted when `node` is created.
    event CreateNode(address indexed node, address asset, string name, string symbol, address[] rebalancers, address owner, bytes32 salt);

    /// @notice Emitted when a Rebalancer executes an external call.
    event Execute(address indexed target, uint256 value, bytes data, bytes result);

    /// @notice Emitted when `operator` is added.
    event AddOperator(address indexed operator);

    /// @notice Emitted when `operator` is removed.
    event RemoveOperator(address indexed operator);
}
