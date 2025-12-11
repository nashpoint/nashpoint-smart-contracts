// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsNodeFactory.sol";
import "./helpers/postconditions/PostconditionsNodeFactory.sol";

import {NodeFactory} from "../../src/NodeFactory.sol";
import {INode} from "../../src/interfaces/INode.sol";
import {IRouter} from "../../src/interfaces/IRouter.sol";
import {IERC7575} from "../../src/interfaces/IERC7575.sol";
import {Node} from "../../src/Node.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title FuzzNodeFactory
 * @notice Fuzzing handlers for NodeFactory contract
 *
 * ACCESS CONTROL CATEGORY: Category 1 (User - Public)
 *
 * This contract contains only public, permissionless functions that any user can call.
 * These functions do not require special roles or privileges.
 *
 * Functions in this category:
 * - deployFullNode: Public permissionless deployment of a full node with escrow
 */
import {SetupCall} from "../../src/interfaces/INodeFactory.sol";

contract FuzzNodeFactory is PreconditionsNodeFactory, PostconditionsNodeFactory {
    uint256 internal constant WAD = 1e18;

    /**
     * @notice Fuzzing handler for deployFullNode function
     * @dev Category 1: Public permissionless function - any user can deploy a node
     * @param seed Random seed for generating test parameters and selecting actor
     */
    function fuzz_nodeFactory_deploy(uint256 seed) public setCurrentActor(seed) {
        if (_managedNodeCount() >= MAX_MANAGED_NODES) {
            return;
        }

        NodeFactoryDeployParams memory params = nodeFactoryDeployPreconditions(seed);

        _before();

        SetupCall[] memory setupCalls = new SetupCall[](0);
        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(factory),
            abi.encodeWithSelector(
                NodeFactory.deployFullNode.selector, params.initArgs, params.payload, setupCalls, params.salt
            ),
            currentActor
        );

        nodeFactoryDeployPostconditions(success, returnData, currentActor, params);

        if (!success) {
            return;
        }

        (address deployedNodeAddr, address deployedEscrowAddr) = abi.decode(returnData, (address, address));
        _configureDeployedNode(deployedNodeAddr, deployedEscrowAddr, params, seed);
    }

    // ==============================================================
    // INTERNAL HELPERS
    // ==============================================================

    function _configureDeployedNode(
        address deployedNodeAddr,
        address deployedEscrowAddr,
        NodeFactoryDeployParams memory params,
        uint256 seed
    ) internal {
        _registerManagedNode(deployedNodeAddr, deployedEscrowAddr);
        _setActiveNode(deployedNodeAddr);

        address ownerActor = params.initArgs.owner == address(0) ? owner : params.initArgs.owner;
        uint256 entropy =
            uint256(keccak256(abi.encodePacked(seed, deployedNodeAddr, deployedEscrowAddr, block.timestamp)));

        _setupNodeCore(deployedNodeAddr, ownerActor, entropy);
        _configureNodePolicies(deployedNodeAddr, ownerActor);
        _prepareNodeApprovals(deployedNodeAddr);
        _seedNodeLiquidity(deployedNodeAddr, deployedEscrowAddr, ownerActor, entropy);

        _setActiveNode(deployedNodeAddr);
    }

    function _setupNodeCore(address nodeAddr, address ownerActor, uint256 entropy) internal {
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.addRouter.selector, address(router4626)),
            "NODE_FACTORY:ADD_ROUTER_4626"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.addRouter.selector, address(router7540)),
            "NODE_FACTORY:ADD_ROUTER_7540"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.addRouter.selector, address(routerFluid)),
            "NODE_FACTORY:ADD_ROUTER_FLUID"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.addRouter.selector, address(routerIncentra)),
            "NODE_FACTORY:ADD_ROUTER_INCENTRA"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.addRouter.selector, address(routerMerkl)),
            "NODE_FACTORY:ADD_ROUTER_MERKL"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.addRouter.selector, address(routerOneInch)),
            "NODE_FACTORY:ADD_ROUTER_ONEINCH"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.addRebalancer.selector, rebalancer),
            "NODE_FACTORY:ADD_REBALANCER"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.setMaxDepositSize.selector, uint256(1e36)),
            "NODE_FACTORY:SET_MAX_DEPOSIT"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.setRebalanceCooldown.selector, uint64(0)),
            "NODE_FACTORY:SET_REBALANCE_COOLDOWN"
        );

        uint64 totalComponentWeight = _addNodeComponents(nodeAddr, ownerActor, entropy);
        uint64 reserveRatio = totalComponentWeight >= WAD ? 0 : uint64(WAD - totalComponentWeight);
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, reserveRatio),
            "NODE_FACTORY:SET_RESERVE_RATIO"
        );
    }

    function _configureNodePolicies(address nodeAddr, address ownerActor) internal {
        _callAs(
            ownerActor,
            address(capPolicy),
            abi.encodeWithSelector(capPolicy.setCap.selector, nodeAddr, DEFAULT_NODE_CAP_AMOUNT),
            "NODE_FACTORY:CAP_POLICY"
        );

        address[] memory whitelistActors = new address[](USERS.length + 5);
        for (uint256 i = 0; i < USERS.length; i++) {
            whitelistActors[i] = USERS[i];
        }
        whitelistActors[USERS.length] = owner;
        whitelistActors[USERS.length + 1] = rebalancer;
        whitelistActors[USERS.length + 2] = address(router4626);
        whitelistActors[USERS.length + 3] = address(router7540);
        whitelistActors[USERS.length + 4] = vaultSeeder;

        _callAs(
            ownerActor,
            address(gatePolicyWhitelist),
            abi.encodeWithSelector(gatePolicyWhitelist.add.selector, nodeAddr, whitelistActors),
            "NODE_FACTORY:GATE_POLICY"
        );
        _callAs(
            ownerActor,
            address(nodePausingPolicy),
            abi.encodeWithSelector(nodePausingPolicy.add.selector, nodeAddr, whitelistActors),
            "NODE_FACTORY:PAUSE_POLICY"
        );
        _callAs(
            ownerActor,
            address(protocolPausingPolicy),
            abi.encodeWithSelector(protocolPausingPolicy.add.selector, _singleton(owner)),
            "NODE_FACTORY:PROTOCOL_POLICY"
        );
        _callAs(
            ownerActor,
            address(digiftAdapter),
            abi.encodeWithSelector(digiftAdapter.setNode.selector, nodeAddr, true),
            "NODE_FACTORY:DIGIFT_LINK"
        );
    }

    function _prepareNodeApprovals(address nodeAddr) internal {
        address[] memory actors = new address[](USERS.length + 3);
        for (uint256 i = 0; i < USERS.length; i++) {
            actors[i] = USERS[i];
        }
        actors[USERS.length] = owner;
        actors[USERS.length + 1] = rebalancer;
        actors[USERS.length + 2] = vaultSeeder;

        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            _callAs(
                actor,
                address(assetToken),
                abi.encodeWithSelector(IERC20.approve.selector, nodeAddr, type(uint256).max),
                "NODE_FACTORY:ASSET_APPROVE"
            );
            _callAs(
                actor,
                nodeAddr,
                abi.encodeWithSelector(IERC20.approve.selector, nodeAddr, type(uint256).max),
                "NODE_FACTORY:SHARE_APPROVE"
            );
        }
    }

    function _seedNodeLiquidity(address nodeAddr, address escrowAddr, address ownerActor, uint256 entropy) internal {
        vm.startPrank(nodeAddr);
        assetToken.approve(address(digiftAdapter), type(uint256).max);
        digiftAdapter.approve(address(digiftAdapter), type(uint256).max);
        vm.stopPrank();

        uint256 seedAmount = 50_000 ether + (entropy % 100_000 ether);
        assetToken.mint(vaultSeeder, seedAmount);

        _callAs(
            vaultSeeder,
            address(assetToken),
            abi.encodeWithSelector(IERC20.approve.selector, nodeAddr, type(uint256).max),
            "NODE_FACTORY:SEED_APPROVE"
        );

        uint64 originalWindow = Node(nodeAddr).rebalanceWindow();
        uint64 tempWindow = uint64(10_000_000_000);
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.setRebalanceWindow.selector, tempWindow),
            "NODE_FACTORY:WINDOW_EXTEND"
        );
        _callAs(
            vaultSeeder,
            nodeAddr,
            abi.encodeWithSelector(IERC7575.deposit.selector, seedAmount, vaultSeeder),
            "NODE_FACTORY:SEED_DEPOSIT"
        );
        _callAs(
            ownerActor,
            nodeAddr,
            abi.encodeWithSelector(INode.setRebalanceWindow.selector, originalWindow),
            "NODE_FACTORY:WINDOW_RESTORE"
        );

        vm.warp(block.timestamp + 1 days);
        _callAs(
            rebalancer, nodeAddr, abi.encodeWithSelector(INode.startRebalance.selector), "NODE_FACTORY:START_REBALANCE"
        );
        lastTimestamp = block.timestamp;
    }

    function _addNodeComponents(address nodeAddr, address ownerActor, uint256 entropy)
        internal
        returns (uint64 totalWeight)
    {
        uint8[6] memory order = _componentOrder(entropy);
        uint256 componentCount = 2 + (entropy % 5);
        if (componentCount > order.length) {
            componentCount = order.length;
        }

        for (uint256 i = 0; i < componentCount; i++) {
            uint8 idx = order[i];
            (address component, address router, uint64 weight) = _componentTemplate(idx);

            // Skip components that have been de-whitelisted by prior fuzzing operations
            if (!IRouter(router).isWhitelisted(component)) {
                continue;
            }

            _callAs(
                ownerActor,
                nodeAddr,
                abi.encodeWithSelector(
                    INode.addComponent.selector, component, weight, DEFAULT_COMPONENT_MAX_DELTA, router
                ),
                "NODE_FACTORY:ADD_COMPONENT"
            );
            totalWeight += weight;
        }
    }

    function _componentOrder(uint256 entropy) internal pure returns (uint8[6] memory order) {
        order = [uint8(0), 1, 2, 3, 4, 5];
        for (uint256 i = 1; i < order.length; i++) {
            uint256 swapIndex = 1 + (uint256(keccak256(abi.encodePacked(entropy, i))) % (order.length - 1));
            if (swapIndex >= order.length) {
                swapIndex = order.length - 1;
            }
            if (swapIndex != i) {
                (order[i], order[swapIndex]) = (order[swapIndex], order[i]);
            }
        }
    }

    function _componentTemplate(uint8 templateId)
        internal
        view
        returns (address component, address router, uint64 weight)
    {
        if (templateId == 0) {
            return (address(vault), address(router4626), uint64(0.3 ether));
        } else if (templateId == 1) {
            return (address(vaultSecondary), address(router4626), uint64(0.19 ether));
        } else if (templateId == 2) {
            return (address(vaultTertiary), address(router4626), uint64(0.14 ether));
        } else if (templateId == 3) {
            return (address(liquidityPool), address(router7540), uint64(0.12 ether));
        } else if (templateId == 4) {
            return (address(liquidityPoolSecondary), address(router7540), uint64(0.1 ether));
        } else if (templateId == 5) {
            return (address(liquidityPoolTertiary), address(router7540), uint64(0.08 ether));
        }

        return (address(vault), address(router4626), uint64(0.3 ether));
    }

    function _callAs(address actor, address target, bytes memory data, string memory err)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returnData) = fl.doFunctionCall(target, data, actor);
        if (!success) {
            console.log("FuzzNodeFactory::_callAs failure:", err);
        }
        fl.t(success, err);
        return returnData;
    }
}
