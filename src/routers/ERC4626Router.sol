// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRouter} from "../libraries/BaseRouter.sol";
import {INode} from "../interfaces/INode.sol";
import {IERC4626Router} from "../interfaces/IERC4626Router.sol";

import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

/**
 * @title ERC4626Router
 * @dev Router for ERC4626 vaults
 */
contract ERC4626Router is BaseRouter, IERC4626Router {
    using SafeERC20 for IERC20;

    /* STATE */
    uint256 internal totalAssets;
    uint256 internal currentCash;
    uint256 internal idealCashReserve;

    /* CONSTRUCTOR */
    constructor(address registry_) BaseRouter(registry_) {}

    /// @notice Invests in a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAmount The amount of assets invested.
    function invest(address node, address component)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256 depositAmount)
    {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }

        // checks if excess reserve is available to invest
        _validateReserveAboveTargetRatio(node);

        (totalAssets, currentCash, idealCashReserve) = _getNodeCashStatus(node);

        // gets units of asset required to set component to target ratio
        depositAmount = _getInvestmentSize(node, component);

        // Validate deposit amount exceeds minimum threshold
        if (depositAmount < MathLib.mulDiv(totalAssets, INode(node).getMaxDelta(component), WAD)) {
            revert ErrorsLib.ComponentWithinTargetRange(node, component);
        }

        // limit deposit by reserve ratio requirements
        uint256 availableReserve = currentCash - idealCashReserve;
        if (depositAmount > availableReserve) {
            depositAmount = availableReserve;
        }

        // subtract execution fee for protocol
        depositAmount = _subtractExecutionFee(depositAmount, node);

        // Check vault deposit limits
        if (depositAmount > IERC4626(component).maxDeposit(address(node))) {
            revert ErrorsLib.ExceedsMaxVaultDeposit(
                component, depositAmount, IERC4626(component).maxDeposit(address(node))
            );
        }

        // Execute deposit and check correct shares received
        uint256 expectedShares = IERC4626(component).previewDeposit(depositAmount);
        uint256 sharesReturned = _deposit(node, component, depositAmount);
        if (sharesReturned < expectedShares) {
            revert ErrorsLib.InsufficientSharesReturned(component, sharesReturned, expectedShares);
        }

        return sharesReturned;
    }

    /// @notice Liquidates a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param shares The amount of shares to liquidate.
    /// @return assetsReturned The amount of assets returned.
    function liquidate(address node, address component, uint256 shares)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256 assetsReturned)
    {
        assetsReturned = _liquidate(node, component, shares);
    }

    /// @notice Fulfills a redeem request on behalf of the Node.
    /// @dev Called by a rebalancer to liquidate a component in order to make assets available for user withdrawal
    /// Transfers the assets to Escrow and updates the Requst for the user
    /// Enforces liquidation queue to ensure asset liquidated is according to order set by the Node Owner
    /// @param node The address of the node.
    /// @param controller The address of the controller.
    /// @param component The address of the component.
    /// @return assetsReturned The amount of assets returned.
    function fulfillRedeemRequest(address node, address controller, address component)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256 assetsReturned)
    {
        (uint256 sharesPending,,, uint256 sharesAdjusted) = INode(node).getRequestState(controller);
        uint256 assetsRequested = INode(node).convertToAssets(sharesAdjusted);

        // Validate that the component is top of the liquidation queue
        address[] memory liquidationsQueue = INode(node).getLiquidationsQueue();
        _enforceLiquidationQueue(component, assetsRequested, liquidationsQueue);

        // liquidate either the requested amount or the balance of the component
        // if the requested amount is greater than the balance of the component
        uint256 componentShares = MathLib.min(
            IERC4626(component).convertToShares(assetsRequested), IERC20(component).balanceOf(address(node))
        );

        // execute the liquidation
        assetsReturned = _liquidate(node, component, componentShares);

        // if the assets returned are less than the assets requested, adjust the shares pending and shares adjusted
        // to reflect the percentage of the requested assets that were returned
        if (assetsReturned < assetsRequested) {
            uint256 percentReturned = MathLib.mulDiv(assetsReturned, WAD, assetsRequested);
            sharesPending = MathLib.mulDiv(sharesPending, percentReturned, WAD);
            sharesAdjusted = MathLib.mulDiv(sharesAdjusted, percentReturned, WAD);
        }

        // transfer the assets to the escrow
        _transferToEscrow(node, assetsReturned);

        // update the redemption request state on the node
        INode(node).finalizeRedemption(controller, assetsReturned, sharesPending, sharesAdjusted);
        return assetsReturned;
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Deposits assets into an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param assets The amount of assets to deposit.
    function _deposit(address node, address vault, uint256 assets) internal returns (uint256) {
        address underlying = IERC4626(vault).asset();
        INode(node).execute(underlying, 0, abi.encodeWithSelector(IERC20.approve.selector, vault, assets));

        bytes memory result =
            INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.deposit.selector, assets, node));
        return abi.decode(result, (uint256));
    }

    /// @notice Burns shares to assets in an ERC4626 vault on behalf of the Node.
    /// @param node The address of the node.
    /// @param vault The address of the ERC4626 vault.
    /// @param shares The amount of shares to burn.
    function _redeem(address node, address vault, uint256 shares) internal returns (uint256) {
        bytes memory result =
            INode(node).execute(vault, 0, abi.encodeWithSelector(IERC4626.redeem.selector, shares, node, node));
        return abi.decode(result, (uint256));
    }

    /// @notice Calculates the target investment size for a component.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAssets The target investment size.
    function _getInvestmentSize(address node, address component)
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

    /// @notice Liquidates a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param shares The amount of shares to liquidate.
    /// @return assetsReturned The amount of assets returned.
    function _liquidate(address node, address component, uint256 shares) internal returns (uint256 assetsReturned) {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }

        _validateNodeAcceptsRouter(node);

        // Validate share value
        if (shares == 0 || shares > IERC4626(component).balanceOf(address(node))) {
            revert ErrorsLib.InvalidShareValue(component, shares);
        }

        // Execute the redemption and check the correct number of assets returned
        uint256 expectedAssets = IERC4626(component).previewRedeem(shares);
        assetsReturned = _redeem(node, component, shares);
        if (assetsReturned < expectedAssets) {
            revert ErrorsLib.InsufficientAssetsReturned(component, assetsReturned, expectedAssets);
        }

        return assetsReturned;
    }
}
