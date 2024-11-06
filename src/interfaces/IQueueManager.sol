// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./INode.sol";
import {IQuoter} from "./IQuoter.sol";

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

    /// @notice Initiates a deposit request
    /// @dev Assets are transferred from owner to escrow immediately upon request
    function requestDeposit(uint256 assets, address controller) external returns (bool);

    /// @notice Initiates a redeem request
    /// @dev Shares are transferred from owner to escrow immediately upon request
    function requestRedeem(uint256 shares, address controller) external returns (bool);

    /// @notice Converts the assets value to share decimals
    function convertToShares(uint256 _assets) external view returns (uint256 shares);

    /// @notice Converts the shares value to assets decimals
    function convertToAssets(uint256 _shares) external view returns (uint256 assets);

    /// @notice Returns the max amount of assets that can be deposited
    function maxDeposit(address user) external view returns (uint256);

    /// @notice Returns the max amount of shares that can be minted
    function maxMint(address user) external view returns (uint256 shares);

    /// @notice Returns the max amount of assets that can be withdrawn
    function maxWithdraw(address user) external view returns (uint256 assets);

    /// @notice Returns the max amount of shares that can be redeemed
    function maxRedeem(address user) external view returns (uint256 shares);

    /// @notice Returns the total pending deposit request in assets
    function pendingDepositRequest(address user) external view returns (uint256 assets);

    /// @notice Returns the total pending redeem request in shares
    function pendingRedeemRequest(address user) external view returns (uint256 shares);

    /// @notice Fulfills pending deposit requests
    /// @dev The shares are minted and moved to the escrow contract
    function fulfillDepositRequest(address user, uint128 assets, uint128 shares) external;

    /// @notice Fulfills pending redeem requests
    /// @dev The shares are burned and assets are locked in escrow
    function fulfillRedeemRequest(address user, uint128 assets, uint128 shares) external;

    /// @notice Processes a deposit of assets for shares
    /// @dev Assets must already be in escrow
    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares);

    /// @notice Processes a mint of shares for assets
    /// @dev Assets must already be in escrow
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    /// @notice Processes a redemption of shares for assets
    /// @dev Shares must already be burned and assets must be in escrow
    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    /// @notice Processes a withdrawal of assets for shares
    /// @dev Shares must already be burned and assets must be in escrow
    function withdraw(uint256 assets, address receiver, address controller) external returns (uint256 shares);
}
