// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IBaseRouter} from "../interfaces/IBaseRouter.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {INode} from "../interfaces/INode.sol";
import {INodeRegistry} from "../interfaces/INodeRegistry.sol";
import {MathLib} from "./MathLib.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

/**
 * @title BaseRouter
 * @author ODND Studios
 */
contract BaseRouter is IBaseRouter {
    /* IMMUTABLES */
    /// @notice The address of the NodeRegistry
    INodeRegistry public immutable registry;
    uint256 immutable WAD = 1e18;

    /* STORAGE */
    /// @notice Mapping of whitelisted target addresses
    mapping(address => bool) public isWhitelisted;

    /* EVENTS */
    event TargetWhitelisted(address indexed target, bool status);

    /* ERRORS */

    /* CONSTRUCTOR */
    /// @dev Initializes the contract
    /// @param registry_ The address of the NodeRegistry

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

    /* REGISTRY OWNER FUNCTIONS */
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

    /* APPROVALS */
    /// @inheritdoc IBaseRouter
    function approve(address node, address token, address spender, uint256 amount)
        external
        onlyNodeRebalancer(node)
        onlyWhitelisted(spender)
    {
        INode(node).execute(token, 0, abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
    }

    function _getInvestmentSize(address node, address component)
        internal
        view
        virtual
        returns (uint256 depositAssets)
    {}

    function _validateReserveAboveTargetRatio(address node) internal view {
        uint256 totalAssets_ = INode(node).totalAssets();
        uint256 idealCashReserve = MathLib.mulDiv(totalAssets_, INode(node).targetReserveRatio(), WAD);
        uint256 currentCash = IERC20(INode(node).asset()).balanceOf(address(node));

        // checks if available reserve exceeds target ratio
        if (currentCash < idealCashReserve) {
            revert ErrorsLib.ReserveBelowTargetRatio();
        }
    }

    function _validateNodeUsesRouter(address node) internal view {
        if (!INode(node).isRouter(address(this))) {
            revert ErrorsLib.NotRouter();
        }
    }

    function _getNodeCashStatus(address node)
        internal
        view
        returns (uint256 totalAssets, uint256 currentCash, uint256 idealCashReserve)
    {
        totalAssets = INode(node).totalAssets();
        currentCash = IERC20(INode(node).asset()).balanceOf(address(node))
            - INode(node).convertToAssets(INode(node).sharesExiting());
        idealCashReserve = MathLib.mulDiv(totalAssets, INode(node).targetReserveRatio(), WAD);
    }
}
