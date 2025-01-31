// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRouter} from "../libraries/BaseRouter.sol";
import {INode} from "../interfaces/INode.sol";
import {IQuoterV1} from "../interfaces/IQuoterV1.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "../interfaces/IERC7540.sol";
import {IERC7575} from "../interfaces/IERC7575.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {EventsLib} from "../libraries/EventsLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

/**
 * @title ERC7540Router
 * @author ODND Studios
 */
contract ERC7540Router is BaseRouter, ReentrancyGuard {
    uint256 internal constant REQUEST_ID = 0;

    /* EVENTS */
    event InvestedInAsyncComponent(address indexed node, address indexed component, uint256 assets);
    event MintedClaimableShares(address indexed node, address indexed component, uint256 sharesReceived);
    event RequestedAsyncWithdrawal(address indexed node, address indexed component, uint256 shares);
    event AsyncWithdrawalExecuted(address indexed node, address indexed component, uint256 assetsReceived);

    /* CONSTRUCTOR */
    constructor(address registry_) BaseRouter(registry_) {
        tolerance = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        onlyWhitelisted(component)
        onlyNodeComponent(node, component)
        returns (uint256 depositAmount)
    {
        depositAmount = _computeDepositAmount(node, component);

        uint256 requestId = _requestDeposit(node, component, depositAmount);
        if (requestId != REQUEST_ID) {
            revert ErrorsLib.IncorrectRequestId(requestId);
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
        onlyWhitelisted(component)
        onlyNodeComponent(node, component)
        returns (uint256 sharesReceived)
    {
        uint256 claimableShares = IERC7575(component).maxMint(address(node));

        address share = IERC7575(component).share();
        uint256 balanceBefore = IERC20(share).balanceOf(address(node));

        _mint(node, component, claimableShares);

        uint256 balanceAfter = IERC20(share).balanceOf(address(node));
        if (balanceAfter < balanceBefore) {
            revert ErrorsLib.InsufficientSharesReturned(component, 0, claimableShares);
        } else {
            sharesReceived = balanceAfter - balanceBefore;
        }

        if (sharesReceived + tolerance < claimableShares) {
            revert ErrorsLib.InsufficientSharesReturned(component, sharesReceived, claimableShares);
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
        onlyWhitelisted(component)
        onlyNodeComponent(node, component)
    {
        address shareToken = IERC7575(component).share();
        if (shares > IERC20(shareToken).balanceOf(address(node))) {
            revert ErrorsLib.ExceedsAvailableShares(node, component, shares);
        }

        uint256 requestId = _requestRedeem(node, component, shares);
        if (requestId != REQUEST_ID) {
            revert ErrorsLib.IncorrectRequestId(requestId);
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
        external
        nonReentrant
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        onlyNodeComponent(node, component)
        returns (uint256 assetsReceived)
    {
        if (assets > IERC7575(component).maxWithdraw(address(node))) {
            revert ErrorsLib.ExceedsAvailableAssets(node, component, assets);
        }

        address asset = IERC7575(node).asset();
        uint256 balanceBefore = IERC20(asset).balanceOf(address(node));

        _withdraw(node, component, assets);

        uint256 balanceAfter = IERC20(asset).balanceOf(address(node));
        if (balanceAfter < balanceBefore) {
            revert ErrorsLib.InsufficientAssetsReturned(component, 0, assets);
        } else {
            assetsReceived = balanceAfter - balanceBefore;
        }

        if ((assetsReceived + tolerance) < assets) {
            revert ErrorsLib.InsufficientAssetsReturned(component, assetsReceived, assets);
        }

        emit AsyncWithdrawalExecuted(node, component, assetsReceived);
        return assetsReceived;
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
        address underlying = IERC4626(component).asset();
        _safeApprove(node, underlying, component, assets);

        bytes memory result = INode(node).execute(
            component, abi.encodeWithSelector(IERC7540Deposit.requestDeposit.selector, assets, node, node)
        );
        return abi.decode(result, (uint256));
    }

    /// @notice Mints claimable shares for a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param claimableShares The amount of shares to mint.
    /// @return sharesReceived The amount of shares received.
    function _mint(address node, address component, uint256 claimableShares) internal returns (uint256) {
        bytes memory result = INode(node).execute(
            component, abi.encodeWithSelector(IERC7540Deposit.mint.selector, claimableShares, node, node)
        );

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
        bytes memory result = INode(node).execute(
            component, abi.encodeWithSelector(IERC7540Redeem.requestRedeem.selector, shares, node, node)
        );
        return abi.decode(result, (uint256));
    }

    /// @notice Withdraws assets from a component on behalf of the Node.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @param assets The amount of assets to withdraw.
    /// @return assetsReceived The amount of assets received.
    function _withdraw(address node, address component, uint256 assets) internal returns (uint256) {
        bytes memory result =
            INode(node).execute(component, abi.encodeWithSelector(IERC7575.withdraw.selector, assets, node, node));
        return abi.decode(result, (uint256));
    }

    /// @notice Returns the investment size for a component.
    /// @dev calculates the amount of assets to deposit to set the component to the target ratio
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAssets The amount of assets to deposit.
    function _getInvestmentSize(address node, address component)
        internal
        view
        override
        returns (uint256 depositAssets)
    {
        uint256 targetHoldings =
            MathLib.mulDiv(INode(node).totalAssets(), INode(node).getComponentAllocation(component).targetWeight, WAD);

        uint256 currentBalance = _getErc7540Assets(node, component);

        uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
        return delta;
    }

    /// @notice Returns the amount of assets in a component.
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return assets The amount of assets.
    function _getErc7540Assets(address node, address component) internal view returns (uint256) {
        address quoter = address(INode(node).quoter());
        return IQuoterV1(quoter).getErc7540Assets(node, component);
    }
}
