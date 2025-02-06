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
}
