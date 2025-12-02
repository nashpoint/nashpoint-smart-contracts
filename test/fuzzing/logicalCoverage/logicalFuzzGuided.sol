// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {Node} from "../../../src/Node.sol";

contract LogicalFuzzGuided is BeforeAfter {
    function logicalFuzzGuided() internal {
        if (address(node) == address(0)) {
            fl.log("GUIDED_node_unavailable");
            return;
        }

        _checkLifecycleIntegrationStates();
        _checkWithdrawalFlowStates();
        _checkReservePreparationStates();
    }

    function _checkLifecycleIntegrationStates() private {
        uint256 users = USERS.length;
        if (users == 0) {
            fl.log("GUIDED_no_users_available");
            return;
        }

        uint256 shareHolders;
        uint256 pendingUsers;
        uint256 claimableUsers;
        uint256 fullyEngaged;
        uint256 idle;

        for (uint256 i = 0; i < users; i++) {
            address controller = USERS[i];
            (uint256 pending,, uint256 claimableAssets) = node.requests(controller);
            uint256 shareBalance = node.balanceOf(controller);

            if (shareBalance > 0) {
                shareHolders++;
                fl.log("GUIDED_user_has_shares");
            } else {
                idle++;
            }

            if (pending > 0) {
                pendingUsers++;
                fl.log("GUIDED_user_pending_redeem_request");
            }
            if (claimableAssets > 0) {
                claimableUsers++;
                fl.log("GUIDED_user_claimable_assets_ready");
            }
            if (shareBalance > 0 && claimableAssets > 0) {
                fullyEngaged++;
                fl.log("GUIDED_user_full_redeem_cycle");
            }
        }

        if (shareHolders == users) {
            fl.log("GUIDED_all_users_have_shares");
        } else if (shareHolders == 0) {
            fl.log("GUIDED_no_user_has_shares");
        }

        if (idle == users) {
            fl.log("GUIDED_all_users_idle");
        } else if (idle > 0) {
            fl.log("GUIDED_some_users_idle");
        }

        if (pendingUsers > 0 && claimableUsers == 0) {
            fl.log("GUIDED_all_pending_no_claimable");
        }
        if (fullyEngaged > 0) {
            fl.log("GUIDED_fully_engaged_users_present");
        }
    }

    function _checkWithdrawalFlowStates() private {
        uint256 controllersReady;
        uint256 controllersWaiting;
        uint256 controllersClaimableOnly;

        for (uint256 i = 0; i < USERS.length; i++) {
            address controller = USERS[i];
            ActorState storage snapshot = states[1].actorStates[controller];

            bool hasPending = snapshot.pendingRedeem > 0;
            bool hasClaimable = snapshot.claimableAssets > 0;

            if (hasPending && hasClaimable) {
                controllersReady++;
                fl.log("GUIDED_controller_ready_to_withdraw");
            } else if (hasPending) {
                controllersWaiting++;
                fl.log("GUIDED_controller_waiting_on_reserve");
            } else if (hasClaimable) {
                controllersClaimableOnly++;
                fl.log("GUIDED_controller_claimable_only");
            }
        }

        if (controllersReady == 0 && controllersWaiting == 0 && controllersClaimableOnly == 0) {
            fl.log("GUIDED_no_active_withdrawal_flow");
        }

        uint256 sharesExiting = node.sharesExiting();
        if (sharesExiting == 0) {
            fl.log("GUIDED_no_shares_exiting");
        } else if (sharesExiting < node.totalSupply() / 10) {
            fl.log("GUIDED_low_exit_pressure");
        } else {
            fl.log("GUIDED_high_exit_pressure");
        }
    }

    function _checkReservePreparationStates() private {
        Node nodeImpl = Node(address(node));
        uint64 last = nodeImpl.lastRebalance();
        uint64 window = nodeImpl.rebalanceWindow();
        uint64 cooldown = nodeImpl.rebalanceCooldown();

        if (block.timestamp < last + window) {
            fl.log("GUIDED_rebalance_window_open");
        } else {
            fl.log("GUIDED_rebalance_window_closed");
        }

        uint64 nextWindow = last + window + cooldown;
        if (block.timestamp >= nextWindow) {
            fl.log("GUIDED_rebalance_ready");
        } else {
            fl.log("GUIDED_rebalance_cooldown_active");
        }

        uint256 reserveBalance = asset.balanceOf(address(node));
        uint256 pending = node.convertToAssets(node.sharesExiting());

        if (pending == 0) {
            fl.log("GUIDED_no_pending_assets");
        } else if (reserveBalance >= pending) {
            fl.log("GUIDED_reserve_can_cover_pending");
        } else {
            fl.log("GUIDED_reserve_shortfall");
        }
    }
}
