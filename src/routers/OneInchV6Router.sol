// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {INode} from "src/interfaces/INode.sol";
import {IAggregationRouterV6} from "src/interfaces/IAggregationRouterV6.sol";
import {BaseRouter} from "src/libraries/BaseRouter.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract OneInchV6Router is BaseRouter, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* IMMUTABLES */

    /// @notice The address of the 1inch Aggregation Router v6
    address public constant ONE_INCH_AGGREGATION_ROUTER_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;

    /* EVENTS */

    // TODO:
    event IncentiveWhitelisted(address indexed incentive, bool status);
    event ExecutorWhitelisted(address indexed executor, bool status);

    /// @notice Emitted when incentive is swapped into underlying token
    event Compounded(
        address indexed node,
        address indexed incentive,
        uint256 incentiveAmount,
        uint256 assetAmount,
        uint256 assetAmountAfterFee
    );

    /* Errors */

    // TODO:
    error ExecutorNotWhitelisted();
    error IncentiveNotWhitelisted();
    error IncentiveIsAsset();
    error IncentiveIsComponent();
    error IncentiveIncompleteSwap();
    error IncentiveInsufficientAmount();

    /* STORAGE */

    // TODO:
    mapping(address => bool) isIncentiveWhitelisted;
    mapping(address => bool) isExecutorWhitelisted;

    /* CONSTRUCTOR */
    constructor(address registry_) BaseRouter(registry_) {
        // TODO:
        tolerance = 1;
    }

    /* FUNCTIONS */

    /*//////////////////////////////////////////////////////////////
                         REGISTRY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the whitelist status of an incentive
    /// @param incentive The address to update
    /// @param status The new whitelist status
    function setIncentiveWhitelistStatus(address incentive, bool status) external onlyRegistryOwner {
        if (incentive == address(0)) revert ErrorsLib.ZeroAddress();
        isIncentiveWhitelisted[incentive] = status;
        emit IncentiveWhitelisted(incentive, status);
    }

    /// @notice Updates the whitelist status of an executor
    /// @param executor The address to update
    /// @param status The new whitelist status
    function setExecutorWhitelistStatus(address executor, bool status) external onlyRegistryOwner {
        if (executor == address(0)) revert ErrorsLib.ZeroAddress();
        isExecutorWhitelisted[executor] = status;
        emit IncentiveWhitelisted(executor, status);
    }

    function swap(
        address node,
        address incentive,
        uint256 incentiveAmount,
        uint256 minAssetsOut,
        address executor,
        bytes calldata swapCalldata
    ) external nonReentrant onlyNodeRebalancer(node) {
        address asset = INode(node).asset();

        require(asset != incentive, IncentiveIsAsset());
        require(!INode(node).isComponent(incentive), IncentiveIsComponent());
        require(isIncentiveWhitelisted[incentive], IncentiveNotWhitelisted());
        require(isExecutorWhitelisted[executor], ExecutorNotWhitelisted());
        require(IERC20(incentive).balanceOf(node) >= incentiveAmount, IncentiveInsufficientAmount());

        _validateAmounts(incentive, incentiveAmount, asset, minAssetsOut);

        // approve spending incentive by 1inch router
        _safeApprove(node, incentive, ONE_INCH_AGGREGATION_ROUTER_V6, incentiveAmount);

        IAggregationRouterV6.SwapDescription memory swapDescription = IAggregationRouterV6.SwapDescription({
            srcToken: incentive,
            dstToken: asset,
            // should be only executor
            srcReceiver: executor,
            // node itself receives assets
            dstReceiver: node,
            amount: incentiveAmount,
            // it checked on AggregationRouterV6 that it is not zero
            // reverts if returned amount is less than minReturnAmount
            minReturnAmount: minAssetsOut,
            // no permit is used, no partial fills or extra eth swaps
            flags: 0
        });
        bytes memory result = INode(node).execute(
            ONE_INCH_AGGREGATION_ROUTER_V6,
            abi.encodeCall(IAggregationRouterV6.swap, (executor, swapDescription, swapCalldata))
        );
        (uint256 returnAmount, uint256 spentAmount) = abi.decode(result, (uint256, uint256));
        require(spentAmount == incentiveAmount, IncentiveIncompleteSwap());

        // TODO: is it possible to updateTotalAssets before subtracting the fee?

        uint256 returnAmountAfterFee = _subtractExecutionFee(returnAmount, node);

        emit Compounded(node, incentive, incentiveAmount, returnAmount, returnAmountAfterFee);
    }

    // TODO: convert to USD and using the tolerance check acceptable deviation
    // can revert
    function _validateAmounts(address incentive, uint256 incentiveAmount, address asset, uint256 assetAmount)
        internal
    {}
}
