// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WhitelistBase} from "src/policies/WhitelistBase.sol";
import {PolicyLib} from "src/libraries/PolicyLib.sol";

contract TransferPolicy is WhitelistBase {
    constructor(address registry_) WhitelistBase(registry_) {
        actions[IERC20.transfer.selector] = true;
        actions[IERC20.approve.selector] = true;
        actions[IERC20.transferFrom.selector] = true;
    }

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view override {
        if (selector == IERC20.transfer.selector) {
            (address to,) = PolicyLib.decodeTransfer(payload);
            // both caller and receiver should be whitelisted
            _isWhitelisted(msg.sender, caller);
            _isWhitelisted(msg.sender, to);
        } else if (selector == IERC20.approve.selector) {
            (address spender,) = PolicyLib.decodeApprove(payload);
            // both caller and spender should be whitelisted
            _isWhitelisted(msg.sender, caller);
            _isWhitelisted(msg.sender, spender);
        } else if (selector == IERC20.transferFrom.selector) {
            (address from, address to,) = PolicyLib.decodeTransferFrom(payload);
            // caller, owner and receiver should be whitelisted
            _isWhitelisted(msg.sender, caller);
            _isWhitelisted(msg.sender, from);
            _isWhitelisted(msg.sender, to);
        }
    }
}
