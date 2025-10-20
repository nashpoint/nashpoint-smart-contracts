// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode, NodeInitArgs} from "./INode.sol";

/**
 * /**
 * @title INodeFactory
 * @author ODND Studios
 */
interface INodeFactory {
    function deployFullNode(NodeInitArgs memory initArgs, bytes32 salt) external returns (INode node, address escrow);
}
