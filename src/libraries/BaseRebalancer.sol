// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {INode} from "../interfaces/INode.sol";
import {ErrorsLib} from "./ErrorsLib.sol";
import {EventsLib} from "./EventsLib.sol";

/**
 * @title BaseRebalancer
 * @author ODND Studios
 */
contract BaseRebalancer is Ownable {
    /* IMMUTABLES */

    /// @notice The address of the node.
    INode public immutable node;

    /* STORAGE */

    /// @notice The addresses of the operators.
    mapping(address => bool) public isOperator;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param node_ The address of the node.
    constructor(
        address node_,
        address owner
    ) Ownable(owner) {
        node = INode(node_);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not an operator or the owner.
    modifier onlyOperator() {
        if (!isOperator[msg.sender] && msg.sender != owner()) revert ErrorsLib.NotOperator();
        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @notice Adds an operator.
    /// @param operator The address of the operator.
    function addOperator(address operator) external onlyOwner {
        isOperator[operator] = true;
        emit EventsLib.AddOperator(operator);
    }

    /// @notice Removes an operator.
    /// @param operator The address of the operator.
    function removeOperator(address operator) external onlyOwner {
        isOperator[operator] = false;
        emit EventsLib.RemoveOperator(operator);
    }

    /* APPROVALS */

    /// @notice approves a tokens spending limit via the Node.execute function.
    /// @param token The address of the token.
    /// @param spender The address of the spender.
    /// @param amount The amount to approve.
    function approve(address token, address spender, uint256 amount) external onlyOperator {
        node.execute(token, 0, abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
    }
}
