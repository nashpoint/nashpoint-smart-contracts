// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IBaseRebalancer} from "./IBaseRebalancer.sol";

/**
 * @title ERC4626Rebalancer
 * @dev Rebalancer for ERC4626 vaults
 */
interface IERC4626Rebalancer is IBaseRebalancer {
    /// @notice Deposits assets into an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to deposit.
    function deposit(address vault, address assets) external;

    /// @notice Mints shares from an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to mint.
    function mint(address vault, address shares) external;

    /// @notice Withdraws assets from an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to withdraw.
    function withdraw(address vault, address assets) external;

    /// @notice Burns shares to assets in an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to burn.
    function redeem(address vault, address shares) external;
}

