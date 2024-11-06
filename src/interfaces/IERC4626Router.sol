// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IBaseRouter} from "./IBaseRouter.sol";

/**
 * @title ERC4626Rebalancer
 * @dev Rebalancer for ERC4626 vaults
 */
interface IERC4626Router is IBaseRouter {
    /// @notice Deposits assets into an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to deposit.
    function deposit(address node, address vault, uint256 assets) external;

    /// @notice Mints shares from an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to mint.
    function mint(address node, address vault, uint256 shares) external;

    /// @notice Withdraws assets from an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to withdraw.
    function withdraw(address node, address vault, uint256 assets) external;

    /// @notice Burns shares to assets in an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to burn.
    function redeem(address node, address vault, uint256 shares) external;
}
