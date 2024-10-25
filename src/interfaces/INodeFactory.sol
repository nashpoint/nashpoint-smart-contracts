// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./INode.sol";

/**
 * @title INode
 * @author ODND Studios
 */
interface INodeFactory {
    /// @notice Whether a Node was created with the factory.
    function isNode(address node) external view returns (bool);

    /// @notice Creates a new node.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param escrow The address of the escrow.
    /// @param rebalancers The addresses of the rebalancers.
    /// @param owner The owner of the contract.
    /// @param salt The salt to use for the Node's CREATE2 address.
    function createNode(
        address asset,
        string memory name,
        string memory symbol,
        address escrow,
        address[] memory rebalancers,
        address owner,
        bytes32 salt
    ) external returns (INode node);
}
