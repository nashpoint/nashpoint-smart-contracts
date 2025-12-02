// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {ComponentAllocation} from "../../../src/interfaces/INode.sol";

contract LogicalNode is BeforeAfter {
    function logicalNode() internal {
        if (address(node) == address(0)) {
            fl.log("NODE_uninitialized");
            return;
        }

        _checkNodeAccountingStates();
        _checkShareDistributionStates();
        _checkRedemptionRequestStates();
        _checkOperatorNetworkStates();
        _checkComponentAllocationStates();
        _checkLiquidationQueueStates();
    }

    function _checkNodeAccountingStates() private {
        uint256 totalAssets = node.totalAssets();
        uint256 totalSupply = node.totalSupply();
        uint256 sharesExiting = node.sharesExiting();
        uint256 reserveBalance = asset.balanceOf(address(node));
        uint256 escrowBalance = asset.balanceOf(address(escrow));
        uint256 cashAfterRedemptions = node.getCashAfterRedemptions();

        if (totalAssets == 0) {
            fl.log("NODE_zero_total_assets");
        } else if (totalAssets < reserveBalance) {
            fl.log("NODE_assets_concentrated_in_reserve");
        } else {
            fl.log("NODE_assets_split_between_reserve_and_components");
        }

        if (totalSupply == 0) {
            fl.log("NODE_zero_total_supply");
        }

        if (sharesExiting == 0) {
            fl.log("NODE_no_shares_exiting");
        } else if (sharesExiting * 10 <= totalSupply || totalSupply == 0) {
            fl.log("NODE_low_exit_pressure");
        } else {
            fl.log("NODE_high_exit_pressure");
        }

        if (reserveBalance == 0) {
            fl.log("NODE_reserve_empty");
        } else if (reserveBalance < 1_000e18) {
            fl.log("NODE_reserve_low");
        } else {
            fl.log("NODE_reserve_high");
        }

        if (escrowBalance == 0) {
            fl.log("NODE_escrow_empty");
        } else {
            fl.log("NODE_escrow_holds_assets");
        }

        if (cashAfterRedemptions < reserveBalance) {
            fl.log("NODE_cash_adjusted_below_reserve");
        } else {
            fl.log("NODE_cash_adjusted_matches_reserve");
        }
    }

    function _checkShareDistributionStates() private {
        uint256 totalSharesHeld;
        uint256 holders;
        uint256 whales;
        uint256 dustHolders;

        for (uint256 i = 0; i < USERS.length; i++) {
            address user = USERS[i];
            uint256 balance = node.balanceOf(user);
            totalSharesHeld += balance;

            if (balance > 0) {
                holders++;
                fl.log("NODE_user_share_holder");
            } else {
                fl.log("NODE_user_no_shares");
            }

            if (balance > node.totalSupply() / 4 && node.totalSupply() > 0) {
                whales++;
                fl.log("NODE_user_share_whale");
            } else if (balance > 0 && balance < 1e18) {
                dustHolders++;
                fl.log("NODE_user_dust_holder");
            }
        }

        if (holders == 0) {
            fl.log("NODE_no_share_holders");
        } else if (holders == USERS.length && USERS.length > 0) {
            fl.log("NODE_all_users_hold_shares");
        }

        if (whales > 0) {
            fl.log("NODE_share_whales_present");
        }
        if (dustHolders > 0) {
            fl.log("NODE_many_small_holders");
        }

        if (totalSharesHeld == node.totalSupply()) {
            fl.log("NODE_all_shares_in_user_accounts");
        } else if (totalSharesHeld < node.totalSupply()) {
            fl.log("NODE_shares_held_by_non_tracked_addresses");
        }
    }

    function _checkRedemptionRequestStates() private {
        uint256 usersWithPending;
        uint256 usersWithClaimable;
        uint256 usersSettled;

        for (uint256 i = 0; i < USERS.length; i++) {
            address controller = USERS[i];
            (uint256 pending, uint256 claimableShares, uint256 claimableAssets) = node.requests(controller);

            if (pending > 0) {
                usersWithPending++;
                fl.log("NODE_pending_request_exists");
            }
            if (claimableAssets > 0 || claimableShares > 0) {
                usersWithClaimable++;
                fl.log("NODE_claimable_request_exists");
            }
            if (pending == 0 && claimableAssets == 0 && claimableShares == 0) {
                usersSettled++;
            }
        }

        if (usersWithPending == 0) {
            fl.log("NODE_all_requests_settled");
        } else if (usersWithPending > USERS.length / 2) {
            fl.log("NODE_majority_pending_requests");
        }

        if (usersWithClaimable > 0) {
            fl.log("NODE_claimable_assets_available");
        }
        if (usersSettled == USERS.length && USERS.length > 0) {
            fl.log("NODE_no_active_requests");
        }
    }

    function _checkOperatorNetworkStates() private {
        uint256 controllersWithOperators;
        uint256 operatorLinks;

        for (uint256 i = 0; i < USERS.length; i++) {
            address controller = USERS[i];
            uint256 controllerLinks;

            for (uint256 j = 0; j < USERS.length; j++) {
                address candidate = USERS[j];
                if (candidate == controller) {
                    continue;
                }
                if (node.isOperator(controller, candidate)) {
                    controllerLinks++;
                    operatorLinks++;
                    fl.log("NODE_operator_link_active");
                }
            }

            if (controllerLinks > 0) {
                controllersWithOperators++;
            }
            if (controllerLinks > 3) {
                fl.log("NODE_controller_many_operators");
            }
        }

        if (operatorLinks == 0) {
            fl.log("NODE_no_operator_relationships");
        } else if (operatorLinks > USERS.length) {
            fl.log("NODE_dense_operator_network");
        }

        if (controllersWithOperators == USERS.length && USERS.length > 0) {
            fl.log("NODE_all_controllers_have_operators");
        }
    }

    function _checkComponentAllocationStates() private {
        address[] memory activeComponents = node.getComponents();
        uint256 componentCount = activeComponents.length;

        if (componentCount == 0) {
            fl.log("NODE_no_active_components");
            return;
        }
        if (componentCount >= 5) {
            fl.log("NODE_diversified_component_set");
        }

        for (uint256 i = 0; i < componentCount; i++) {
            address component = activeComponents[i];
            ComponentAllocation memory alloc = node.getComponentAllocation(component);

            if (!alloc.isComponent) {
                fl.log("NODE_component_flagged_removed");
                continue;
            }

            if (alloc.targetWeight == 0) {
                fl.log("NODE_component_weight_zero");
            } else if (alloc.targetWeight >= 0.5 ether) {
                fl.log("NODE_component_high_weight");
            } else {
                fl.log("NODE_component_balanced_weight");
            }

            if (alloc.router == address(router4626)) {
                fl.log("NODE_component_router_4626");
            } else if (alloc.router == address(router7540)) {
                fl.log("NODE_component_router_7540");
            } else if (alloc.router == address(routerOneInch)) {
                fl.log("NODE_component_router_oneinch");
            } else {
                fl.log("NODE_component_router_custom");
            }

            if (_isTracked(component, COMPONENTS_ERC7540)) {
                fl.log("NODE_component_async_strategy");
            } else if (_isTracked(component, COMPONENTS_ERC4626)) {
                fl.log("NODE_component_sync_strategy");
            }
        }
    }

    // NOTE: getLiquidationsQueue has been removed in the remediation commit
    function _checkLiquidationQueueStates() private {
        // Liquidation queue was removed; use getComponents() for coverage
        address[] memory components = node.getComponents();
        if (components.length == 0) {
            fl.log("NODE_components_empty");
            return;
        }

        fl.log("NODE_components_present");

        if (components.length > 3) {
            fl.log("NODE_components_many");
        }
    }

    function _isTracked(address target, address[] storage list) private view returns (bool) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == target) {
                return true;
            }
        }
        return false;
    }
}
