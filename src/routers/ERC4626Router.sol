// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseComponentRouter} from "src/libraries/BaseComponentRouter.sol";
import {INode} from "src/interfaces/INode.sol";

/**
 * @title ERC4626Router
 * @author ODND Studios
 */
contract ERC4626Router is BaseComponentRouter, ReentrancyGuard {
    /* EVENTS */
    event InvestedInComponent(address indexed node, address indexed component, uint256 assets);
    event LiquidatedFromComponent(address indexed node, address indexed component, uint256 assets);
    event FulfilledRedeemRequest(address indexed node, address indexed component, uint256 assets);

    /* ERRORS */
    error ExceedsMaxComponentDeposit(address component, uint256 depositAmount, uint256 maxDeposit);
    error InsufficientSharesReturned(address component, uint256 sharesReturned, uint256 expectedShares);
    error InsufficientAssetsReturned(address component, uint256 assetsReturned, uint256 expectedAssets);
    error InvalidShareValue(address component, uint256 shares);

    /* CONSTRUCTOR */
    constructor(address registry_) BaseComponentRouter(registry_) {
        tolerance = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Invests in a component on behalf of the Node.
    /// @dev call by a valid node rebalancer to invest excess reserve into components
    /// enforces the strategy set by the Node Owner
    /// will revert if there is not sufficient excess reserve or if the component is within maxDelta
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAmount The amount of assets invested.
    function invest(address node, address component, uint256 minSharesOut)
        external
        nonReentrant
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
        returns (uint256 depositAmount)
    {
        depositAmount = _computeDepositAmount(node, component);

        // Check component deposit limits
        if (depositAmount > IERC4626(component).maxDeposit(address(node))) {
            revert ExceedsMaxComponentDeposit(component, depositAmount, IERC4626(component).maxDeposit(address(node)));
        }

        // Execute deposit and check correct shares received
        uint256 sharesBefore = IERC4626(component).balanceOf(address(node));
        uint256 expectedShares = IERC4626(component).previewDeposit(depositAmount);
        uint256 sharesReturned;

        _deposit(node, component, depositAmount);

        uint256 sharesAfter = IERC4626(component).balanceOf(address(node));
        if (sharesAfter < sharesBefore) {
            revert InsufficientSharesReturned(component, 0, expectedShares);
        } else {
            sharesReturned = sharesAfter - sharesBefore;
        }

        if ((sharesReturned + tolerance) < expectedShares) {
            revert InsufficientSharesReturned(component, sharesReturned, expectedShares);
        }

        if ((sharesReturned + tolerance) < minSharesOut) {
            revert InsufficientSharesReturned(component, sharesReturned, minSharesOut);
        }

        emit InvestedInComponent(node, component, depositAmount);
        return depositAmount;
    }

    /// @notice Liquidates a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param shares The amount of shares to liquidate.
    /// @return assetsReturned The amount of assets returned.
    function liquidate(address node, address component, uint256 shares, uint256 minAssetsOut)
        external
        nonReentrant
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
        returns (uint256 assetsReturned)
    {
        assetsReturned = _liquidate(node, component, shares);
        if ((assetsReturned + tolerance) < minAssetsOut) {
            revert InsufficientAssetsReturned(component, assetsReturned, minAssetsOut);
        }

        emit LiquidatedFromComponent(node, component, assetsReturned);
        return assetsReturned;
    }

    /// @notice Fulfills a redeem request on behalf of the Node.
    /// @dev Called by a rebalancer to liquidate a component in order to make assets available for user withdrawal
    /// Transfers the assets to Escrow and updates the Requst for the user
    /// Enforces liquidation queue to ensure asset liquidated is according to order set by the Node Owner
    /// @param node The address of the node.
    /// @param controller The address of the controller.
    /// @param component The address of the component.
    /// @return assetsReturned The amount of assets returned.
    function fulfillRedeemRequest(address node, address controller, address component, uint256 minAssetsOut)
        external
        nonReentrant
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
        returns (uint256 assetsReturned)
    {
        (uint256 sharesPending,,) = INode(node).requests(controller);
        uint256 assetsRequested = INode(node).convertToAssets(sharesPending);

        // Validate that the component is top of the liquidation queue
        INode(node).enforceLiquidationOrder(component, assetsRequested);

        // liquidate either the requested amount or the balance of the component
        // if the requested amount is greater than the balance of the component
        uint256 componentShares =
            Math.min(IERC4626(component).convertToShares(assetsRequested), IERC20(component).balanceOf(address(node)));

        // execute the liquidation
        assetsReturned = _liquidate(node, component, componentShares);

        if ((assetsReturned + tolerance) < minAssetsOut) {
            revert InsufficientAssetsReturned(component, assetsReturned, minAssetsOut);
        }

        // downscale sharesPending if assetsReturned is less than assetsRequested
        if (assetsReturned < assetsRequested) {
            sharesPending = _calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested);
        }

        // update the redemption request state on the node and transfer the assets to the escrow
        INode(node).finalizeRedemption(controller, assetsReturned, sharesPending);
        emit FulfilledRedeemRequest(node, component, assetsReturned);
        return assetsReturned;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the assets of a component held by the node.
    /// @param component The address of the component.
    /// @return assets The amount of assets of the component.
    function getComponentAssets(address component, bool) public view override returns (uint256) {
        return _getComponentAssets(component, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits assets into an ERC4626 component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the ERC4626 component.
    /// @param assets The amount of assets to deposit.
    function _deposit(address node, address component, uint256 assets) internal returns (uint256) {
        address underlying = INode(node).asset();
        _safeApprove(node, underlying, component, assets);

        bytes memory result = INode(node).execute(component, abi.encodeCall(IERC4626.deposit, (assets, node)));
        return abi.decode(result, (uint256));
    }

    /// @notice Burns shares to assets in an ERC4626 component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the ERC4626 component.
    /// @param shares The amount of shares to burn.
    function _redeem(address node, address component, uint256 shares) internal returns (uint256) {
        bytes memory result = INode(node).execute(component, abi.encodeCall(IERC4626.redeem, (shares, node, node)));
        return abi.decode(result, (uint256));
    }

    /// @inheritdoc BaseComponentRouter
    function getInvestmentSize(address node, address component) public view override returns (uint256 depositAssets) {
        uint256 targetHoldings =
            Math.mulDiv(INode(node).totalAssets(), INode(node).getComponentAllocation(component).targetWeight, WAD);

        uint256 currentBalance = _getComponentAssets(component, node);

        depositAssets = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
    }

    /// @notice Liquidates a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param shares The amount of shares to liquidate.
    /// @return assetsReturned The amount of assets returned.
    function _liquidate(address node, address component, uint256 shares) internal returns (uint256 assetsReturned) {
        // Validate share value
        if (shares == 0 || shares > IERC4626(component).balanceOf(address(node))) {
            revert InvalidShareValue(component, shares);
        }

        address asset = IERC4626(node).asset();
        uint256 balanceBefore = IERC20(asset).balanceOf(address(node));
        uint256 assets = IERC4626(component).previewRedeem(shares);

        _redeem(node, component, shares);

        uint256 balanceAfter = IERC20(asset).balanceOf(address(node));
        if (balanceAfter < balanceBefore) {
            revert InsufficientAssetsReturned(component, 0, assets);
        } else {
            assetsReturned = balanceAfter - balanceBefore;
        }

        if ((assetsReturned + tolerance) < assets) {
            revert InsufficientAssetsReturned(component, assetsReturned, assets);
        }

        return assetsReturned;
    }

    /// @notice Returns the assets of a component held by the node.
    /// @param component The address of the component.
    /// @param node The address of the node.
    /// @return assets The amount of assets of the component.
    function _getComponentAssets(address component, address node) internal view returns (uint256) {
        uint256 balance = IERC20(component).balanceOf(node);
        return IERC4626(component).previewRedeem(balance);
    }
}
