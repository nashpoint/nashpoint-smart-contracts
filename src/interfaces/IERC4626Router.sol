// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IBaseRouter} from "./IBaseRouter.sol";

/**
 * @title ERC4626Rebalancer
 * @dev Rebalancer for ERC4626 vaults
 */
interface IERC4626Router is IBaseRouter {
    /// @notice Invests in a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    function invest(address node, address component) external returns (uint256);

    /// @notice Liquidates a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param shares The amount of shares to liquidate.
    function liquidate(address node, address component, uint256 shares) external returns (uint256);
}
