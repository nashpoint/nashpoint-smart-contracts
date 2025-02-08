// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Escrow} from "./Escrow.sol";
import {Node} from "./Node.sol";
import {INode, ComponentAllocation} from "./interfaces/INode.sol";
import {INodeFactory} from "./interfaces/INodeFactory.sol";
import {INodeRegistry} from "./interfaces/INodeRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title NodeFactory
/// @author ODND Studios
contract NodeFactory is INodeFactory {
    /* IMMUTABLES */
    INodeRegistry public immutable registry;

    /* ERRORS */
    error ZeroAddress();
    error InvalidName();
    error InvalidSymbol();
    error LengthMismatch();

    /* EVENTS */
    event NodeCreated(
        address indexed node, address indexed asset, string name, string symbol, address indexed owner, bytes32 salt
    );

    /* CONSTRUCTOR */
    constructor(address registry_) {
        if (registry_ == address(0)) revert ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc INodeFactory
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
    ) external returns (INode node, address escrow) {
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        node =
            _createNode(name, symbol, asset, address(this), components, componentAllocations, targetReserveRatio, salt);

        escrow = address(new Escrow{salt: salt}(address(node)));
        node.addRebalancer(rebalancer);
        node.setQuoter(quoter);
        node.initialize(address(escrow));
        Ownable(address(node)).transferOwnership(owner);
    }

    function _createNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        uint64 targetReserveRatio,
        bytes32 salt
    ) internal returns (INode node) {
        if (asset == address(0) || owner == address(0)) {
            revert ZeroAddress();
        }
        if (bytes(name).length == 0) revert InvalidName();
        if (bytes(symbol).length == 0) revert InvalidSymbol();
        if (components.length != componentAllocations.length) revert LengthMismatch();

        node = INode(
            address(
                new Node{salt: salt}(
                    address(registry), name, symbol, asset, owner, components, componentAllocations, targetReserveRatio
                )
            )
        );

        registry.addNode(address(node));

        emit NodeCreated(address(node), asset, name, symbol, owner, salt);
    }
}
