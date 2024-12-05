// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRouter} from "../libraries/BaseRouter.sol";
import {INode} from "../interfaces/INode.sol";

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "../interfaces/IERC7540.sol";
import {IERC7575} from "../interfaces/IERC7575.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

/**
 * @title ERC7540Router
 * @dev Router for ERC7540 vaults
 */
contract ERC7540Router is BaseRouter {
    /* CONSTRUCTOR */
    constructor(address registry_) BaseRouter(registry_) {}

    /* EXTERNAL FUNCTIONS */

    function investInAsyncVault(address node, address component)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256 cashInvested)
    {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }

        uint256 totalAssets_ = INode(node).totalAssets();
        uint256 idealCashReserve = MathLib.mulDiv(totalAssets_, INode(node).targetReserveRatio(), WAD);
        uint256 currentCash = IERC20(INode(node).asset()).balanceOf(address(node));

        // checks if available reserve exceeds target ratio
        if (currentCash < idealCashReserve) {
            revert ErrorsLib.ReserveBelowTargetRatio();
        }

        // gets deposit amount
        uint256 depositAmount = _getInvestmentSize(node, component);

        // Check if the current allocation is below the lower bound
        uint256 currentAllocation = MathLib.mulDiv(_getErc7540Assets(node, component), WAD, totalAssets_);
        uint256 lowerBound = INode(node).getComponentRatio(component) - INode(node).getMaxDelta(component);

        if (currentAllocation >= lowerBound) {
            revert ErrorsLib.ComponentWithinTargetRange(node, component);
        }

        // get max transaction size that will maintain reserve ratio
        uint256 availableReserve = currentCash - idealCashReserve;

        // limits the depositAmount to this transaction size
        if (depositAmount > availableReserve) {
            depositAmount = availableReserve;
        }

        uint256 requestId = _requestDeposit(node, component, depositAmount);
        require(requestId == 0, "No requestId returned");
        return (requestId);
    }

    function mintClaimableShares(address node, address component) public onlyNodeRebalancer(node) returns (uint256) {
        uint256 claimableShares = IERC7575(component).maxMint(address(node));

        uint256 sharesReceived = _mint(node, component, claimableShares);
        require(sharesReceived >= claimableShares, "Not enough shares received");

        return sharesReceived;
    }

    function requestAsyncWithdrawal(address node, address component, uint256 shares)
        public
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
    // todo check is a valid node component
    {
        address shareToken = IERC7575(component).share();
        if (shares > IERC20(shareToken).balanceOf(address(node))) {
            revert ErrorsLib.ExceedsAvailableShares(node, component, shares);
        }

        uint256 requestId = _requestRedeem(node, component, shares);
        require(requestId == 0, "No requestId returned");
    }

    // withdraws claimable assets from async vault
    function executeAsyncWithdrawal(address node, address component, uint256 assets)
        public
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (
            // todo check is a valid node component
            uint256 assetsReceived
        )
    {
        if (assets > IERC7575(component).maxWithdraw(address(node))) {
            revert ErrorsLib.ExceedsAvailableAssets(node, component, assets);
        }

        assetsReceived = _withdraw(node, component, assets);
        require(assetsReceived >= assets, "Not enough assets received");

        return assetsReceived;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _requestDeposit(address node, address component, uint256 assets) internal returns (uint256) {
        address underlying = IERC4626(component).asset();

        INode(node).execute(underlying, 0, abi.encodeWithSelector(IERC20.approve.selector, component, assets));

        bytes memory result = INode(node).execute(
            component, 0, abi.encodeWithSelector(IERC7540Deposit.requestDeposit.selector, assets, node, node)
        );
        return abi.decode(result, (uint256));
    }

    function _mint(address node, address component, uint256 claimableShares) internal returns (uint256) {
        address shareToken = IERC7575(component).share();
        // Approve the component to spend share tokens
        INode(node).execute(shareToken, 0, abi.encodeWithSelector(IERC20.approve.selector, component, claimableShares));

        bytes memory result = INode(node).execute(
            component, 0, abi.encodeWithSelector(IERC7540Deposit.mint.selector, claimableShares, node, node)
        );

        return abi.decode(result, (uint256));
    }

    function _requestRedeem(address node, address component, uint256 shares) internal returns (uint256) {
        bytes memory result = INode(node).execute(
            component, 0, abi.encodeWithSelector(IERC7540Redeem.requestRedeem.selector, shares, node, node)
        );
        return abi.decode(result, (uint256));
    }

    function _withdraw(address node, address component, uint256 assets) internal returns (uint256) {
        bytes memory result =
            INode(node).execute(component, 0, abi.encodeWithSelector(IERC7575.withdraw.selector, assets, node, node));
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

        address shareToken = IERC7575(component).share();
        uint256 currentBalance = IERC20(shareToken).balanceOf(address(node));

        uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
        return delta;
    }

    // todo: delete this later and call it from quoter via node instead
    function _getErc7540Assets(address node, address component) internal view returns (uint256) {
        uint256 assets;
        address shareToken = IERC7575(component).share();
        uint256 shareBalance = IERC20(shareToken).balanceOf(node);

        if (shareBalance > 0) {
            assets = IERC4626(component).convertToAssets(shareBalance);
        }
        /// @dev in ERC7540 deposits are denominated in assets and redeems are in shares
        assets += IERC7540(component).pendingDepositRequest(0, node);
        assets += IERC7540(component).claimableDepositRequest(0, node);
        assets += IERC4626(component).convertToAssets(IERC7540(component).pendingRedeemRequest(0, node));
        assets += IERC4626(component).convertToAssets(IERC7540(component).claimableRedeemRequest(0, node));

        return assets;
    }
}
