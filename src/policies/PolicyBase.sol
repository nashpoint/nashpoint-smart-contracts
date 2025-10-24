// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {INode} from "src/interfaces/INode.sol";
import {IPolicy} from "src/interfaces/IPolicy.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

abstract contract PolicyBase is IPolicy {
    INodeRegistry public immutable registry;
    mapping(bytes4 sig => bool allowed) public actions;

    constructor(address registry_) {
        registry = INodeRegistry(registry_);
    }

    modifier onlyRegistryOwner() {
        _onlyRegistryOwner();
        _;
    }

    modifier onlyNodeOwner(address node) {
        _onlyNode(node);
        _onlyNodeOwner(node);
        _;
    }

    modifier onlyNode(address node) {
        _onlyNode(node);
        _;
    }

    function onCheck(address caller, bytes calldata data) external view onlyNode(msg.sender) {
        (bytes4 selector, bytes calldata payload) = _extract(data);
        _allowedAction(selector);
        _executeCheck(caller, selector, payload);
    }

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view virtual;

    function _onlyNode(address node) internal view {
        if (!registry.isNode(node)) revert ErrorsLib.NotRegistered();
    }

    function _onlyNodeOwner(address node) internal view {
        if (Ownable(node).owner() != msg.sender) revert ErrorsLib.NotNodeOwner();
    }

    function _onlyRegistryOwner() internal view {
        if (Ownable(address(registry)).owner() != msg.sender) revert ErrorsLib.NotRegistryOwner();
    }

    function _extract(bytes calldata data) internal pure returns (bytes4 selector, bytes calldata payload) {
        assembly {
            selector := calldataload(data.offset)
            payload.offset := add(data.offset, 4)
            payload.length := sub(data.length, 4)
        }
    }

    function _allowedAction(bytes4 selector) internal view {
        if (!actions[selector]) revert ErrorsLib.NotAllowedAction(selector);
    }
}
