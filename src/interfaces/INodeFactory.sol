// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode, NodeInitArgs} from "./INode.sol";

/// @notice Arbitrary call executed during factory deployment flows
struct SetupCall {
    address target;
    bytes payload;
}

/**
 * /**
 * @title INodeFactory
 * @author ODND Studios
 */
interface INodeFactory {
    /// @notice Deploys a new node clone with its escrow and initialization payload
    /// @param initArgs Initialization arguments forwarded to the node
    /// @param nodePayload Multicall payload executed post-initialization on Node
    /// @param setupCalls Additional call data executed by the factory
    /// @param salt User supplied salt
    /// @return node The deployed node instance
    /// @return escrow Escrow contract created for the node
    function deployFullNode(
        NodeInitArgs calldata initArgs,
        bytes[] calldata nodePayload,
        SetupCall[] calldata setupCalls,
        bytes32 salt
    ) external returns (INode node, address escrow);

    /// @notice Predicts the address of a node deployed via `deployFullNode`
    /// @param salt User supplied salt used during deployment
    /// @param deployer Address that will call `deployFullNode`
    /// @return predicted Address where the node clone will be deployed
    function predictDeterministicAddress(bytes32 salt, address deployer) external view returns (address predicted);
}
