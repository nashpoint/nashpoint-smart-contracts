// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IEscrow} from "./IEscrow.sol";
import {INode, ComponentAllocation} from "./INode.sol";

struct DeployParams {
    string name;
    string symbol;
    address asset;
    address owner;
    address rebalancer;
    address quoter;
    address pricer;
    address[] routers;
    address[] components;
    ComponentAllocation[] componentAllocations;
    ComponentAllocation reserveAllocation;
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
    function deployFullNode(DeployParams memory params) external returns (INode node, IEscrow escrow);

    function createNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        ComponentAllocation memory reserveAllocation,
        bytes32 salt
    ) external returns (INode node);
}
