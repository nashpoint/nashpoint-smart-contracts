// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Node} from "src/Node.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract OneInchV6Router is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    struct SwapVars {
        uint256 nodeUnderlyingBalanceBefore;
        uint256 nodeUnderlyingBalanceAfter;
        uint256 routerUnderlyingBalanceBefore;
        uint256 routerUnderlyingBalanceAfter;
        uint256 routerIncentiveBalanceBefore;
        uint256 routerIncentiveBalanceAfter;
    }

    /* IMMUTABLES */

    uint256 constant WAD = 1e18;

    /// @notice The address of the 1inch Aggregation Router v6
    address public constant ONE_INCH_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;

    /// @notice The address of the NodeRegistry
    INodeRegistry public immutable registry;

    /* EVENTS */

    /// @notice Emitted when incentive is swapped into underlying token
    event Compounded(
        address indexed node,
        address indexed incentiveAddress,
        uint256 incentiveAmount,
        uint256 nodeCompounded,
        uint256 feeTaken
    );

    /* Errors */

    /// @notice it is forbidden to swap component shares or underlying asset
    error ForbiddenToSwap();
    /// @notice there should be no leftovers of incentive token
    error IncompleteIncentiveSwap();
    /// @notice Node balance of underlying asset did not increase
    error ZeroValueSwap();

    /* CONSTRUCTOR */

    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not a rebalancer for the node
    modifier onlyNodeRebalancer(address node) {
        if (!registry.isNode(node)) revert ErrorsLib.InvalidNode();
        if (!Node(node).isRebalancer(msg.sender)) revert ErrorsLib.NotRebalancer();
        _;
    }

    /* FUNCTIONS */

    /// @notice Swap a node’s incentive token into the underlying via 1inch, take a protocol fee, and forward net to the node.
    /// @dev Only callable by a node rebalancer. Flow: pull full `incentive` from `node` → approve 1inch v6 → swap
    ///      (proceeds arrive to this contract) → compute fee → transfer `swapped - fee` to `node`.
    ///      Assumes 1inch calldata routes `dstToken == underlying` and `dstReceiver == address(this)`.
    /// @param node The Node being compounded.
    /// @param incentive ERC20 incentive token to swap into the node’s underlying.
    /// @param swapCalldata Encoded 1inch v6 payload.
    /// @custom:reverts ForbiddenToSwap If `incentive` is the node’s underlying or a component share.
    /// @custom:reverts ZeroValueSwap If no underlying is received by this contract from the swap, or if the node’s
    ///                               underlying does not increase after forwarding.
    /// @custom:reverts IncompleteIncentiveSwap If this contract’s `incentive` balance changes after the swap (dust/leftovers).
    /// @custom:emits Compounded Emitted with `incentiveAmount` (pulled), `nodeCompounded` (net to node), and `feeTaken`.
    function swap(address node, address incentive, bytes calldata swapCalldata)
        external
        nonReentrant
        onlyNodeRebalancer(node)
    {
        address underlyingAsset = Node(node).asset();
        if (underlyingAsset == incentive || Node(node).isComponent(incentive)) revert ForbiddenToSwap();

        uint256 incentiveBalance = IERC20(incentive).balanceOf(node);
        if (incentiveBalance == 0) revert ZeroValueSwap();

        // to avoid stack too deep error
        SwapVars memory vars;

        vars.nodeUnderlyingBalanceBefore = IERC20(underlyingAsset).balanceOf(node);
        vars.routerUnderlyingBalanceBefore = IERC20(underlyingAsset).balanceOf(address(this));
        vars.routerIncentiveBalanceBefore = IERC20(incentive).balanceOf(address(this));

        Node(node).execute(incentive, abi.encodeCall(IERC20.transfer, (address(this), incentiveBalance)));
        IERC20(incentive).safeIncreaseAllowance(ONE_INCH_V6, incentiveBalance);
        ONE_INCH_V6.functionCall(swapCalldata);

        vars.routerUnderlyingBalanceAfter = IERC20(underlyingAsset).balanceOf(address(this));
        vars.routerIncentiveBalanceAfter = IERC20(incentive).balanceOf(address(this));

        if (vars.routerUnderlyingBalanceAfter <= vars.routerUnderlyingBalanceBefore) revert ZeroValueSwap();
        if (vars.routerIncentiveBalanceAfter != vars.routerIncentiveBalanceBefore) revert IncompleteIncentiveSwap();

        uint256 swapped = vars.routerUnderlyingBalanceAfter - vars.routerUnderlyingBalanceBefore;
        uint256 executionFee = swapped * registry.protocolExecutionFee() / WAD;

        uint256 nodeCompounded = swapped - executionFee;

        IERC20(underlyingAsset).safeTransfer(node, nodeCompounded);
        IERC20(underlyingAsset).safeTransfer(registry.protocolFeeAddress(), executionFee);

        vars.nodeUnderlyingBalanceAfter = IERC20(underlyingAsset).balanceOf(node);
        if (vars.nodeUnderlyingBalanceAfter <= vars.nodeUnderlyingBalanceBefore) revert ZeroValueSwap();

        emit Compounded(node, incentive, incentiveBalance, nodeCompounded, executionFee);
    }
}
