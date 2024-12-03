// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRouter} from "../libraries/BaseRouter.sol";
import {INode} from "../interfaces/INode.sol";
import {IERC4626Router} from "../interfaces/IERC4626Router.sol";

import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

/**
 * @title ERC4626Router
 * @dev Router for ERC4626 vaults
 */
contract ERC4626Router is BaseRouter, IERC4626Router {
    uint256 immutable WAD = 1e18;

    /* CONSTRUCTOR */
    constructor(address registry_) BaseRouter(registry_) {}

    function invest(address node, address component)
        external
        override(IERC4626Router, BaseRouter)
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256 depositAmount)
    {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }

        // Calculate target deposit amount
        depositAmount = getInvestmentSize(node, component);

        // Validate deposit amount exceeds minimum threshold
        uint256 totalAssets_ = INode(node).totalAssets();
        if (depositAmount < MathLib.mulDiv(totalAssets_, INode(node).getMaxDelta(component), WAD)) {
            revert ComponentWithinTargetRange(node, component);
        }

        // Calculate current available cash (accounting for pending withdrawals)
        uint256 currentCash = IERC20(INode(node).asset()).balanceOf(address(node))
            - INode(node).convertToAssets(INode(node).sharesExiting());

        // Limit deposit by reserve ratio requirements
        uint256 idealCashReserve = MathLib.mulDiv(totalAssets_, INode(node).targetReserveRatio(), WAD);
        uint256 availableReserve = currentCash - idealCashReserve;

        if (depositAmount > availableReserve) {
            depositAmount = availableReserve;

            // Check vault deposit limits
            uint256 maxDepositAmount = IERC4626(component).maxDeposit(address(this));
            if (depositAmount > maxDepositAmount) {
                revert ExceedsMaxVaultDeposit(component, depositAmount, maxDepositAmount);
            }
        }

        // Execute deposit
        _deposit(node, component, depositAmount);
        return depositAmount;
    }

    // rebalancer to use this function to liquidate underlying vault to meet redeem requests
    function liquidate(address node, address component, uint256 shares)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256 assetsReturned)
    {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }

        if (IERC4626(component).balanceOf(address(node)) < shares) {
            revert ExceedsMaxWithdrawal(component, shares);
        }

        if (shares == 0) {
            revert CannotRedeemZeroShares();
        }

        // Preview the expected assets from redemption
        uint256 expectedAssets = IERC4626(component).previewRedeem(shares);

        // Perform the redemption
        assetsReturned = _redeem(node, component, shares);

        // Ensure assets returned is within an acceptable range of expectedAssets
        if (assetsReturned < expectedAssets) {
            revert InsufficientAssetsReturned(component, assetsReturned, expectedAssets);
        }

        return assetsReturned;
    }

    /// @notice Deposits assets into an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to deposit.
    function _deposit(address node, address vault, uint256 assets) internal {
        address underlying = IERC4626(vault).asset();
        INode(node).execute(underlying, 0, abi.encodeWithSelector(IERC20.approve.selector, vault, assets));
        INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.deposit.selector, assets, node));
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
    function _redeem(address node, address vault, uint256 shares)
        internal
        onlyNodeRebalancer(node)
        onlyWhitelisted(vault)
        returns (uint256)
    {
        bytes memory result =
            INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.redeem.selector, shares, node, node));
        return abi.decode(result, (uint256));
    }

    function redeem(address node, address vault, uint256 shares)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(vault)
    {
        INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.redeem.selector, shares, node, node));
    }

    /// @notice Calculates the target investment size for a component.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAssets The target investment size.
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
