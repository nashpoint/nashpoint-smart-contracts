// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {INode} from "../interfaces/INode.sol";
import {INodeRegistry} from "../interfaces/INodeRegistry.sol";
import {MathLib} from "./MathLib.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

/**
 * @title BaseRouter
 * @author ODND Studios
 */
contract BaseRouter {
    /* IMMUTABLES */
    /// @notice The address of the NodeRegistry
    INodeRegistry public immutable registry;
    uint256 immutable WAD = 1e18;

    /* STORAGE */
    /// @notice Mapping of whitelisted target addresses
    mapping(address => bool) public isWhitelisted;

    /* EVENTS */
    event TargetWhitelisted(address indexed target, bool status);

    /* CONSTRUCTOR */
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* MODIFIERS */
    /// @dev Reverts if the caller is not a rebalancer for the node
    modifier onlyNodeRebalancer(address node) {
        if (!registry.isNode(node)) revert ErrorsLib.InvalidNode();
        if (!INode(node).isRebalancer(msg.sender)) revert ErrorsLib.NotRebalancer();
        _;
    }

    /// @dev Reverts if the caller is not a valid node
    modifier onlyNode() {
        if (!registry.isNode(msg.sender)) revert ErrorsLib.InvalidNode();
        _;
    }

    /// @dev Reverts if the caller is not the registry owner
    modifier onlyRegistryOwner() {
        if (msg.sender != Ownable(address(registry)).owner()) revert ErrorsLib.NotRegistryOwner();
        _;
    }

    /// @dev Reverts if the target is not whitelisted
    modifier onlyWhitelisted(address target) {
        if (!isWhitelisted[target]) revert ErrorsLib.NotWhitelisted();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         REGISTRY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the whitelist status of a target
    /// @param target The address to update
    /// @param status The new whitelist status
    function setWhitelistStatus(address target, bool status) external onlyRegistryOwner {
        if (target == address(0)) revert ErrorsLib.ZeroAddress();
        isWhitelisted[target] = status;
        emit TargetWhitelisted(target, status);
    }

    /// @notice Batch updates whitelist status of targets
    /// @param targets Array of addresses to update
    /// @param statuses Array of whitelist statuses
    function batchSetWhitelistStatus(address[] calldata targets, bool[] calldata statuses) external onlyRegistryOwner {
        if (targets.length != statuses.length) revert ErrorsLib.LengthMismatch();

        uint256 length = targets.length;
        for (uint256 i = 0; i < length;) {
            if (targets[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isWhitelisted[targets[i]] = statuses[i];
            emit TargetWhitelisted(targets[i], statuses[i]);
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    VIRTUAL / OVERRIDABLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the investment size for a component.
    /// @dev This function is virtual and should be overridden by the router implementation
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAssets The amount of assets to deposit.
    function _getInvestmentSize(address node, address component)
        internal
        view
        virtual
        returns (uint256 depositAssets)
    {}

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates that the reserve is above the target ratio.
    /// @param node The address of the node.
    function _validateReserveAboveTargetRatio(address node) internal view {
        uint256 totalAssets_ = INode(node).totalAssets();
        uint256 idealCashReserve = MathLib.mulDiv(totalAssets_, INode(node).targetReserveRatio(), WAD);
        uint256 currentCash = IERC20(INode(node).asset()).balanceOf(address(node))
            - INode(node).convertToAssets(INode(node).getSharesExiting());

        // checks if available reserve exceeds target ratio
        if (currentCash < idealCashReserve) {
            revert ErrorsLib.ReserveBelowTargetRatio();
        }
    }

    /// @notice Validates that the node accepts the router.
    /// @param node The address of the node.
    function _validateNodeAcceptsRouter(address node) internal view {
        if (!INode(node).isRouter(address(this))) {
            revert ErrorsLib.NotRouter();
        }
    }

    /// @notice Returns the node's cash status.
    /// @param node The address of the node.
    /// @return totalAssets The total assets of the node.
    /// @return currentCash The current cash of the node.
    /// @return idealCashReserve The ideal cash reserve of the node.
    function _getNodeCashStatus(address node)
        internal
        view
        returns (uint256 totalAssets, uint256 currentCash, uint256 idealCashReserve)
    {
        totalAssets = INode(node).totalAssets();
        currentCash = IERC20(INode(node).asset()).balanceOf(address(node))
            - INode(node).convertToAssets(INode(node).getSharesExiting());
        idealCashReserve = MathLib.mulDiv(totalAssets, INode(node).targetReserveRatio(), WAD);
    }

    /// @notice Subtracts the execution fee from the transaction amount.
    /// @dev This calls transfer function on the node's asset to subtract the fee
    ///      and send to protocol fee recipient address
    /// @param transactionAmount The amount of the transaction.
    /// @param node The address of the node.
    /// @return transactionAfterFee The amount of the transaction after the fee is subtracted.
    function _subtractExecutionFee(uint256 transactionAmount, address node) internal returns (uint256) {
        uint256 executionFee = transactionAmount * registry.protocolExecutionFee() / WAD;
        if (executionFee == 0) {
            return transactionAmount;
        }

        if (executionFee >= transactionAmount) {
            revert ErrorsLib.FeeExceedsAmount(executionFee, transactionAmount);
        }

        uint256 transactionAfterFee = transactionAmount - executionFee;
        INode(node).subtractProtocolExecutionFee(executionFee);

        return transactionAfterFee;
    }

    /// @dev Transfers assets to the escrow.
    /// @param node The address of the node.
    /// @param assetsToReturn The amount of assets to return.
    function _transferToEscrow(address node, uint256 assetsToReturn) internal {
        bytes memory transferCallData =
            abi.encodeWithSelector(IERC20.transfer.selector, INode(node).escrow(), assetsToReturn);
        INode(node).execute(INode(node).asset(), 0, transferCallData);
    }

    /// @dev Enforces the liquidation queue.
    /// @param component The address of the component.
    /// @param assetsToReturn The amount of assets to return.
    /// @param liquidationsQueue The liquidation queue.
    function _enforceLiquidationQueue(address component, uint256 assetsToReturn, address[] memory liquidationsQueue)
        internal
        view
    {
        for (uint256 i = 0; i < liquidationsQueue.length; i++) {
            address candidate = liquidationsQueue[i];
            uint256 candidateShares = IERC20(candidate).balanceOf(address(this));
            uint256 candidateAssets = IERC4626(candidate).convertToAssets(candidateShares);

            if (candidateAssets >= assetsToReturn) {
                if (candidate != component) {
                    revert ErrorsLib.IncorrectLiquidationOrder(component, assetsToReturn);
                }
                break;
            }
        }
    }

    function _approve(address node, address token, address spender, uint256 amount) internal {
        INode(node).execute(token, 0, abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
    }
}
