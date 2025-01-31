// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Escrow} from "./Escrow.sol";
import {Node} from "./Node.sol";

import {INode, ComponentAllocation} from "./interfaces/INode.sol";
import {INodeFactory, DeployParams} from "./interfaces/INodeFactory.sol";
import {INodeRegistry, RegistryType} from "./interfaces/INodeRegistry.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title NodeFactory
/// @author ODND Studios
contract NodeFactory is INodeFactory {
    /* IMMUTABLES */
    INodeRegistry public immutable registry;

    /* CONSTRUCTOR */
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc INodeFactory
    function deployFullNode(DeployParams memory params) external returns (INode node, address escrow) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, params.salt));
        node = _createNode(
            params.name,
            params.symbol,
            params.asset,
            address(this),
            params.routers,
            params.components,
            params.componentAllocations,
            params.reserveAllocation,
            salt
        );

        escrow = address(new Escrow{salt: salt}(address(node)));
        node.addRebalancer(params.rebalancer);
        node.setQuoter(params.quoter);
        node.initialize(address(escrow));
        Ownable(address(node)).transferOwnership(params.owner);
    }

    /// @inheritdoc INodeFactory
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
    ) public returns (INode node) {
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        node =
            _createNode(name, symbol, asset, owner, routers, components, componentAllocations, reserveAllocation, salt);
    }

    function _createNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        ComponentAllocation memory reserveAllocation,
        bytes32 salt
    ) internal returns (INode node) {
        if (asset == address(0) || owner == address(0)) {
            revert ErrorsLib.ZeroAddress();
        }
        if (bytes(name).length == 0) revert ErrorsLib.InvalidName();
        if (bytes(symbol).length == 0) revert ErrorsLib.InvalidSymbol();
        if (components.length != componentAllocations.length) revert ErrorsLib.LengthMismatch();

        for (uint256 i = 0; i < routers.length; i++) {
            if (!registry.isRouter(routers[i])) revert ErrorsLib.NotRegistered();
        }

        node = INode(
            address(
                new Node{salt: salt}(
                    address(registry),
                    name,
                    symbol,
                    asset,
                    owner,
                    routers,
                    components,
                    componentAllocations,
                    reserveAllocation
                )
            )
        );

        registry.addNode(address(node));

        emit EventsLib.NodeCreated(address(node), asset, name, symbol, owner, salt);
    }
}
