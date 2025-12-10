// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Escrow} from "src/Escrow.sol";
import {NodeInitArgs} from "src/Node.sol";

import {INode} from "src/interfaces/INode.sol";
import {INodeFactory, SetupCall} from "src/interfaces/INodeFactory.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";

/// @title NodeFactory
/// @author ODND Studios
/// @notice This factory forwards arbitrary `setupCalls` verbatim, so any ERC20 approval granted
/// to it can be drained by the next caller. Do not grant allowances that live on-chain for more
/// than one tx: use permit or bundle approval + deployment in a single atomic transaction.
/// Post-deployment seeding is safe because funds move directly through the newly created node,
/// and `setupCalls` should be reserved for policy configuration that does not require custody
/// over third-party assets.
contract NodeFactory is INodeFactory {
    /* IMMUTABLES */
    INodeRegistry public immutable registry;
    address public immutable nodeImplementation;

    /* ERRORS */
    error ZeroAddress();
    error InvalidName();
    error InvalidSymbol();
    error Forbidden();

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
    function deployFullNode(
        NodeInitArgs calldata initArgs,
        bytes[] calldata nodePayload,
        SetupCall[] calldata setupCalls,
        bytes32 salt
    ) external returns (INode node, address escrow) {
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        if (initArgs.asset == address(0) || initArgs.owner == address(0)) {
            revert ZeroAddress();
        }
        if (bytes(initArgs.name).length == 0) revert InvalidName();
        if (bytes(initArgs.symbol).length == 0) revert InvalidSymbol();

        node = INode(Clones.cloneDeterministic(nodeImplementation, salt));
        escrow = address(new Escrow(address(node), initArgs.asset));
        node.initialize(initArgs, escrow);

        registry.addNode(address(node));

        for (uint256 i; i < setupCalls.length; i++) {
            // we should forbid adding malicious Nodes to the registry
            if (setupCalls[i].target == address(registry)) revert Forbidden();
            if (!registry.setupCallWhitelisted(setupCalls[i].target)) revert Forbidden();
            Address.functionCall(setupCalls[i].target, setupCalls[i].payload);
        }

        // complete initial setup of the node
        Multicall(address(node)).multicall(nodePayload);

        // transfer ownership to actual owner
        Ownable(address(node)).transferOwnership(initArgs.owner);

        emit NodeCreated(address(node), initArgs.asset, initArgs.name, initArgs.symbol, initArgs.owner);
    }

    /// @inheritdoc INodeFactory
    function predictDeterministicAddress(bytes32 salt, address deployer) external view returns (address predicted) {
        salt = keccak256(abi.encodePacked(deployer, salt));
        predicted = Clones.predictDeterministicAddress(nodeImplementation, salt, address(this));
    }
}
