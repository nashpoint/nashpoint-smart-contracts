// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode, ComponentAllocation} from "./INode.sol";

/**
 * /**
 * @title INodeFactory
 * @author ODND Studios
 */
interface INodeFactory {
    function deployFullNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        uint64 targetReserveRatio,
        address rebalancer,
        address quoter,
        bytes32 salt
    ) external returns (INode node, address escrow);
}
