// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./INode.sol";

/// @dev Queue requests and deposit/redeem bookkeeping per user
struct QueueState {
    /// @dev Shares that can be claimed using `mint()`
    uint128 maxMint;
    /// @dev Assets that can be claimed using `withdraw()`
    uint128 maxWithdraw;
    /// @dev Weighted average price of deposits, used to convert maxMint to maxDeposit
    uint256 depositPrice;
    /// @dev Weighted average price of redemptions, used to convert maxWithdraw to maxRedeem
    uint256 redeemPrice;
    /// @dev Remaining deposit request in assets
    uint128 pendingDepositRequest;
    /// @dev Remaining redeem request in shares
    uint128 pendingRedeemRequest;
}

interface IQueueManager {

    /// @notice Node that the QueueManager manages
    function node() external view returns (INode);

    /// @notice Initiates a deposit request by locking assets in escrow
    /// @dev Assets are transferred from owner to escrow immediately upon request
    function requestDeposit(uint256 assets, address receiver) external returns (bool);

    /// @notice Initiates a redeem request by locking shares in escrow
    /// @dev Shares are transferred from owner to escrow immediately upon request
    function requestRedeem(uint256 shares, address receiver) external returns (bool);

    // --- View functions ---
    /// @notice Converts the assets value to share decimals.
    function convertToShares(uint256 _assets) external view returns (uint256 shares);

    /// @notice Converts the shares value to assets decimals.
    function convertToAssets(uint256 _shares) external view returns (uint256 assets);

    /// @notice Returns the max amount of assets based on the unclaimed amount of shares after at least one successful
    ///         deposit order fulfillment on Centrifuge.
    function maxDeposit(address user) external view returns (uint256);

    /// @notice Returns the max amount of shares a user can claim after at least one successful deposit order
    ///         fulfillment on Centrifuge.
    function maxMint(address user) external view returns (uint256 shares);

    /// @notice Returns the max amount of assets a user can claim after at least one successful redeem order fulfillment
    ///         on Centrifuge.
    function maxWithdraw(address user) external view returns (uint256 assets);

    /// @notice Returns the max amount of shares based on the unclaimed number of assets after at least one successful
    ///         redeem order fulfillment on Centrifuge.
    function maxRedeem(address user) external view returns (uint256 shares);

    /// @notice Indicates whether a user has pending deposit requests and returns the total deposit request asset
    /// request value.
    function pendingDepositRequest(address user) external view returns (uint256 assets);

    /// @notice Indicates whether a user has pending redeem requests and returns the total share request value.
    function pendingRedeemRequest(address user) external view returns (uint256 shares);

    /// @notice Fulfills pending deposit requests after successful epoch execution on Centrifuge.
    ///         The amount of shares that can be claimed by the user is minted and moved to the escrow contract.
    ///         The MaxMint bookkeeping value is updated.
    ///         The request fulfillment can be partial.
    /// @dev    The shares in the escrow are reserved for the user and are transferred to the user on deposit
    ///         and mint calls.
    function fulfillDepositRequest(
        address user,
        uint128 assets,
        uint128 shares
    ) external;

    /// @notice Fulfills pending redeem requests after successful epoch execution on Centrifuge.
    ///         The amount of redeemed shares is burned. The amount of assets that can be claimed by the user in
    ///         return is locked in the escrow contract. The MaxWithdraw bookkeeping value is updated.
    ///         The request fulfillment can be partial.
    /// @dev    The assets in the escrow are reserved for the user and are transferred to the user on redeem
    ///         and withdraw calls.
    function fulfillRedeemRequest(
        address user,
        uint128 assets,
        uint128 shares
    ) external;

    // --- Vault claim functions ---
    /// @notice Processes owner's asset deposit after the epoch has been executed on Centrifuge and the deposit order
    ///         has been successfully processed (partial fulfillment possible).
    ///         Shares are transferred from the escrow to the receiver. Amount of shares is computed based of the amount
    ///         of assets and the owner's share price.
    /// @dev    The assets required to fulfill the deposit are already locked in escrow upon calling requestDeposit.
    ///         The shares required to fulfill the deposit have already been minted and transferred to the escrow on
    ///         fulfillDepositRequest.
    ///         Receiver has to pass all the share token restrictions in order to receive the shares.
    function deposit(uint256 assets, address receiver, address owner)
        external
        returns (uint256 shares);

    /// @notice Processes owner's share mint after the epoch has been executed on Centrifuge and the deposit order has
    ///         been successfully processed (partial fulfillment possible).
    ///         Shares are transferred from the escrow to the receiver. Amount of assets is computed based of the amount
    ///         of shares and the owner's share price.
    /// @dev    The assets required to fulfill the mint are already locked in escrow upon calling requestDeposit.
    ///         The shares required to fulfill the mint have already been minted and transferred to the escrow on
    ///         fulfillDepositRequest.
    ///         Receiver has to pass all the share token restrictions in order to receive the shares.
    function mint(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /// @notice Processes owner's share redemption after the epoch has been executed on Centrifuge and the redeem order
    ///         has been successfully processed (partial fulfillment possible).
    ///         Assets are transferred from the escrow to the receiver. Amount of assets is computed based of the amount
    ///         of shares and the owner's share price.
    /// @dev    The shares required to fulfill the redemption were already locked in escrow on requestRedeem and burned
    ///         on fulfillRedeemRequest.
    ///         The assets required to fulfill the redemption have already been reserved in escrow on
    ///         fulfillRedeemtRequest.
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /// @notice Assets are transferred from the escrow to the receiver. Amount of shares is computed based of the amount
    ///         of shares and the owner's share price.
    /// @dev    The shares required to fulfill the withdrawal were already locked in escrow on requestRedeem and burned
    ///         on fulfillRedeemRequest.
    ///         The assets required to fulfill the withdrawal have already been reserved in escrow on
    ///         fulfillRedeemtRequest.
    function withdraw(uint256 assets, address receiver, address owner)
        external
        returns (uint256 shares);
}
