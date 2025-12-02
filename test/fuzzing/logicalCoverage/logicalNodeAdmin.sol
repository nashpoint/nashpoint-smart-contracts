// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {Node} from "../../../src/Node.sol";

contract LogicalNodeAdmin is BeforeAfter {
    function logicalNodeAdmin() internal {
        if (address(node) == address(0)) {
            fl.log("NODE_ADMIN_uninitialized");
            return;
        }

        _checkRebalanceAndTimingStates();
        _checkRouterAccessStates();
        _checkFeeAndSwingStates();
        _checkPolicyRegistryStates();
    }

    function _checkRebalanceAndTimingStates() private {
        Node nodeImpl = Node(address(node));
        uint64 last = nodeImpl.lastRebalance();
        uint64 window = nodeImpl.rebalanceWindow();
        uint64 cooldown = nodeImpl.rebalanceCooldown();
        uint64 elapsed = uint64(block.timestamp) - last;

        if (block.timestamp < last + window) {
            fl.log("NODE_ADMIN_rebalance_window_open");
        } else {
            fl.log("NODE_ADMIN_rebalance_window_closed");
        }

        if (elapsed < cooldown) {
            fl.log("NODE_ADMIN_rebalance_cooldown_active");
        } else {
            fl.log("NODE_ADMIN_rebalance_cooldown_elapsed");
        }

        if (window == 0) {
            fl.log("NODE_ADMIN_zero_rebalance_window");
        }
        if (cooldown == 0) {
            fl.log("NODE_ADMIN_zero_rebalance_cooldown");
        }
    }

    function _checkRouterAccessStates() private {
        address[] memory trackedRouters = new address[](6);
        trackedRouters[0] = address(router4626);
        trackedRouters[1] = address(router7540);
        trackedRouters[2] = address(routerFluid);
        trackedRouters[3] = address(routerIncentra);
        trackedRouters[4] = address(routerMerkl);
        trackedRouters[5] = address(routerOneInch);

        uint256 enabledRouters;
        for (uint256 i = 0; i < trackedRouters.length; i++) {
            address routerAddr = trackedRouters[i];
            if (node.isRouter(routerAddr)) {
                enabledRouters++;
                fl.log("NODE_ADMIN_router_enabled");
            } else {
                fl.log("NODE_ADMIN_router_disabled");
            }
        }

        if (enabledRouters == 0) {
            fl.log("NODE_ADMIN_no_routers_enabled");
        } else if (enabledRouters == trackedRouters.length) {
            fl.log("NODE_ADMIN_all_routers_enabled");
        }

        if (node.isRebalancer(rebalancer)) {
            fl.log("NODE_ADMIN_rebalancer_whitelisted");
        } else {
            fl.log("NODE_ADMIN_rebalancer_missing");
        }
    }

    // NOTE: swingPricing and quoter have been removed in the remediation commit
    function _checkFeeAndSwingStates() private {
        uint64 managementFee = node.annualManagementFee();
        uint64 protocolFee = registry.protocolManagementFee();
        uint256 maxDeposit = node.maxDepositSize();

        if (managementFee == 0) {
            fl.log("NODE_ADMIN_zero_management_fee");
        } else {
            fl.log("NODE_ADMIN_management_fee_active");
        }

        if (protocolFee == 0) {
            fl.log("NODE_ADMIN_zero_protocol_management_fee");
        }

        // NOTE: swingPricing has been removed in remediation commit

        if (maxDeposit == type(uint256).max) {
            fl.log("NODE_ADMIN_unbounded_deposit");
        } else if (maxDeposit < 1_000e18) {
            fl.log("NODE_ADMIN_low_max_deposit");
        } else {
            fl.log("NODE_ADMIN_max_deposit_configured");
        }

        if (node.nodeOwnerFeeAddress() == address(0)) {
            fl.log("NODE_ADMIN_fee_address_missing");
        } else {
            fl.log("NODE_ADMIN_fee_address_set");
        }
    }

    function _checkPolicyRegistryStates() private {
        uint256 registeredPolicies = REGISTERED_POLICY_SELECTORS.length;
        if (registeredPolicies == 0) {
            fl.log("NODE_ADMIN_no_policies_registered");
        } else if (registeredPolicies < 3) {
            fl.log("NODE_ADMIN_sparse_policy_set");
        } else {
            fl.log("NODE_ADMIN_dense_policy_set");
        }

        // NOTE: quoter has been removed in remediation commit
    }
}
