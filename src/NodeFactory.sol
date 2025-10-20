// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Escrow} from "./Escrow.sol";
import {NodeInitArgs} from "./Node.sol";
import {INode, ComponentAllocation} from "./interfaces/INode.sol";
import {INodeFactory} from "./interfaces/INodeFactory.sol";
import {INodeRegistry} from "./interfaces/INodeRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/// @title NodeFactory
/// @author ODND Studios
contract NodeFactory is INodeFactory {
    /* IMMUTABLES */
    INodeRegistry public immutable registry;
    address public immutable nodeImplementation;

    /* ERRORS */
    error ZeroAddress();
    error InvalidName();
    error InvalidSymbol();
    error LengthMismatch();

    /* EVENTS */
    event NodeCreated(address indexed node, address indexed asset, string name, string symbol, address indexed owner);

    /* CONSTRUCTOR */
    constructor(address registry_, address nodeImplementation_) {
        if (registry_ == address(0) || nodeImplementation_ == address(0)) revert ZeroAddress();
        registry = INodeRegistry(registry_);
        nodeImplementation = nodeImplementation_;
    }

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc INodeFactory
    function deployFullNode(NodeInitArgs memory initArgs, bytes32 salt) external returns (INode node, address escrow) {
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        if (initArgs.asset == address(0) || initArgs.owner == address(0)) {
            revert ZeroAddress();
        }
        if (bytes(initArgs.name).length == 0) revert InvalidName();
        if (bytes(initArgs.symbol).length == 0) revert InvalidSymbol();
        if (initArgs.components.length != initArgs.componentAllocations.length) revert LengthMismatch();

        node = INode(Clones.cloneDeterministic(nodeImplementation, salt));
        escrow = address(new Escrow(address(node), initArgs.asset));
        node.initialize(initArgs, escrow);

        registry.addNode(address(node));

        emit NodeCreated(address(node), initArgs.asset, initArgs.name, initArgs.symbol, initArgs.owner);
    }
}
