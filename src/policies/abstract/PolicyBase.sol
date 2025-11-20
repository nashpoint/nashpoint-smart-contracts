// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {INode} from "src/interfaces/INode.sol";
import {IPolicy} from "src/interfaces/IPolicy.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

/**
 * @title PolicyBase
 * @notice Common access control and action dispatching for node policies
 */
abstract contract PolicyBase is IPolicy {
    /// @notice Registry that tracks nodes and protocol ownership
    INodeRegistry public immutable registry;
    /// @notice Mapping of function selectors permitted to be executed through the policy
    mapping(bytes4 sig => bool allowed) public actions;

    /// @param registry_ Address of the shared node registry dependency
    constructor(address registry_) {
        registry = INodeRegistry(registry_);
    }

    /// @notice Restricts function to the owner of the protocol
    modifier onlyRegistryOwner() {
        _onlyRegistryOwner();
        _;
    }

    /// @notice Restricts function to the owner of the provided node
    /// @param node Node address whose owner must be the caller
    modifier onlyNodeOwner(address node) {
        _onlyNode(node);
        _onlyNodeOwner(node);
        _;
    }

    /// @notice Restricts function to registered nodes
    /// @param node Address that must be recognized as a node
    modifier onlyNode(address node) {
        _onlyNode(node);
        _;
    }

    /// @inheritdoc IPolicy
    function onCheck(address caller, bytes calldata data) external view onlyNode(msg.sender) {
        (bytes4 selector, bytes calldata payload) = _extract(data);
        _allowedAction(selector);
        _executeCheck(msg.sender, caller, selector, payload);
    }

    /// @inheritdoc IPolicy
    function receiveUserData(address caller, bytes calldata data) external onlyNode(msg.sender) {
        _processCallerData(caller, data);
    }

    /// @notice Hook executed by inheriting policies to enforce custom logic
    /// @param node Node invoking the action
    /// @param caller Original caller whose action is being checked
    /// @param selector Function selector authorized via `actions`
    /// @param payload Call data minus the selector
    function _executeCheck(address node, address caller, bytes4 selector, bytes calldata payload)
        internal
        view
        virtual;

    /// @notice Optional hook for policies that need extra information from callers
    /// @dev Base implementation reverts; override in derived contracts as needed
    /// @param caller User providing the additional data
    /// @param data Abi-encoded payload specific to the policy
    function _processCallerData(address caller, bytes calldata data) internal virtual {
        revert ErrorsLib.Forbidden();
    }

    /// @notice Reverts unless the address is a registered node
    /// @param node Address being validated
    function _onlyNode(address node) internal view {
        if (!registry.isNode(node)) revert ErrorsLib.NotRegistered();
    }

    /// @notice Reverts unless `msg.sender` owns the given node
    /// @param node Node whose ownership is being confirmed
    function _onlyNodeOwner(address node) internal view {
        if (Ownable(node).owner() != msg.sender) revert ErrorsLib.NotNodeOwner();
    }

    /// @notice Reverts unless `msg.sender` owns the registry
    function _onlyRegistryOwner() internal view {
        if (Ownable(address(registry)).owner() != msg.sender) revert ErrorsLib.NotRegistryOwner();
    }

    /// @notice Splits call data into selector and payload to ease policy checks
    /// @param data ABI-encoded function selector plus arguments
    /// @return selector Function selector (first 4 bytes)
    /// @return payload Remaining calldata bytes
    function _extract(bytes calldata data) internal pure returns (bytes4 selector, bytes calldata payload) {
        assembly {
            selector := calldataload(data.offset)
            payload.offset := add(data.offset, 4)
            payload.length := sub(data.length, 4)
        }
    }

    /// @notice Reverts if the selector is not marked as allowed
    /// @param selector Function selector being invoked
    function _allowedAction(bytes4 selector) internal view {
        if (!actions[selector]) revert ErrorsLib.NotAllowedAction(selector);
    }
}
