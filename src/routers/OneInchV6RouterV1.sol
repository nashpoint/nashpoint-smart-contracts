// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {INode} from "src/interfaces/INode.sol";
import {IAggregationRouterV6} from "src/interfaces/IAggregationRouterV6.sol";
import {BaseComponentRouter} from "src/libraries/BaseComponentRouter.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract OneInchV6RouterV1 is BaseComponentRouter, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* IMMUTABLES */

    /// @notice The address of the 1inch Aggregation Router v6
    address public constant ONE_INCH_AGGREGATION_ROUTER_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;

    /* EVENTS */

    /// @notice Emitted when an incentive token is whitelisted or blacklisted
    /// @param incentive The address of the incentive token
    /// @param status True if whitelisted, false if blacklisted
    event IncentiveWhitelisted(address indexed incentive, bool status);

    /// @notice Emitted when an executor address is whitelisted or blacklisted
    /// @param executor The address of the executor
    /// @param status True if whitelisted, false if blacklisted
    event ExecutorWhitelisted(address indexed executor, bool status);

    /// @notice Emitted when incentive tokens are successfully swapped into underlying assets
    /// @param node The address of the node that performed the swap
    /// @param incentive The address of the incentive token that was swapped
    /// @param incentiveAmount The amount of incentive tokens that were swapped
    /// @param assetAmount The amount of underlying assets received from the swap
    /// @param assetAmountAfterFee The amount of underlying assets after execution fees are deducted
    event Compounded(
        address indexed node,
        address indexed incentive,
        uint256 incentiveAmount,
        uint256 assetAmount,
        uint256 assetAmountAfterFee
    );

    /* Errors */

    /// @notice Thrown when the executor is not whitelisted
    error ExecutorNotWhitelisted();

    /// @notice Thrown when the incentive token is not whitelisted
    error IncentiveNotWhitelisted();

    /// @notice Thrown when the incentive token is the same as the node's asset
    error IncentiveIsAsset();

    /// @notice Thrown when the incentive token is a component of the node
    error IncentiveIsComponent();

    /// @notice Thrown when the swap operation doesn't spend the full incentive amount
    error IncentiveIncompleteSwap();

    /// @notice Thrown when the node doesn't have sufficient incentive tokens
    error IncentiveInsufficientAmount();

    /* STORAGE */

    /// @notice Mapping to track whitelisted incentive tokens
    /// @dev incentive address => whitelist status
    mapping(address => bool) isIncentiveWhitelisted;

    /// @notice Mapping to track whitelisted executor addresses
    /// @dev executor address => whitelist status
    mapping(address => bool) isExecutorWhitelisted;

    /* CONSTRUCTOR */
    constructor(address registry_) BaseComponentRouter(registry_) {}

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
        emit ExecutorWhitelisted(executor, status);
    }

    /// @notice Swaps incentive tokens to underlying assets using 1inch Aggregation Router v6
    /// @param node The address of the node contract
    /// @param incentive The address of the incentive token to swap
    /// @param incentiveAmount The amount of incentive tokens to swap
    /// @param minAssetsOut The minimum amount of assets to receive from the swap
    /// @param executor The address of the executor that will receive the incentive tokens
    /// @param swapCalldata The calldata for the 1inch swap operation
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

        uint256 returnAmountAfterFee = _subtractExecutionFee(returnAmount, node);

        emit Compounded(node, incentive, incentiveAmount, returnAmount, returnAmountAfterFee);
    }
}
