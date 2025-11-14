// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode} from "src/interfaces/INode.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

import {PolicyBase} from "src/policies/abstract/PolicyBase.sol";

/**
 * @title CapPolicy
 * @notice Enforces a maximum total asset cap per node
 */
contract CapPolicy is PolicyBase {
    mapping(address node => uint256 cap) public nodeCap;

    event CapChange(address indexed node, uint256 amount);

    error CapExceeded(uint256 byAmount);

    constructor(address registry_) PolicyBase(registry_) {
        actions[IERC7575.deposit.selector] = true;
        actions[IERC7575.mint.selector] = true;
    }

    /// @notice Updates the maximum total assets allowed for a node
    /// @param node Node contract to configure
    /// @param amount Maximum total assets allowed; zero disables the cap
    function setCap(address node, uint256 amount) external onlyNodeOwner(node) {
        nodeCap[node] = amount;
        emit CapChange(node, amount);
    }

    function _executeCheck(address node, address caller, bytes4 selector, bytes calldata payload)
        internal
        view
        override
    {
        uint256 cap = nodeCap[node];
        if (cap > 0) {
            uint256 totalAssets = INode(node).totalAssets();
            if (totalAssets > cap) revert CapExceeded(totalAssets - cap);
        }
    }
}
