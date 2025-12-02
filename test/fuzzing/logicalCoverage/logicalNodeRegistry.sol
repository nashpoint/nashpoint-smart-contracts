// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {RegistryType} from "../../../src/interfaces/INodeRegistry.sol";

contract LogicalNodeRegistry is BeforeAfter {
    function logicalNodeRegistry() internal {
        _checkFeeConfigurationStates();
        _checkRoleCoverageStates();
        _checkPoliciesRootState();
        _checkExtendedRoleStates();
    }

    // NOTE: protocolMaxSwingFactor has been removed in remediation commit
    function _checkFeeConfigurationStates() private {
        uint64 managementFee = registry.protocolManagementFee();
        uint64 executionFee = registry.protocolExecutionFee();
        address feeAddress = registry.protocolFeeAddress();

        if (managementFee == 0) {
            fl.log("REGISTRY_management_fee_zero");
        } else {
            fl.log("REGISTRY_management_fee_active");
        }

        if (executionFee == 0) {
            fl.log("REGISTRY_execution_fee_zero");
        } else if (executionFee > 0.02 ether) {
            fl.log("REGISTRY_execution_fee_high");
        } else {
            fl.log("REGISTRY_execution_fee_low");
        }

        // NOTE: swingFactor has been removed in remediation commit

        if (feeAddress == address(0)) {
            fl.log("REGISTRY_fee_address_missing");
        } else {
            fl.log("REGISTRY_fee_address_set");
            if (feeAddress == protocolFeesAddress) {
                fl.log("REGISTRY_fee_address_matches_protocol");
            } else {
                fl.log("REGISTRY_fee_address_custom");
            }
        }
    }

    function _checkRoleCoverageStates() private {
        if (address(factory) != address(0)) {
            if (registry.isRegistryType(address(factory), RegistryType.FACTORY)) {
                fl.log("REGISTRY_factory_role_granted");
            } else {
                fl.log("REGISTRY_factory_role_missing");
            }
        }

        address[] memory routers = new address[](6);
        routers[0] = address(router4626);
        routers[1] = address(router7540);
        routers[2] = address(routerFluid);
        routers[3] = address(routerIncentra);
        routers[4] = address(routerMerkl);
        routers[5] = address(routerOneInch);

        uint256 routerRoles;
        for (uint256 i = 0; i < routers.length; i++) {
            if (routers[i] == address(0)) {
                continue;
            }
            if (registry.isRegistryType(routers[i], RegistryType.ROUTER)) {
                routerRoles++;
            } else {
                fl.log("REGISTRY_router_not_whitelisted");
            }
        }

        if (routerRoles == routers.length) {
            fl.log("REGISTRY_all_routers_whitelisted");
        }

        if (registry.isRegistryType(rebalancer, RegistryType.REBALANCER)) {
            fl.log("REGISTRY_rebalancer_whitelisted");
        } else {
            fl.log("REGISTRY_rebalancer_missing_role");
        }

        if (address(node) != address(0)) {
            if (registry.isNode(address(node))) {
                fl.log("REGISTRY_active_node_registered");
            } else {
                fl.log("REGISTRY_active_node_missing_role");
            }
        }
    }

    function _checkPoliciesRootState() private {
        bytes32 root = registry.policiesRoot();
        if (root == bytes32(0)) {
            fl.log("REGISTRY_policies_root_unset");
        } else {
            fl.log("REGISTRY_policies_root_set");
        }
    }

    function _checkExtendedRoleStates() private {
        // NOTE: quoter has been removed in the remediation commit
        // if (address(quoter) != address(0)) {
        //     if (registry.isRegistryType(address(quoter), RegistryType.QUOTER)) {
        //         fl.log("REGISTRY_quoter_registered");
        //     } else {
        //         fl.log("REGISTRY_quoter_missing_role");
        //     }
        // }

        if (registry.isRegistryType(address(node), RegistryType.NODE)) {
            fl.log("REGISTRY_explicit_active_node_role");
        }

        if (registry.isRegistryType(address(router7540), RegistryType.ROUTER)) {
            fl.log("REGISTRY_router7540_registered");
        }
        if (registry.isRegistryType(address(routerOneInch), RegistryType.ROUTER)) {
            fl.log("REGISTRY_router_oneinch_registered");
        }
    }
}
