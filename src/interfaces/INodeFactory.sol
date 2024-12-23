// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IEscrow} from "./IEscrow.sol";
import {INode, ComponentAllocation} from "./INode.sol";

/**
 * @title INodeFactory
 * @author ODND Studios
 */
interface INodeFactory {
    /// @notice Creates a full Node setup with Escrow and QueueManager
    /// @param name The ERC20 name of the vault
    /// @param symbol The ERC20 symbol of the vault
    /// @param asset The underlying asset address
    /// @param owner The owner of the node
    /// @param rebalancer The rebalancer address
    /// @param quoter The quoter address
    /// @param routers Array of initial router addresses
    /// @param components Array of initial component addresses
    /// @param componentAllocations Array of initial component allocations
    /// @param reserveAllocation The initial reserve allocation
    /// @param salt The salt to use for CREATE2 deployment
    /// @return node The deployed Node contract
    /// @return escrow The deployed Escrow contract
    function deployFullNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address rebalancer,
        address quoter,
        address pricer,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        ComponentAllocation memory reserveAllocation,
        bytes32 salt
    ) external returns (INode node, IEscrow escrow);

    /// @notice Creates a new node contract
    /// @param name The ERC20 name of the vault
    /// @param symbol The ERC20 symbol of the vault
    /// @param asset The underlying asset address
    /// @param owner The owner of the node
    /// @param rebalancer The rebalancer address
    /// @param quoter The quoter address
    /// @param routers Array of initial router addresses
    /// @param components Array of initial component addresses
    /// @param componentAllocations Array of initial component allocations
    /// @param reserveAllocation The initial reserve allocation
    /// @param salt The salt to use for CREATE2 deployment
    /// @return node The deployed Node contract
    function createNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address rebalancer,
        address quoter,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        ComponentAllocation memory reserveAllocation,
        bytes32 salt
    ) external returns (INode node);
}
