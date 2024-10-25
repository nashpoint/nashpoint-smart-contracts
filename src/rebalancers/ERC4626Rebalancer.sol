// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRebalancer} from "../libraries/BaseRebalancer.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title ERC4626Rebalancer
 * @dev Rebalancer for ERC4626 vaults
 */
contract ERC4626Rebalancer is BaseRebalancer {

    /* CONSTRUCTOR */

    constructor(address node_, address owner) BaseRebalancer(node_, owner) {}

    /* EXTERNAL FUNCTIONS */

    /// @notice Deposits assets into an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to deposit.
    function deposit(address vault, address assets) external onlyOperator {
        node.execute(vault, 0, abi.encodeWithSelector(IERC4626.deposit.selector, assets, address(node)));
    }

    /// @notice Mints shares from an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to mint.
    function mint(address vault, address shares) external onlyOperator {
        node.execute(vault, 0, abi.encodeWithSelector(IERC4626.mint.selector, shares, address(node)));
    }

    /// @notice Withdraws assets from an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to withdraw.
    function withdraw(address vault, address assets) external onlyOperator {
        node.execute(vault, 0, abi.encodeWithSelector(IERC4626.withdraw.selector, assets, address(node), address(node)));
    }

    /// @notice Burns shares to assets in an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to burn.
    function redeem(address vault, address shares) external onlyOperator {
        node.execute(vault, 0, abi.encodeWithSelector(IERC4626.redeem.selector, shares, address(node), address(node)));
    }
}

