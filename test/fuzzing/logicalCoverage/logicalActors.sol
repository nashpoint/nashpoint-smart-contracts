// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LogicalActors is BeforeAfter {
    function logicalActors() internal {
        if (USERS.length == 0) {
            fl.log("ACTOR_no_users_initialized");
            return;
        }

        _checkActorRoleStates();
        _checkActorAllowanceStates();
        _checkActorRequestHealthStates();
    }

    function _checkActorRoleStates() private {
        uint256 owners;
        uint256 rebalancers;
        uint256 plainUsers;

        for (uint256 i = 0; i < USERS.length; i++) {
            address actor = USERS[i];
            if (actor == owner) {
                owners++;
                fl.log("ACTOR_owner_in_user_set");
            } else if (actor == rebalancer) {
                rebalancers++;
                fl.log("ACTOR_rebalancer_in_user_set");
            } else {
                plainUsers++;
            }

            if (node.isOperator(actor, actor)) {
                fl.log("ACTOR_self_operator");
            }
        }

        if (owners == 0) {
            fl.log("ACTOR_owner_not_in_users");
        }
        if (rebalancers == 0) {
            fl.log("ACTOR_rebalancer_not_in_users");
        }
        if (plainUsers == 0) {
            fl.log("ACTOR_no_plain_users");
        }
    }

    function _checkActorAllowanceStates() private {
        if (address(node) == address(0)) {
            return;
        }

        uint256 fullyAllowanced;
        uint256 missingAllowance;

        for (uint256 i = 0; i < USERS.length; i++) {
            address actor = USERS[i];
            uint256 allowanceToNode = asset.allowance(actor, address(node));
            uint256 allowanceToRouter4626 = IERC20(address(node)).allowance(actor, address(router4626));

            if (allowanceToNode > 0) {
                fullyAllowanced++;
                fl.log("ACTOR_has_node_asset_allowance");
            } else {
                missingAllowance++;
                fl.log("ACTOR_missing_node_asset_allowance");
            }

            if (allowanceToRouter4626 > 0) {
                fl.log("ACTOR_node_share_router_allowance");
            }
        }

        if (missingAllowance == USERS.length) {
            fl.log("ACTOR_no_allowances_set");
        } else if (fullyAllowanced == USERS.length) {
            fl.log("ACTOR_all_allowances_ready");
        }
    }

    function _checkActorRequestHealthStates() private {
        uint256 controllersOverCommitted;
        uint256 controllersFullySettled;
        uint256 controllersWithClaimsOnly;

        for (uint256 i = 0; i < USERS.length; i++) {
            address actor = USERS[i];
            ActorState storage snapshot = states[1].actorStates[actor];

            if (snapshot.pendingRedeem == 0 && snapshot.claimableAssets == 0 && snapshot.claimableRedeem == 0) {
                controllersFullySettled++;
            }
            if (snapshot.pendingRedeem > 0 && snapshot.claimableAssets == 0) {
                controllersOverCommitted++;
                fl.log("ACTOR_pending_without_claimable");
            }
            if (snapshot.pendingRedeem == 0 && (snapshot.claimableAssets > 0 || snapshot.claimableRedeem > 0)) {
                controllersWithClaimsOnly++;
                fl.log("ACTOR_ready_to_withdraw_claimable");
            }

            if (snapshot.pendingRedeem > snapshot.shareBalance) {
                fl.log("ACTOR_pending_exceeds_balance");
            }
            if (snapshot.claimableRedeem > snapshot.shareBalance + snapshot.claimableRedeem) {
                fl.log("ACTOR_claimable_shares_anomaly");
            }
        }

        if (controllersFullySettled == USERS.length) {
            fl.log("ACTOR_all_controllers_idle");
        }
        if (controllersOverCommitted > controllersWithClaimsOnly) {
            fl.log("ACTOR_more_waiting_than_claimable");
        }
    }
}
