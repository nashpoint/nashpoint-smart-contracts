// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Node} from "../../../src/Node.sol";

contract LogicalFuzzSetup is BeforeAfter {
    function logicalFuzzSetup() internal {
        _checkUserProvisioningStates();
        _checkEnvironmentSizingStates();
        _checkProtocolConfigurationStates();
    }

    function _checkUserProvisioningStates() private {
        uint256 userCount = USERS.length;
        if (userCount == 0) {
            fl.log("SETUP_no_users_configured");
            return;
        }

        uint256 fullyProvisioned;
        uint256 missingAllowance;
        uint256 shareHolders;
        uint256 idleWallets;

        for (uint256 i = 0; i < userCount; i++) {
            address user = USERS[i];
            uint256 assetBalance = asset.balanceOf(user);
            uint256 shareBalance = node.balanceOf(user);
            uint256 allowance = asset.allowance(user, address(node));
            ActorState storage snapshot = states[1].actorStates[user];

            if (assetBalance > 0) {
                fl.log("SETUP_user_holds_assets");
            } else {
                fl.log("SETUP_user_no_assets");
            }

            if (shareBalance > 0) {
                shareHolders++;
                fl.log("SETUP_user_has_shares");
            }

            if (snapshot.pendingRedeem > 0) {
                fl.log("SETUP_user_pending_redeem");
            }
            if (snapshot.claimableAssets > 0) {
                fl.log("SETUP_user_claimable_assets");
            }

            bool ready = allowance > 0 && assetBalance > 0;
            if (ready) {
                fullyProvisioned++;
            } else {
                missingAllowance++;
            }

            if (assetBalance == 0 && shareBalance == 0) {
                idleWallets++;
                fl.log("SETUP_user_idle_wallet");
            }
        }

        if (fullyProvisioned == userCount) {
            fl.log("SETUP_all_users_allowanced");
        } else if (fullyProvisioned > 0) {
            fl.log("SETUP_partial_user_allowances");
        } else {
            fl.log("SETUP_no_user_allowances");
        }

        if (shareHolders == 0) {
            fl.log("SETUP_no_share_holders");
        } else if (shareHolders == userCount) {
            fl.log("SETUP_all_users_have_shares");
        }

        if (idleWallets == userCount) {
            fl.log("SETUP_everyone_idle");
        } else if (idleWallets > 0) {
            fl.log("SETUP_some_idle_wallets");
        }
    }

    function _checkEnvironmentSizingStates() private {
        uint256 tokenCount = TOKENS.length;
        uint256 donateeCount = DONATEES.length;
        uint256 componentCount = COMPONENTS.length;
        uint256 managedNodes = MANAGED_NODES.length;
        uint256 routerCount = ROUTERS.length;

        if (tokenCount == 0) {
            fl.log("SETUP_no_tokens_registered");
        } else if (tokenCount <= 4) {
            fl.log("SETUP_small_token_catalog");
        } else {
            fl.log("SETUP_rich_token_catalog");
        }

        if (donateeCount == 0) {
            fl.log("SETUP_no_donatees_available");
        } else if (donateeCount <= 5) {
            fl.log("SETUP_limited_donatees");
        } else {
            fl.log("SETUP_diverse_donatees");
        }

        if (componentCount == 0) {
            fl.log("SETUP_no_components_registered");
        } else if (componentCount <= 3) {
            fl.log("SETUP_minimal_component_set");
        } else {
            fl.log("SETUP_multi_component_set");
        }

        if (managedNodes == 0) {
            fl.log("SETUP_no_managed_nodes");
        } else if (managedNodes == MAX_MANAGED_NODES) {
            fl.log("SETUP_managed_nodes_at_capacity");
        } else {
            fl.log("SETUP_managed_nodes_available");
        }

        if (routerCount == 0) {
            fl.log("SETUP_no_routers_registered");
        } else {
            fl.log("SETUP_router_inventory_present");
        }
    }

    function _checkProtocolConfigurationStates() private {
        if (!protocolSet) {
            fl.log("SETUP_protocol_uninitialized");
            return;
        }
        fl.log("SETUP_protocol_initialized");

        if (address(node) == address(0)) {
            fl.log("SETUP_active_node_missing");
            return;
        }

        // NOTE: quoter has been removed in remediation commit
        // if (address(node.quoter()) == address(0)) {
        //     fl.log("SETUP_quoter_missing");
        // } else {
        //     fl.log("SETUP_quoter_configured");
        // }

        uint64 targetReserve = node.targetReserveRatio();
        if (targetReserve == 0) {
            fl.log("SETUP_zero_target_reserve");
        } else if (targetReserve <= 0.2 ether) {
            fl.log("SETUP_low_target_reserve");
        } else if (targetReserve >= 0.5 ether) {
            fl.log("SETUP_high_target_reserve");
        }

        // NOTE: swingPricingEnabled has been removed in remediation commit

        if (node.validateComponentRatios()) {
            fl.log("SETUP_component_weights_balanced");
        } else {
            fl.log("SETUP_component_weights_unbalanced");
        }

        uint256 iterationPhase = iteration;
        if (iterationPhase <= 25) {
            fl.log("SETUP_iteration_bootstrap_phase");
        } else if (iterationPhase <= 100) {
            fl.log("SETUP_iteration_growth_phase");
        } else {
            fl.log("SETUP_iteration_mature_phase");
        }
    }
}
