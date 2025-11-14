// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ListBase} from "src/policies/abstract/ListBase.sol";
import {PolicyLib} from "src/libraries/PolicyLib.sol";

import {INode} from "src/interfaces/INode.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

abstract contract GatePolicyBase is ListBase {
    constructor(address registry_) ListBase(registry_) {
        actions[IERC7575.deposit.selector] = true;
        actions[IERC7575.mint.selector] = true;
        actions[INode.setOperator.selector] = true;
        actions[INode.requestRedeem.selector] = true;
        actions[IERC7575.withdraw.selector] = true;
        actions[IERC7575.redeem.selector] = true;
        actions[IERC20.transfer.selector] = true;
        actions[IERC20.approve.selector] = true;
        actions[IERC20.transferFrom.selector] = true;
    }

    function _executeCheck(address node, address caller, bytes4 selector, bytes calldata payload)
        internal
        view
        override
    {
        if (selector == IERC7575.deposit.selector) {
            (, address receiver) = PolicyLib.decodeDeposit(payload);
            _actorCheck(node, caller);
            _actorCheck(node, receiver);
        } else if (selector == IERC7575.mint.selector) {
            (, address receiver) = PolicyLib.decodeMint(payload);
            _actorCheck(node, caller);
            _actorCheck(node, receiver);
        } else if (selector == INode.requestRedeem.selector) {
            (, address controller, address owner) = PolicyLib.decodeRequestRedeem(payload);
            _actorCheck(node, caller);
            _actorCheck(node, controller);
            _actorCheck(node, owner);
        } else if (selector == INode.setOperator.selector) {
            (address operator,) = PolicyLib.decodeSetOperator(payload);
            _actorCheck(node, caller);
            _actorCheck(node, operator);
        } else if (selector == IERC7575.redeem.selector) {
            (, address receiver, address controller) = PolicyLib.decodeRedeem(payload);
            _actorCheck(node, caller);
            _actorCheck(node, receiver);
            _actorCheck(node, controller);
        } else if (selector == IERC7575.withdraw.selector) {
            (, address receiver, address controller) = PolicyLib.decodeWithdraw(payload);
            _actorCheck(node, caller);
            _actorCheck(node, receiver);
            _actorCheck(node, controller);
        } else if (selector == IERC20.transfer.selector) {
            (address to,) = PolicyLib.decodeTransfer(payload);
            _actorCheck(node, caller);
            _actorCheck(node, to);
        } else if (selector == IERC20.approve.selector) {
            (address spender,) = PolicyLib.decodeApprove(payload);
            _actorCheck(node, caller);
            _actorCheck(node, spender);
        } else if (selector == IERC20.transferFrom.selector) {
            (address from, address to,) = PolicyLib.decodeTransferFrom(payload);
            _actorCheck(node, caller);
            _actorCheck(node, from);
            _actorCheck(node, to);
        }
    }

    function _actorCheck(address node, address actor) internal view virtual;
}
