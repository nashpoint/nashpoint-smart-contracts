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

    /// @notice Thrown when the max mint is exceeded.
    error ExceedsMaxMint();

    /// @notice Thrown when the max redeem is exceeded.
    error ExceedsMaxRedeem();

    /// @notice Thrown when the max withdraw is exceeded.
    error ExceedsMaxWithdraw();

    /// @notice Thrown when the max deposit limit is exceeded.
    error ExceedsMaxDepositLimit();

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

    /// @notice Thrown when there is a length mismatch.
    error LengthMismatch();

    /// @notice Thrown when trying to remove a component with a non-zero balance.
    error NonZeroBalance();

    /// @notice Thrown when the target is not whitelisted.
    error NotWhitelisted();

    /// @notice Thrown when the target node is invalid
    error InvalidNode();

    /// @notice Thrown when the input to getSwingFactoris invalid.
    error InvalidInput(int256 reserveImpact);

    /// @notice Thrown when the reserve ratio is below target
    error ReserveBelowTargetRatio();

    /// @notice Thrown when the component is within the target range.
    error ComponentWithinTargetRange(address node, address component);

    /// @notice Thrown when the deposit amount exceeds the max vault deposit.
    error ExceedsMaxComponentDeposit(address component, uint256 depositAmount, uint256 maxDepositAmount);

    /// @notice Thrown when the redeem amount exceeds the max vault redeem.
    error ExceedsMaxComponentRedeem(address component, uint256 redeemAmount, uint256 maxRedeemAmount);

    /// @notice Thrown when the shares requested are more than the available shares.
    error ExceedsAvailableShares(address node, address component, uint256 sharesRequested);

    /// @notice Thrown when the assets requested are more than the available assets
    error ExceedsAvailableAssets(address node, address component, uint256 assetsRequested);

    /// @notice Thrown when the share value is invalid.
    error InvalidShareValue(address component, uint256 shareValue);

    /// @notice Thrown when the assets returned are insufficient.
    error InsufficientAssetsReturned(address component, uint256 assetsReturned, uint256 expectedAssets);

    /// @notice Thrown when the shares returned are insufficient.
    error InsufficientSharesReturned(address component, uint256 sharesReturned, uint256 expectedShares);

    /// @notice Thrown when incorrect requestId is returned.
    error IncorrectRequestId(uint256 requestId);

    /// @notice Thrown when the component is already in the queue.
    error DuplicateComponent();

    /// @notice Thrown when the liquidation order is incorrect.
    error IncorrectLiquidationOrder(address component, uint256 assetsToReturn);

    /// @notice Thrown when the cooldown is active.
    error CooldownActive();

    /// @notice Thrown when the rebalance is not available.
    error RebalanceWindowClosed();

    /// @notice Thrown when the rebalance window is open.
    error RebalanceWindowOpen();

    /// @notice Thrown when the not enough assets to pay fees.
    error NotEnoughAssetsToPayFees(uint256 feeForPeriod, uint256 assetsBalance);

    /// @notice Thrown when the component ratios do not sum to 100%.
    error InvalidComponentRatios();

    /// @notice Thrown when the fee exceeds the amount.
    error FeeExceedsAmount(uint256 fee, uint256 amount);
}
