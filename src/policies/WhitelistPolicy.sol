// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PolicyBase} from "src/policies/PolicyBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {PolicyLib} from "src/libraries/PolicyLib.sol";

import {INode} from "src/interfaces/INode.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

contract WhitelistPolicy is PolicyBase {
    mapping(address node => mapping(address user => bool whitelisted)) whitelist;

    event WhitelistAdded(address indexed node, address[] users);
    event WhitelistRemoved(address indexed node, address[] users);

    constructor(address registry_) PolicyBase(registry_) {
        actions[IERC7575.deposit.selector] = true;
        actions[IERC7575.mint.selector] = true;
        actions[INode.requestRedeem.selector] = true;
        // we don't care who will withdraw/redeem
    }

    function add(address node, address[] calldata users) external onlyNodeOwner(node) {
        for (uint256 i; i < users.length; i++) {
            whitelist[node][users[i]] = true;
        }
        emit WhitelistAdded(node, users);
    }

    function remove(address node, address[] calldata users) external onlyNodeOwner(node) {
        for (uint256 i; i < users.length; i++) {
            whitelist[node][users[i]] = false;
        }
        emit WhitelistRemoved(node, users);
    }

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view override {
        if (selector == IERC7575.deposit.selector) {
            (, address receiver) = PolicyLib.decodeDeposit(payload);
            // both caller and receiver should be whitelisted
            _isWhitelisted(caller);
            _isWhitelisted(receiver);
        } else if (selector == IERC7575.mint.selector) {
            (, address receiver) = PolicyLib.decodeMint(payload);
            // both caller and receiver should be whitelisted
            _isWhitelisted(caller);
            _isWhitelisted(receiver);
        } else if (selector == INode.requestRedeem.selector) {
            (,, address owner) = PolicyLib.decodeRequestRedeem(payload);
            // only owner of shares should be whitelisted
            // it might have provided operator role to someone
            _isWhitelisted(owner);
        }
    }

    function _isWhitelisted(address user) internal view {
        if (!whitelist[msg.sender][user]) revert ErrorsLib.NotWhitelisted();
    }
}
