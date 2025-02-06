// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode, ComponentAllocation} from "./INode.sol";

struct DeployParams {
    string name;
    string symbol;
    address asset;
    address owner;
    address rebalancer;
    address quoter;
    address[] routers;
    address[] components;
    ComponentAllocation[] componentAllocations;
    uint64 targetReserveRatio;
    bytes32 salt;
}

/**
 * /**
 * @title INodeFactory
 * @author ODND Studios
 */
interface INodeFactory {
    /// @notice Creates a full Node setup with Escrow and QueueManager
    /// @param params The deployment parameters
    /// @return node The deployed Node contract
    /// @return escrow The deployed Escrow contract
    function deployFullNode(DeployParams memory params) external returns (INode node, address escrow);

    /// @notice Creates a Node
    /// @param name The name of the Node
    /// @param symbol The symbol of the Node
    /// @param asset The asset of the Node
    /// @param owner The owner of the Node
    /// @param routers The routers of the Node
    /// @param components The components of the Node
    /// @param componentAllocations The component allocations of the Node
    /// @param targetReserveRatio The target reserve ratio of the Node
    /// @param salt The salt for the Node
    /// @return node The deployed Node contract
    function createNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        uint64 targetReserveRatio,
        bytes32 salt
    ) external returns (INode node);
}
