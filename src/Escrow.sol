// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {INode} from "./interfaces/INode.sol";
import {IEscrow} from "./interfaces/IEscrow.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title  Escrow
/// @notice Escrow contract that holds tokens for pending Node withdrawals
contract Escrow is IEscrow {
    /* IMMUTABLES */
    /// @notice The Node contract this escrow serves
    INode public immutable node;

    /* CONSTRUCTOR */
    constructor(address node_) {
        if (node_ == address(0)) revert ErrorsLib.ZeroAddress();
        node = INode(node_);
    }

    /* MODIFIERS */
    modifier onlyNodeOwner() {
        if (msg.sender != Ownable(address(node)).owner()) revert ErrorsLib.NotNodeOwner();
        _;
    }

    /* TOKEN APPROVALS */
    /// @inheritdoc IEscrow
    function approveMax(address token, address spender) external onlyNodeOwner {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            _safeApprove(token, spender, type(uint256).max);
            emit EventsLib.Approve(token, spender, type(uint256).max);
        }
    }

    /// @inheritdoc IEscrow
    function unapprove(address token, address spender) external onlyNodeOwner {
        _safeApprove(token, spender, 0);
        emit EventsLib.Approve(token, spender, 0);
    }

    /* INTERNAL FUNCTIONS */
    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.approve, (spender, amount)));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert ErrorsLib.SafeApproveFailed();
    }
}
