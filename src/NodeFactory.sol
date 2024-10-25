// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./interfaces/INode.sol";
import {Node} from "./Node.sol";
import {Escrow} from "./Escrow.sol";
import {ERC4626Rebalancer} from "./rebalancers/ERC4626Rebalancer.sol";
import {INodeFactory} from "./interfaces/INodeFactory.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
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
        address owner,
        bytes32 salt
    ) external returns (INode node) {
        if (asset == address(0)) revert ErrorsLib.ZeroAddress();
        if (bytes(name).length == 0) revert ErrorsLib.InvalidName();
        if (bytes(symbol).length == 0) revert ErrorsLib.InvalidSymbol();
        if (owner == address(0)) revert ErrorsLib.ZeroAddress();

        node = INode(address(new Node{salt: salt}(asset, name, symbol, address(0), new address[](0), owner)));

        isNode[address(node)] = true;

        emit EventsLib.CreateNode(address(node), asset, name, symbol, owner, salt);
    }

    function createEscrow(address owner, bytes32 salt) external returns (Escrow escrow) {
        escrow = Escrow(address(new Escrow{salt: salt}(owner)));
    }

    function createERC4626Rebalancer(address node, address owner, bytes32 salt) external returns (ERC4626Rebalancer rebalancer) {
        rebalancer = ERC4626Rebalancer(address(new ERC4626Rebalancer{salt: salt}(node, owner)));
    }
}
