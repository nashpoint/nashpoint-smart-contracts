// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {INode} from "../interfaces/INode.sol";
import {INodeRegistry} from "../interfaces/INodeRegistry.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

/**
 * @title RegistryAccessControl
 * @author ODND Studios
 */
abstract contract RegistryAccessControl {
    /* IMMUTABLES */
    /// @notice The address of the NodeRegistry
    INodeRegistry public immutable registry;

    /* CONSTRUCTOR */
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* MODIFIERS */
    /// @dev Reverts if the caller is not a rebalancer for the node
    modifier onlyNodeRebalancer(address node) {
        if (!registry.isNode(node)) revert ErrorsLib.InvalidNode();
        if (!INode(node).isRebalancer(msg.sender)) revert ErrorsLib.NotRebalancer();
        _;
    }

    /// @dev Reverts if the caller is not a valid node
    modifier onlyNode() {
        if (!registry.isNode(msg.sender)) revert ErrorsLib.InvalidNode();
        _;
    }

    /// @dev Reverts if the caller is not the registry owner
    modifier onlyRegistryOwner() {
        if (msg.sender != Ownable(address(registry)).owner()) revert ErrorsLib.NotRegistryOwner();
        _;
    }

    /// @dev Reverts if the component is not a valid component on the node
    modifier onlyNodeComponent(address node, address component) {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }
        _;
    }
}
