// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode, NodeInitArgs, ComponentAllocation} from "./INode.sol";

/**
 * /**
 * @title INodeFactory
 * @author ODND Studios
 */
interface INodeFactory {
    /// @notice Deploys a new node clone with its escrow and initialization payload
    /// @param initArgs Initialization arguments forwarded to the node
    /// @param payload Multicall payload executed post-initialization
    /// @param salt User supplied salt
    /// @return node The deployed node instance
    /// @return escrow Escrow contract created for the node
    function deployFullNode(NodeInitArgs calldata initArgs, bytes[] calldata payload, bytes32 salt)
        external
        returns (INode node, address escrow);
}
