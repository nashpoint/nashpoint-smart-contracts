// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./interfaces/INode.sol";
import {Node} from "./Node.sol";
import {INodeFactory} from "./interfaces/INodeFactory.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/**
 * @title NodeFactory
 * @author ODND Studios
 * @notice Factory for creating Nodes and indexing them.
 */
contract NodeFactory is INodeFactory {
    /* STORAGE */

    /// @inheritdoc INodeFactory
    mapping(address => bool) public isNode;

    /* EXTERNAL */

    /// @inheritdoc INodeFactory
    function createNode(
        address asset,
        string memory name,
        string memory symbol,
        address escrow,
        address[] memory rebalancers,
        address owner,
        bytes32 salt
    ) external returns (INode node) {
        node = INode(address(new Node{salt: salt}(asset, name, symbol, escrow, rebalancers, owner)));

        isNode[address(node)] = true;

        emit EventsLib.CreateNode(address(node), asset, name, symbol, rebalancers, owner, salt);
    }
}
