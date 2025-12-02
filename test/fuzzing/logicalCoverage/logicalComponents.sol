// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {ComponentAllocation} from "../../../src/interfaces/INode.sol";

contract LogicalComponents is BeforeAfter {
    function logicalComponents() internal {
        _checkComponentInventoryStates();
        _checkRemovableComponentStates();
        if (address(node) != address(0)) {
            _checkActiveComponentAllocationStates();
        }
        _checkRouterRegistryStates();
    }

    function _checkComponentInventoryStates() private {
        uint256 totalComponents = COMPONENTS.length;
        uint256 syncComponents = COMPONENTS_ERC4626.length;
        uint256 asyncComponents = COMPONENTS_ERC7540.length;

        if (totalComponents == 0) {
            fl.log("COMP_inventory_empty");
        } else if (totalComponents <= 3) {
            fl.log("COMP_inventory_minimal");
        } else {
            fl.log("COMP_inventory_diverse");
        }

        if (syncComponents == 0) {
            fl.log("COMP_no_sync_components");
        }
        if (asyncComponents == 0) {
            fl.log("COMP_no_async_components");
        }
        if (syncComponents > 0 && asyncComponents > 0) {
            fl.log("COMP_mixed_component_types");
        }
    }

    function _checkRemovableComponentStates() private {
        uint256 removableCount = REMOVABLE_COMPONENTS.length;
        if (removableCount == 0) {
            fl.log("COMP_no_removable_components");
        } else if (removableCount < COMPONENTS.length) {
            fl.log("COMP_partial_removable_set");
        } else {
            fl.log("COMP_all_components_removable");
        }
    }

    function _checkActiveComponentAllocationStates() private {
        address[] memory activeComponents = node.getComponents();
        if (activeComponents.length == 0) {
            fl.log("COMP_node_has_no_components");
            return;
        }

        uint256 totalWeight;
        uint256 highWeightComponents;
        uint256 asyncActiveComponents;

        for (uint256 i = 0; i < activeComponents.length; i++) {
            address component = activeComponents[i];
            ComponentAllocation memory alloc = node.getComponentAllocation(component);
            totalWeight += alloc.targetWeight;

            if (alloc.targetWeight >= 0.5 ether) {
                highWeightComponents++;
                fl.log("COMP_component_high_weight");
            } else if (alloc.targetWeight == 0) {
                fl.log("COMP_component_zero_weight");
            } else {
                fl.log("COMP_component_balanced_weight");
            }

            if (_isAsyncComponent(component)) {
                asyncActiveComponents++;
                fl.log("COMP_async_component_active");
            } else {
                fl.log("COMP_sync_component_active");
            }
        }

        if (totalWeight == 1e18) {
            fl.log("COMP_weights_balanced_to_wad");
        } else {
            fl.log("COMP_weights_off_target");
        }

        if (asyncActiveComponents == 0) {
            fl.log("COMP_no_async_active");
        } else if (asyncActiveComponents == activeComponents.length) {
            fl.log("COMP_only_async_active");
        } else {
            fl.log("COMP_mixed_active_types");
        }

        if (highWeightComponents > 0) {
            fl.log("COMP_high_weight_components_exist");
        }
    }

    function _checkRouterRegistryStates() private {
        uint256 routerCount = ROUTERS.length;
        if (routerCount == 0) {
            fl.log("COMP_router_registry_empty");
        } else if (routerCount < 3) {
            fl.log("COMP_router_registry_sparse");
        } else {
            fl.log("COMP_router_registry_populated");
        }

        if (REBALANCERS.length == 0) {
            fl.log("COMP_no_rebalancers_registered");
        } else if (REBALANCERS.length == 1) {
            fl.log("COMP_single_rebalancer");
        } else {
            fl.log("COMP_multi_rebalancer_setup");
        }
    }

    function _isAsyncComponent(address component) private view returns (bool) {
        for (uint256 i = 0; i < COMPONENTS_ERC7540.length; i++) {
            if (COMPONENTS_ERC7540[i] == component) {
                return true;
            }
        }
        return false;
    }
}
