// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRouter} from "../libraries/BaseRouter.sol";
import {MathLib} from "../libraries/MathLib.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626Router} from "../interfaces/IERC4626Router.sol";
import {INode} from "../interfaces/INode.sol";

/**
 * @title ERC4626Router
 * @dev Router for ERC4626 vaults
 */
contract ERC4626Router is BaseRouter, IERC4626Router {
    uint256 immutable WAD = 1e18;
    /* CONSTRUCTOR */

    constructor(address registry_) BaseRouter(registry_) {}

    /* EXTERNAL FUNCTIONS */
    /// @notice Deposits assets into an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to deposit.
    function deposit(address node, address vault, uint256 assets)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(vault)
    {
        // todo: make this more efficient later
        address underlying = IERC4626(vault).asset();
        INode(node).execute(underlying, 0, abi.encodeWithSelector(IERC20.approve.selector, vault, assets));
        INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.deposit.selector, assets, node));
    }

    /// @notice Mints shares from an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to mint.
    function mint(address node, address vault, uint256 shares)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(vault)
    {
        INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.mint.selector, shares, node));
    }

    /// @notice Withdraws assets from an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to withdraw.
    function withdraw(address node, address vault, uint256 assets)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(vault)
    {
        INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.withdraw.selector, assets, node, node));
    }

    /// @notice Burns shares to assets in an ERC4626 vault on behalf of the Node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to burn.
    function redeem(address node, address vault, uint256 shares)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(vault)
    {
        INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.redeem.selector, shares, node, node));
    }

    function getInvestmentSize(address node, address component)
        internal
        view
        override
        returns (uint256 depositAssets)
    {
        uint256 targetHoldings =
            MathLib.mulDiv(INode(node).totalAssets(), INode(node).getComponentRatio(component), WAD);

        uint256 currentBalance = IERC20(component).balanceOf(address(node));

        uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
        return delta;
    }
}
