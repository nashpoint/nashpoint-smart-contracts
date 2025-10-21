// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PolicyBase} from "src/policies/PolicyBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {PolicyLib} from "src/libraries/PolicyLib.sol";

contract TransferPolicy is PolicyBase {
    mapping(address node => mapping(address user => bool whitelisted)) whitelist;

    event WhitelistAdded(address indexed node, address[] users);
    event WhitelistRemoved(address indexed node, address[] users);

    constructor(address registry_) PolicyBase(registry_) {
        actions[IERC20.transfer.selector] = true;
        actions[IERC20.approve.selector] = true;
        actions[IERC20.transferFrom.selector] = true;
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
        if (selector == IERC20.transfer.selector) {
            (address to,) = PolicyLib.decodeTransfer(payload);
            // both caller and receiver should be whitelisted
            _isWhitelisted(caller);
            _isWhitelisted(to);
        } else if (selector == IERC20.approve.selector) {
            (address spender,) = PolicyLib.decodeApprove(payload);
            // both caller and spender should be whitelisted
            _isWhitelisted(caller);
            _isWhitelisted(spender);
        } else if (selector == IERC20.transferFrom.selector) {
            (address from, address to,) = PolicyLib.decodeTransferFrom(payload);
            // caller, owner and receiver should be whitelisted
            _isWhitelisted(caller);
            _isWhitelisted(from);
            _isWhitelisted(to);
        }
    }

    function _isWhitelisted(address user) internal view {
        if (!whitelist[msg.sender][user]) revert ErrorsLib.NotWhitelisted();
    }
}
