// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Escrow} from "./Escrow.sol";
import {Node} from "./Node.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {INode, ComponentAllocation} from "./interfaces/INode.sol";
import {INodeFactory} from "./interfaces/INodeFactory.sol";
import {INodeRegistry} from "./interfaces/INodeRegistry.sol";

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
    function deployFullNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address rebalancer,
        address quoter,
        address pricer,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        ComponentAllocation memory reserveAllocation,
        bytes32 salt
    ) external returns (INode node, IEscrow escrow) {
        node = createNode(
            name,
            symbol,
            asset,
            address(this),
            rebalancer,
            quoter,
            routers,
            components,
            componentAllocations,
            reserveAllocation,
            salt
        );
        escrow = IEscrow(address(new Escrow{salt: salt}(address(node))));
        node.setNodePricer(address(pricer));
        node.initialize(address(escrow));
        Ownable(address(node)).transferOwnership(owner);
    }

    /// @inheritdoc INodeFactory
    function createNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address rebalancer,
        address quoter,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        ComponentAllocation memory reserveAllocation,
        bytes32 salt
    ) public returns (INode node) {
        if (asset == address(0) || owner == address(0) || quoter == address(0) || rebalancer == address(0)) {
            revert ErrorsLib.ZeroAddress();
        }
        if (bytes(name).length == 0) revert ErrorsLib.InvalidName();
        if (bytes(symbol).length == 0) revert ErrorsLib.InvalidSymbol();
        if (components.length != componentAllocations.length) revert ErrorsLib.LengthMismatch();

        if (!registry.isQuoter(quoter)) revert ErrorsLib.NotRegistered();
        if (!registry.isRebalancer(rebalancer)) revert ErrorsLib.NotRegistered();
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
                    quoter,
                    owner,
                    rebalancer,
                    routers,
                    components,
                    componentAllocations,
                    reserveAllocation
                )
            )
        );

        registry.addNode(address(node));
        emit EventsLib.CreateNode(address(node), asset, name, symbol, owner, rebalancer, salt);
    }
}
