// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Escrow} from "./Escrow.sol";
import {Node} from "./Node.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
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

    uint256 public immutable maxDelta = 0.01 ether;

    /* CONSTRUCTOR */
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc INodeFactory
    function deployFullNode(DeployParams memory params) external returns (INode node, IEscrow escrow) {
        node = createNode(
            params.name,
            params.symbol,
            params.asset,
            address(this),
            params.routers,
            params.components,
            params.componentAllocations,
            params.reserveAllocation,
            params.salt
        );
        escrow = IEscrow(address(new Escrow{salt: params.salt}(address(node))));
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

        emit EventsLib.CreateNode(address(node), asset, name, symbol, owner, salt);
    }
}
