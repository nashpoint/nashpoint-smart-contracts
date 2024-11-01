// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IEscrow} from "./IEscrow.sol";
import {INode} from "./INode.sol";
import {IQueueManager} from "./IQueueManager.sol";

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
    /// @param rebalancer The initial rebalancer address
    /// @param quoter The quoter address
    /// @param routers Array of initial router addresses
    /// @param salt The salt to use for CREATE2 deployment
    /// @return node The deployed Node contract
    /// @return escrow The deployed Escrow contract
    /// @return manager The deployed QueueManager contract
    function deployFullNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address rebalancer,
        address quoter,
        address[] memory routers,
        bytes32 salt
    ) external returns (INode node, IEscrow escrow, IQueueManager manager);

    /// @notice Creates a new node contract
    /// @param name The ERC20 name of the vault
    /// @param symbol The ERC20 symbol of the vault
    /// @param asset The underlying asset address
    /// @param owner The owner of the node
    /// @param rebalancer The initial rebalancer address
    /// @param quoter The quoter address
    /// @param routers Array of initial router addresses
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
        bytes32 salt
    ) external returns (INode node);
}
