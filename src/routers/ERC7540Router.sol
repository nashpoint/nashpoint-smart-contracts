// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRouter} from "../libraries/BaseRouter.sol";
import {INode} from "../interfaces/INode.sol";
import {IQuoterV1} from "../interfaces/IQuoterV1.sol";

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

    // todo need to deal with cases where shares pending, claimable etc
    function investInAsyncVault(address node, address component)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256 cashInvested)
    {
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }

        uint256 totalAssets_ = INode(node).totalAssets();
        uint256 currentCash = IERC20(INode(node).asset()).balanceOf(address(node))
            - INode(node).convertToAssets(INode(node).sharesExiting());
        uint256 idealCashReserve = MathLib.mulDiv(totalAssets_, INode(node).targetReserveRatio(), WAD);

        // checks if available reserve exceeds target ratio
        _validateReserveAboveTargetRatio(node);

        // gets deposit amount
        uint256 depositAmount = _getInvestmentSize(node, component);

        // Validate deposit amount exceeds minimum threshold
        if (depositAmount < MathLib.mulDiv(totalAssets_, INode(node).getMaxDelta(component), WAD)) {
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

    function mintClaimableShares(address node, address component)
        public
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
        returns (uint256)
    {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }
        uint256 claimableShares = IERC7575(component).maxMint(address(node));

        uint256 sharesReceived = _mint(node, component, claimableShares);
        require(sharesReceived >= claimableShares, "Not enough shares received");

        return sharesReceived;
    }

    function requestAsyncWithdrawal(address node, address component, uint256 shares)
        public
        onlyNodeRebalancer(node)
        onlyWhitelisted(component)
    {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }
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
        returns (uint256 assetsReceived)
    {
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }

        if (assets > IERC7575(component).maxWithdraw(address(node))) {
            revert ErrorsLib.ExceedsAvailableAssets(node, component, assets);
        }

        assetsReceived = IERC7575(component).convertToAssets(_withdraw(node, component, assets));

        if (assetsReceived < assets) {
            revert ErrorsLib.InsufficientAssetsReturned(component, assetsReceived, assets);
        }
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

    function _getInvestmentSize(address node, address component)
        internal
        view
        override
        returns (uint256 depositAssets)
    {
        uint256 targetHoldings =
            MathLib.mulDiv(INode(node).totalAssets(), INode(node).getComponentRatio(component), WAD);

        uint256 currentBalance = _getErc7540Assets(node, component);

        uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
        return delta;
    }

    function _getErc7540Assets(address node, address component) internal view returns (uint256) {
        address quoter = address(INode(node).quoter());
        return IQuoterV1(quoter).getErc7540Assets(node, component);
    }
}
