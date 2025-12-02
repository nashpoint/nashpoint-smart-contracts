// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {INode} from "../../../src/interfaces/INode.sol";

contract LogicalNodeFactory is BeforeAfter {
    function logicalNodeFactory() internal {
        _checkManagedNodeInventory();
        _checkActiveNodeSelection();
        _checkFactoryDependencies();
        _checkManagedEscrowCoverage();
        _checkManagedNodeLiquidityStates();
    }

    function _checkManagedNodeInventory() private {
        uint256 managed = MANAGED_NODES.length;
        if (managed == 0) {
            fl.log("FACTORY_no_managed_nodes");
        } else if (managed == 1) {
            fl.log("FACTORY_single_managed_node");
        } else if (managed == MAX_MANAGED_NODES) {
            fl.log("FACTORY_managed_nodes_at_capacity");
        } else {
            fl.log("FACTORY_multiple_managed_nodes");
        }

        for (uint256 i = 0; i < managed; i++) {
            address managedNode = MANAGED_NODES[i];
            address escrowAddr = MANAGED_NODE_ESCROWS[managedNode];
            if (escrowAddr == address(escrow) && managedNode == address(node)) {
                fl.log("FACTORY_active_node_registered");
            }

            if (registry.isNode(managedNode)) {
                fl.log("FACTORY_node_registered_in_registry");
            } else {
                fl.log("FACTORY_node_missing_registry_role");
            }

            if (escrowAddr == address(0)) {
                fl.log("FACTORY_managed_node_missing_escrow");
            }
        }
    }

    function _checkActiveNodeSelection() private {
        if (MANAGED_NODES.length == 0) {
            return;
        }

        address activeNode = address(node);
        if (activeNode == address(0)) {
            fl.log("FACTORY_active_node_not_set");
            return;
        }

        if (MANAGED_NODE_ESCROWS[activeNode] == address(0)) {
            fl.log("FACTORY_active_node_missing_escrow");
        } else {
            fl.log("FACTORY_active_node_has_escrow");
        }

        bool tracked;
        for (uint256 i = 0; i < MANAGED_NODES.length; i++) {
            if (MANAGED_NODES[i] == activeNode) {
                tracked = true;
                break;
            }
        }

        if (tracked) {
            fl.log("FACTORY_active_node_in_inventory");
        } else {
            fl.log("FACTORY_active_node_outside_inventory");
        }
    }

    function _checkFactoryDependencies() private {
        if (address(factory) == address(0)) {
            fl.log("FACTORY_contract_missing");
            return;
        }

        if (address(factory.registry()) == address(registry)) {
            fl.log("FACTORY_registry_linked");
        } else {
            fl.log("FACTORY_registry_mismatch");
        }

        if (factory.nodeImplementation() != address(0)) {
            fl.log("FACTORY_implementation_set");
        } else {
            fl.log("FACTORY_implementation_missing");
        }
    }

    function _checkManagedEscrowCoverage() private {
        if (MANAGED_NODES.length == 0) {
            return;
        }

        uint256 missingEscrows;
        uint256 matchingEscrows;

        for (uint256 i = 0; i < MANAGED_NODES.length; i++) {
            address managedNode = MANAGED_NODES[i];
            address escrowAddr = MANAGED_NODE_ESCROWS[managedNode];

            if (escrowAddr == address(0)) {
                missingEscrows++;
                fl.log("FACTORY_managed_node_without_escrow");
            } else {
                matchingEscrows++;
                if (escrowAddr == address(escrow)) {
                    fl.log("FACTORY_managed_node_uses_active_escrow");
                } else {
                    fl.log("FACTORY_managed_node_custom_escrow");
                }
            }
        }

        if (missingEscrows == 0) {
            fl.log("FACTORY_all_managed_nodes_have_escrow");
        }
        if (matchingEscrows == 0) {
            fl.log("FACTORY_no_registered_escrows");
        }
    }

    function _checkManagedNodeLiquidityStates() private {
        if (MANAGED_NODES.length == 0) {
            return;
        }

        uint256 nodesWithAssets;
        uint256 nodesWithoutAssets;
        uint256 nodesWithEscrowBalances;

        for (uint256 i = 0; i < MANAGED_NODES.length; i++) {
            address managedNode = MANAGED_NODES[i];
            address escrowAddr = MANAGED_NODE_ESCROWS[managedNode];

            try INode(managedNode).totalAssets() returns (uint256 totalAssets) {
                if (totalAssets == 0) {
                    nodesWithoutAssets++;
                    fl.log("FACTORY_managed_node_zero_assets");
                } else if (totalAssets < 1_000 ether) {
                    nodesWithAssets++;
                    fl.log("FACTORY_managed_node_low_assets");
                } else {
                    nodesWithAssets++;
                    fl.log("FACTORY_managed_node_high_assets");
                }
            } catch {
                fl.log("FACTORY_managed_node_query_failed");
            }

            if (escrowAddr != address(0)) {
                uint256 escrowBalance = asset.balanceOf(escrowAddr);
                if (escrowBalance == 0) {
                    fl.log("FACTORY_managed_escrow_zero_balance");
                } else {
                    nodesWithEscrowBalances++;
                    fl.log("FACTORY_managed_escrow_funded");
                }
            }
        }

        if (nodesWithoutAssets == MANAGED_NODES.length) {
            fl.log("FACTORY_all_managed_nodes_empty");
        } else if (nodesWithAssets == MANAGED_NODES.length) {
            fl.log("FACTORY_all_managed_nodes_funded");
        }

        if (nodesWithEscrowBalances == 0 && MANAGED_NODES.length > 0) {
            fl.log("FACTORY_no_managed_escrow_liquidity");
        }
    }
}
