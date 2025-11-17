// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {BaseComponentRouter} from "src/libraries/BaseComponentRouter.sol";
import {INode} from "src/interfaces/INode.sol";

import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

/**
 * @title ERC7540Router
 * @author ODND Studios
 */
contract ERC7540Router is BaseComponentRouter, ReentrancyGuard {
    uint256 internal constant REQUEST_ID = 0;

    /* EVENTS */
    event InvestedInAsyncComponent(address indexed node, address indexed component, uint256 assets);
    event MintedClaimableShares(address indexed node, address indexed component, uint256 sharesReceived);
    event RequestedAsyncWithdrawal(address indexed node, address indexed component, uint256 shares);
    event AsyncWithdrawalExecuted(address indexed node, address indexed component, uint256 assetsReceived);
    event FulfilledRedeemRequest(address indexed node, address indexed component, uint256 assets);

    /* ERRORS */
    error InsufficientSharesReturned(address component, uint256 sharesReturned, uint256 expectedShares);
    error InsufficientAssetsReturned(address component, uint256 assetsReturned, uint256 expectedAssets);
    error ExceedsAvailableShares(address node, address component, uint256 shares);
    error ExceedsAvailableAssets(address node, address component, uint256 assets);
    error IncorrectRequestId(uint256 requestId);

    /* CONSTRUCTOR */
    constructor(address registry_) BaseComponentRouter(registry_) {
        tolerance = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fulfills a redeem request on behalf of the Node.
    /// @dev Called by a rebalancer to liquidate a component in order to make assets available for user withdrawal
    /// Transfers the assets to Escrow and updates the Requst for the user
    /// @param node The address of the node.
    /// @param controller The address of the controller.
    /// @param component The address of the component.
    /// @return assetsReturned The amount of assets returned.
    function fulfillRedeemRequest(address node, address controller, address component)
        external
        nonReentrant
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
        returns (uint256 assetsReturned)
    {
        (uint256 sharesPending,,) = INode(node).requests(controller);
        uint256 assetsRequested = INode(node).convertToAssets(sharesPending);

        // Get the max amount of assets that can be withdrawn from the async component atomically
        uint256 maxClaimableAssets = IERC7575(component).maxWithdraw(node);

        // execute the withdrawal
        assetsReturned = _executeAsyncWithdrawal(node, component, Math.min(assetsRequested, maxClaimableAssets));

        // downscale sharesPending if assetsReturned is less than assetsRequested
        if (assetsReturned < assetsRequested) {
            sharesPending = _calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested);
        }

        // update the redemption request state on the node and transfer the assets to the escrow
        INode(node).finalizeRedemption(controller, assetsReturned, sharesPending);
        emit FulfilledRedeemRequest(node, component, assetsReturned);
        return assetsReturned;
    }

    /// @notice Invests in a component on behalf of the Node.
    /// @dev call by a valid node rebalancer to invest excess reserve into components
    /// enforces the strategy set by the Node Owner
    /// will revert if there is not sufficient excess reserve or if the target component is within maxDelta
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAmount The amount of cash invested.
    function investInAsyncComponent(address node, address component)
        external
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
        returns (uint256 depositAmount)
    {
        depositAmount = _computeDepositAmount(node, component);

        uint256 requestId = _requestDeposit(node, component, depositAmount);
        if (requestId != REQUEST_ID) {
            revert IncorrectRequestId(requestId);
        }

        emit InvestedInAsyncComponent(node, component, depositAmount);
        return depositAmount;
    }

    /// @notice Mints claimable shares for a component on behalf of the Node.
    /// @dev call by a valid node rebalancer to mint shares for a component
    /// will revert if there is not sufficient shares available to mint
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return sharesReceived The amount of shares received.
    function mintClaimableShares(address node, address component)
        external
        nonReentrant
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
        returns (uint256 sharesReceived)
    {
        uint256 claimableShares = IERC7575(component).maxMint(address(node));

        address share = IERC7575(component).share();
        uint256 balanceBefore = IERC20(share).balanceOf(address(node));

        _mint(node, component, claimableShares);

        uint256 balanceAfter = IERC20(share).balanceOf(address(node));
        if (balanceAfter < balanceBefore) {
            revert InsufficientSharesReturned(component, 0, claimableShares);
        } else {
            sharesReceived = balanceAfter - balanceBefore;
        }

        if ((sharesReceived + tolerance) < claimableShares) {
            revert InsufficientSharesReturned(component, sharesReceived, claimableShares);
        }

        emit MintedClaimableShares(node, component, sharesReceived);
        return sharesReceived;
    }

    /// @notice Requests an async withdrawal for a component on behalf of the Node.
    /// @dev call by a valid node rebalancer to request an async withdrawal for a component
    /// will revert if there is not sufficient shares available to redeem
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param shares The amount of shares to redeem.
    function requestAsyncWithdrawal(address node, address component, uint256 shares)
        external
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
    {
        address shareToken = IERC7575(component).share();
        if (shares > IERC20(shareToken).balanceOf(address(node))) {
            revert ExceedsAvailableShares(node, component, shares);
        }

        uint256 requestId = _requestRedeem(node, component, shares);
        if (requestId != REQUEST_ID) {
            revert IncorrectRequestId(requestId);
        }

        emit RequestedAsyncWithdrawal(node, component, shares);
    }

    /// @notice Withdraws claimable assets from async component
    /// @dev call by a valid node rebalancer to withdraw claimable assets from a component
    /// will revert if there is not sufficient assets available to withdraw
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param assets The amount of assets to withdraw.
    /// @return assetsReceived The amount of assets received.
    function executeAsyncWithdrawal(address node, address component, uint256 assets)
        public
        nonReentrant
        onlyNodeRebalancer(node)
        onlyNodeComponent(node, component)
        returns (uint256 assetsReceived)
    {
        assetsReceived = _executeAsyncWithdrawal(node, component, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the assets of a component held by the node.
    /// @param component The address of the component.
    /// @param claimableOnly Whether the assets are claimable.
    /// @return assets The amount of assets of the component.

    function getComponentAssets(address component, bool claimableOnly) public view override returns (uint256 assets) {
        return
            claimableOnly ? _getClaimableErc7540Assets(msg.sender, component) : _getErc7540Assets(msg.sender, component);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal functions for ERC7540Router
     * Each function maps directly to a function defined in the ERC-7540 spec
     * link: https://eips.ethereum.org/EIPS/eip-7540
     */

    /// @notice Requests a deposit for a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param assets The amount of assets to deposit.
    /// @return requestId The request ID.
    function _requestDeposit(address node, address component, uint256 assets) internal returns (uint256) {
        address underlying = INode(node).asset();
        _safeApprove(node, underlying, component, assets);

        bytes memory result =
            INode(node).execute(component, abi.encodeCall(IERC7540Deposit.requestDeposit, (assets, node, node)));
        return abi.decode(result, (uint256));
    }

    /// @notice Mints claimable shares for a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param claimableShares The amount of shares to mint.
    /// @return sharesReceived The amount of shares received.
    function _mint(address node, address component, uint256 claimableShares) internal returns (uint256) {
        bytes memory result =
            INode(node).execute(component, abi.encodeCall(IERC7540Deposit.mint, (claimableShares, node, node)));

        return abi.decode(result, (uint256));
    }

    /// @notice Requests a redemption for a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param shares The amount of shares to redeem.
    /// @return requestId The request ID.
    function _requestRedeem(address node, address component, uint256 shares) internal returns (uint256) {
        address shareToken = IERC7575(component).share();
        _safeApprove(node, shareToken, component, shares);
        bytes memory result =
            INode(node).execute(component, abi.encodeCall(IERC7540Redeem.requestRedeem, (shares, node, node)));
        return abi.decode(result, (uint256));
    }

    /// @notice Withdraws assets from a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param assets The amount of assets to withdraw.
    /// @return assetsReceived The amount of assets received.
    function _withdraw(address node, address component, uint256 assets) internal returns (uint256) {
        bytes memory result = INode(node).execute(component, abi.encodeCall(IERC7575.withdraw, (assets, node, node)));
        return abi.decode(result, (uint256));
    }

    /// @inheritdoc BaseComponentRouter
    function getInvestmentSize(address node, address component) public view override returns (uint256 depositAssets) {
        uint256 targetHoldings =
            Math.mulDiv(INode(node).totalAssets(), INode(node).getComponentAllocation(component).targetWeight, WAD);

        uint256 currentBalance = _getErc7540Assets(node, component);

        depositAssets = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
    }

    /// @notice Returns the amount of assets in a component.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return assets The amount of assets.
    function _getErc7540Assets(address node, address component) internal view returns (uint256 assets) {
        address shareToken = IERC7575(component).share();
        uint256 shares = IERC20(shareToken).balanceOf(node);

        shares += IERC7540(component).pendingRedeemRequest(REQUEST_ID, node);
        // maxWithdraw should be used over claimableRedeemRequest since the last might lead
        // to inflation of assets due to share price being changed
        uint256 maxWithdraw = IERC7575(component).maxWithdraw(node);
        // according to https://eips.ethereum.org/EIPS/eip-4626#maxwithdraw
        // it should return 0 if withdrawals are paused
        if (maxWithdraw == 0) {
            // in that case we need to include claimableRedeemRequest for convertToAssets
            shares += IERC7540(component).claimableRedeemRequest(REQUEST_ID, node);
        }
        assets = shares > 0 ? IERC4626(component).convertToAssets(shares) : 0;
        assets += maxWithdraw;
        assets += IERC7540(component).pendingDepositRequest(REQUEST_ID, node);
        assets += IERC7540(component).claimableDepositRequest(REQUEST_ID, node);

        return assets;
    }

    function _getClaimableErc7540Assets(address node, address component) internal view returns (uint256 assets) {
        return IERC4626(component).maxWithdraw(node);
    }

    function _executeAsyncWithdrawal(address node, address component, uint256 assets)
        internal
        returns (uint256 assetsReceived)
    {
        if (assets > IERC7575(component).maxWithdraw(address(node))) {
            revert ExceedsAvailableAssets(node, component, assets);
        }

        address asset = IERC7575(node).asset();
        uint256 balanceBefore = IERC20(asset).balanceOf(address(node));

        _withdraw(node, component, assets);

        uint256 balanceAfter = IERC20(asset).balanceOf(address(node));
        if (balanceAfter < balanceBefore) {
            revert InsufficientAssetsReturned(component, 0, assets);
        } else {
            assetsReceived = balanceAfter - balanceBefore;
        }

        if ((assetsReceived + tolerance) < assets) {
            revert InsufficientAssetsReturned(component, assetsReceived, assets);
        }

        emit AsyncWithdrawalExecuted(node, component, assetsReceived);
        return assetsReceived;
    }
}
