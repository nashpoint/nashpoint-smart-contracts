// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IBaseRouter} from "../interfaces/IBaseRouter.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {INode} from "../interfaces/INode.sol";
import {INodeRegistry} from "../interfaces/INodeRegistry.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

/**
 * @title BaseRouter
 * @author ODND Studios
 */
contract BaseRouter is IBaseRouter {
    /* IMMUTABLES */
    /// @notice The address of the NodeRegistry.
    INodeRegistry public immutable registry;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param registry_ The address of the NodeRegistry.
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not a rebalancer for the node
    modifier onlyNodeRebalancer(address node) {
        if (msg.sender != INode(node).rebalancer()) revert ErrorsLib.NotRebalancer();
        _;
    }

    /* APPROVALS */

    /// @inheritdoc IBaseRouter
    function approve(
        address node,
        address token,
        address spender,
        uint256 amount
    ) external onlyNodeRebalancer(node) {
        INode(node).execute(token, 0, abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
    }
}
