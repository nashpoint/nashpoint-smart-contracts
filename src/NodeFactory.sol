// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Escrow} from "./Escrow.sol";
import {NodeInitArgs} from "./Node.sol";
import {INode, ComponentAllocation} from "./interfaces/INode.sol";
import {INodeFactory} from "./interfaces/INodeFactory.sol";
import {INodeRegistry} from "./interfaces/INodeRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
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
    function deployFullNode(NodeInitArgs calldata initArgs, bytes[] calldata payload, bytes32 salt)
        external
        returns (INode node, address escrow)
    {
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        if (initArgs.asset == address(0) || initArgs.owner == address(0)) {
            revert ZeroAddress();
        }
        if (bytes(initArgs.name).length == 0) revert InvalidName();
        if (bytes(initArgs.symbol).length == 0) revert InvalidSymbol();

        node = INode(Clones.cloneDeterministic(nodeImplementation, salt));
        escrow = address(new Escrow(address(node), initArgs.asset));
        node.initialize(initArgs, escrow);

        // complete initial setup of the node
        Multicall(address(node)).multicall(payload);

        // transfer ownership to actual owner
        Ownable(address(node)).transferOwnership(initArgs.owner);

        registry.addNode(address(node));

        emit NodeCreated(address(node), initArgs.asset, initArgs.name, initArgs.symbol, initArgs.owner);
    }

    // function _setupNode(INode node, NodeSetupArgs calldata setupArgs) internal {
    //     // add routers
    //     for (uint256 i; i < setupArgs.components.length; ++i) {
    //         if (!node.isRouter(setupArgs.componentAllocations[i].router)) {
    //             node.addRouter(setupArgs.componentAllocations[i].router);
    //         }
    //     }
    //     // set quoter
    //     node.setQuoter(setupArgs.quoter);
    //     // add rebalancer
    //     node.addRebalancer(setupArgs.rebalancer);
    //     node.updateTargetReserveRatio(setupArgs.targetReserveRatio);
    //     for (uint256 i; i < setupArgs.components.length; i++) {
    //         node.addComponent(
    //             setupArgs.components[i],
    //             setupArgs.componentAllocations[i].targetWeight,
    //             setupArgs.componentAllocations[i].maxDelta,
    //             setupArgs.componentAllocations[i].router
    //         );
    //     }
    // }
}
