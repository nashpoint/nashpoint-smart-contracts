// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {INodeRegistry} from "../interfaces/INodeRegistry.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

/**
 * @title BaseQuoter
 * @author ODND Studios
 */
contract BaseManager {
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

    /// @dev Reverts if the caller is not the NodeRegistry owner.
    modifier onlyRegistryOwner() {
        if (msg.sender != address(Ownable(address(registry)).owner())) revert ErrorsLib.NotRegistryOwner();
        _;
    }
}
