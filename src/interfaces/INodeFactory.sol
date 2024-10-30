// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IEscrow} from "./IEscrow.sol";
import {INode} from "./INode.sol";
import {IQueueManager} from "./IQueueManager.sol";
import {IQuoter} from "./IQuoter.sol";
import {IERC4626Rebalancer} from "./IERC4626Rebalancer.sol";

/**
 * @title INodeFactory
 * @author ODND Studios
 */
interface INodeFactory {
    /// @notice Creates a full Node with Escrow, Manager, Quoter and ERC4626Rebalancer
    /// @param asset The underlying asset address
    /// @param name The ERC20 name of the vault
    /// @param symbol The ERC20 symbol of the vault
    /// @param owner The owner of the node
    /// @param salt The salt to use for CREATE2 deployment
    /// @return node The deployed Node contract
    /// @return escrow The deployed Escrow contract
    /// @return quoter The deployed Quoter contract
    /// @return manager The deployed QueueManager contract
    /// @return erc4626Rebalancer The deployed ERC4626Rebalancer contract
    function deployFullNode(
        address asset,
        string memory name,
        string memory symbol,
        address owner,
        bytes32 salt
    ) external returns (INode node, IEscrow escrow, IQuoter quoter, IQueueManager manager, IERC4626Rebalancer erc4626Rebalancer);

    /// @notice Creates a new ERC4626 rebalancer
    /// @param node Address of the Node contract this rebalancer will serve
    /// @param owner Address that will own the rebalancer
    /// @param salt The salt to use for CREATE2 deployment
    /// @return rebalancer The deployed ERC4626Rebalancer contract
    function createERC4626Rebalancer(
        address node,
        address owner,
        bytes32 salt
    ) external returns (IERC4626Rebalancer rebalancer);

    /// @notice Creates a new escrow contract
    /// @param owner Address that will own the escrow
    /// @param salt The salt to use for CREATE2 deployment
    /// @return escrow The deployed Escrow contract
    function createEscrow(
        address owner,
        bytes32 salt
    ) external returns (IEscrow escrow);

    /// @notice Creates a new node contract
    /// @param asset The underlying asset address
    /// @param name The ERC20 name of the vault
    /// @param symbol The ERC20 symbol of the vault
    /// @param escrow The escrow address
    /// @param manager The manager address
    /// @param owner The owner of the node
    /// @param salt The salt to use for CREATE2 deployment
    /// @return node The deployed Node contract
    function createNode(
        address asset,
        string memory name,
        string memory symbol,
        address escrow,
        address manager,
        address owner,
        bytes32 salt
    ) external returns (INode node);

    /// @notice Creates a new queue manager
    /// @param node Address of the Node contract this manager will serve
    /// @param quoter Address of the Quoter contract
    /// @param owner Address that will own the manager
    /// @param salt The salt to use for CREATE2 deployment
    /// @return manager The deployed QueueManager contract
    function createQueueManager(
        address node,
        address quoter,
        address owner,
        bytes32 salt
    ) external returns (IQueueManager manager);

    /// @notice Creates a new quoter contract
    /// @param node Address of the Node contract this quoter will serve
    /// @param owner Address that will own the quoter
    /// @param salt The salt to use for CREATE2 deployment
    /// @return quoter The deployed Quoter contract
    function createQuoter(
        address node,
        address owner,
        bytes32 salt
    ) external returns (IQuoter quoter);

    /// @notice Checks if an address is a Node created by this factory
    /// @param node Address to check
    /// @return True if the address is a Node created by this factory
    function isNode(address node) external view returns (bool);
}
