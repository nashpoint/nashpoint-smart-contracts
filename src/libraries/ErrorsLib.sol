// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ErrorsLib
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when the address passed is the zero address.
    error ZeroAddress();

    /// @notice Thrown when the parameter passed is already set.
    error AlreadySet();

    /// @notice Thrown when the parameter passed is not set.
    error NotSet();

    /// @notice Thrown when the caller is not a rebalancer.
    error NotRebalancer();

    /// @notice Thrown when the caller is not an operator.
    error NotOperator();

    /// @notice Thrown when the safe approve failed.
    error SafeApproveFailed();
}
