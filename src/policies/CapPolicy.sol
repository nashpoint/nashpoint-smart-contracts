// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PolicyBase} from "src/policies/PolicyBase.sol";

import {INode} from "src/interfaces/INode.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

contract CapPolicy is PolicyBase {
    mapping(address node => uint256 cap) nodeCap;

    event CapChange(address indexed node, uint256 amount);

    error CapExceeded(uint256 byAmount);

    constructor(address registry_) PolicyBase(registry_) {
        actions[IERC7575.deposit.selector] = true;
        actions[IERC7575.mint.selector] = true;
    }

    function setCap(address node, uint256 amount) external onlyNodeOwner(node) {
        nodeCap[node] = amount;
        emit CapChange(node, amount);
    }

    function _executeCheck(bytes4 selector, bytes calldata payload) internal view override {
        uint256 cap = nodeCap[msg.sender];
        if (cap > 0) {
            uint256 totalAssets = INode(msg.sender).totalAssets();
            if (totalAssets > cap) revert CapExceeded(totalAssets - cap);
        }
    }
}
