// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {INodeRegistry} from "../interfaces/INodeRegistry.sol";
import {INode} from "../interfaces/INode.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

/**
 * @title BaseQuoter
 * @author ODND Studios
 */
abstract contract BaseQuoter {
    /* IMMUTABLES */
    /// @notice The address of the NodeRegistry.
    INodeRegistry public immutable registry;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param registry_ The address of the NodeRegistry.
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not a valid node.
    modifier onlyValidNode(address node) {
        if (!registry.isNode(node)) revert ErrorsLib.NotRegistered();
        _;
    }

    /// @dev Reverts if the caller is not a valid quoter.
    modifier onlyValidQuoter(address node) {
        if (address(INode(node).quoter()) != address(this)) revert ErrorsLib.InvalidQuoter();
        _;
    }

    /// @dev Reverts if the caller is not the NodeRegistry owner.
    modifier onlyRegistryOwner() {
        if (msg.sender != Ownable(address(registry)).owner()) revert ErrorsLib.NotRegistryOwner();
        _;
    }
}
