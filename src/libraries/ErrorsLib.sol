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

    /// @notice Thrown when no name is provided.
    error InvalidName();

    /// @notice Thrown when no symbol is provided.
    error InvalidSymbol();

    /// @notice Thrown when zero amount is provided.
    error ZeroAmount();

    /// @notice Thrown when the sender is invalid.
    error InvalidSender();

    /// @notice Thrown when the owner is invalid.
    error InvalidOwner();

    /// @notice Thrown when the controller is invalid.
    error InvalidController();

    /// @notice Thrown when the balance is insufficient.
    error InsufficientBalance();

    /// @notice Thrown when the deposit request failed.
    error RequestDepositFailed();

    /// @notice Thrown when the redeem request failed.
    error RequestRedeemFailed();

    /// @notice Thrown when trying to set self as operator.
    error CannotSetSelfAsOperator();

    /// @notice Thrown when there is no pending deposit request.
    error NoPendingDepositRequest();

    /// @notice Thrown when there is no pending redeem request.
    error NoPendingRedeemRequest();

    /// @notice Thrown when the max deposit is exceeded.
    error ExceedsMaxDeposit();

    /// @notice Thrown when the max redeem is exceeded.
    error ExceedsMaxRedeem();

    /// @notice Thrown when the max withdraw is exceeded.
    error ExceedsMaxWithdraw();

    /// @notice Thrown when the component is invalid.
    error InvalidComponent();

    /// @notice Thrown when not the factory.
    error NotFactory();

    /// @notice Thrown when not initialized.
    error NotInitialized();

    /// @notice Thrown when already initialized.
    error AlreadyInitialized();

    /// @notice Thrown when not the node owner.
    error NotNodeOwner();

    /// @notice Thrown when not the node rebalancer.
    error NotNodeRebalancer();

    /// @notice Thrown when not a router.
    error NotRouter();

    /// @notice Thrown when not registered.
    error NotRegistered();

    /// @notice Thrown when not the registry owner.
    error NotRegistryOwner();
}
