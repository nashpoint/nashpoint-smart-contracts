// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {WhitelistBase} from "src/policies/WhitelistBase.sol";
import {PolicyLib} from "src/libraries/PolicyLib.sol";

import {INode} from "src/interfaces/INode.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

contract GatePolicy is WhitelistBase {
    constructor(address registry_) WhitelistBase(registry_) {
        actions[IERC7575.deposit.selector] = true;
        actions[IERC7575.mint.selector] = true;
        actions[INode.requestRedeem.selector] = true;
        // we don't care who will withdraw/redeem
    }

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view override {
        if (selector == IERC7575.deposit.selector) {
            (, address receiver) = PolicyLib.decodeDeposit(payload);
            // both caller and receiver should be whitelisted
            _isWhitelisted(msg.sender, caller);
            _isWhitelisted(msg.sender, receiver);
        } else if (selector == IERC7575.mint.selector) {
            (, address receiver) = PolicyLib.decodeMint(payload);
            // both caller and receiver should be whitelisted
            _isWhitelisted(msg.sender, caller);
            _isWhitelisted(msg.sender, receiver);
        } else if (selector == INode.requestRedeem.selector) {
            (,, address owner) = PolicyLib.decodeRequestRedeem(payload);
            // only owner of shares should be whitelisted
            // it might have provided operator role to someone
            _isWhitelisted(msg.sender, owner);
        }
    }
}
