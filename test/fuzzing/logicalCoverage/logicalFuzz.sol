// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";

contract LogicalFuzz is BeforeAfter {
    function logicalFuzz() internal {
        _checkActorStates();
        _checkIterationProgress();
        _checkProtocolLiquidityPulse();
    }

    function _checkActorStates() private {
        address actor = currentActor;
        if (actor == address(0)) {
            fl.log("FUZZ_actor_zero_address");
            return;
        }

        if (actor == owner) {
            fl.log("FUZZ_actor_owner");
        } else if (actor == rebalancer) {
            fl.log("FUZZ_actor_rebalancer");
        } else if (actor == protocolFeesAddress) {
            fl.log("FUZZ_actor_protocol_fee_target");
        } else if (actor == vaultSeeder) {
            fl.log("FUZZ_actor_vault_seeder");
        }

        bool registered;
        for (uint256 i = 0; i < USERS.length; i++) {
            if (USERS[i] == actor) {
                registered = true;
                break;
            }
        }
        if (registered) {
            fl.log("FUZZ_actor_registered_user");
        } else {
            fl.log("FUZZ_actor_external");
        }

        ActorState storage snapshot = states[1].actorStates[actor];
        if (snapshot.shareBalance > 0) {
            fl.log("FUZZ_actor_holds_node_shares");
        } else {
            fl.log("FUZZ_actor_no_node_shares");
        }

        if (snapshot.pendingRedeem > 0) {
            fl.log("FUZZ_actor_pending_redeem");
        }
        if (snapshot.claimableRedeem > 0) {
            fl.log("FUZZ_actor_claimable_shares");
        }
        if (snapshot.claimableAssets > 0) {
            fl.log("FUZZ_actor_claimable_assets");
        }

        if (snapshot.assetBalance == 0) {
            fl.log("FUZZ_actor_zero_asset_balance");
        } else if (snapshot.assetBalance < 100e18) {
            fl.log("FUZZ_actor_low_asset_balance");
        } else {
            fl.log("FUZZ_actor_high_asset_balance");
        }
    }

    function _checkIterationProgress() private {
        if (iteration % 10 == 0) {
            fl.log("FUZZ_iteration_multiple_of_ten");
        }
        if (iteration % 25 == 0) {
            fl.log("FUZZ_iteration_multiple_of_twentyfive");
        }
        if (iteration % 100 == 0) {
            fl.log("FUZZ_iteration_century_marker");
        }

        if (iteration < 50) {
            fl.log("FUZZ_iteration_early_phase");
        } else if (iteration < 200) {
            fl.log("FUZZ_iteration_growth_phase");
        } else {
            fl.log("FUZZ_iteration_late_phase");
        }

        if (block.timestamp == lastTimestamp) {
            fl.log("FUZZ_timestamp_frozen");
        } else if (block.timestamp > lastTimestamp) {
            fl.log("FUZZ_timestamp_advanced");
        } else {
            fl.log("FUZZ_timestamp_regressed");
        }
    }

    function _checkProtocolLiquidityPulse() private {
        if (address(node) == address(0)) {
            fl.log("FUZZ_node_not_assigned");
            return;
        }

        uint256 reserveBalance = asset.balanceOf(address(node));
        uint256 escrowBalance = asset.balanceOf(address(escrow));
        uint256 totalAssets = node.totalAssets();
        uint256 totalSupply = node.totalSupply();
        uint256 cashAfterRedemptions = node.getCashAfterRedemptions();
        uint64 targetReserve = node.targetReserveRatio();
        uint256 actualRatio = totalAssets == 0 ? 0 : (cashAfterRedemptions * 1e18) / totalAssets;

        if (reserveBalance == 0) {
            fl.log("FUZZ_reserve_empty");
        } else if (reserveBalance < 1_000e18) {
            fl.log("FUZZ_reserve_thin");
        } else {
            fl.log("FUZZ_reserve_healthy");
        }

        if (escrowBalance == 0) {
            fl.log("FUZZ_escrow_dry");
        } else {
            fl.log("FUZZ_escrow_funded");
        }

        if (totalAssets == 0) {
            fl.log("FUZZ_node_zero_assets");
        } else if (totalAssets <= reserveBalance) {
            fl.log("FUZZ_assets_fully_in_reserve");
        }

        if (totalSupply == 0) {
            fl.log("FUZZ_node_zero_supply");
        } else if (totalSupply > reserveBalance && reserveBalance > 0) {
            fl.log("FUZZ_supply_backed_by_reserve");
        }

        if (actualRatio < targetReserve) {
            fl.log("FUZZ_reserve_below_target");
        } else if (actualRatio > targetReserve) {
            fl.log("FUZZ_reserve_above_target");
        } else {
            fl.log("FUZZ_reserve_on_target");
        }
    }
}
