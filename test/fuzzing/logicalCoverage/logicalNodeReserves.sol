// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";

contract LogicalNodeReserves is BeforeAfter {
    function logicalNodeReserves() internal {
        if (address(node) == address(0)) {
            fl.log("NODE_RES_node_missing");
            return;
        }

        _checkReserveCoverageStates();
        _checkEscrowLinkStates();
        _checkRequestCoverageStates();
    }

    function _checkReserveCoverageStates() private {
        uint256 totalAssets = node.totalAssets();
        uint256 reserveBalance = asset.balanceOf(address(node));
        uint256 sharesExiting = node.sharesExiting();
        uint256 pendingAssets = sharesExiting == 0 ? 0 : node.convertToAssets(sharesExiting);
        uint256 cashAfterRedemptions = node.getCashAfterRedemptions();
        uint64 targetReserveRatio = node.targetReserveRatio();

        if (totalAssets == 0) {
            fl.log("NODE_RES_zero_total_assets");
        } else {
            uint256 reserveRatio = (cashAfterRedemptions * 1e18) / totalAssets;
            if (reserveRatio < targetReserveRatio) {
                fl.log("NODE_RES_ratio_below_target");
            } else if (reserveRatio == targetReserveRatio) {
                fl.log("NODE_RES_ratio_on_target");
            } else {
                fl.log("NODE_RES_ratio_above_target");
            }
        }

        if (reserveBalance == 0) {
            fl.log("NODE_RES_reserve_empty");
        } else if (reserveBalance < 10_000 ether) {
            fl.log("NODE_RES_reserve_thin");
        } else {
            fl.log("NODE_RES_reserve_weighted");
        }

        if (cashAfterRedemptions >= pendingAssets) {
            fl.log("NODE_RES_cash_covers_pending");
        } else if (pendingAssets > 0) {
            fl.log("NODE_RES_cash_shortfall");
        }

        if (pendingAssets == 0) {
            fl.log("NODE_RES_no_pending_assets");
        } else if (pendingAssets < reserveBalance) {
            fl.log("NODE_RES_pending_below_reserve");
        } else {
            fl.log("NODE_RES_pending_above_reserve");
        }
    }

    function _checkEscrowLinkStates() private {
        address escrowAddr = address(escrow);

        if (escrowAddr == address(0)) {
            fl.log("NODE_RES_escrow_missing");
            return;
        }

        if (MANAGED_NODE_ESCROWS[address(node)] == escrowAddr) {
            fl.log("NODE_RES_escrow_registered");
        } else {
            fl.log("NODE_RES_escrow_untracked");
        }

        uint256 escrowBalance = asset.balanceOf(escrowAddr);
        if (escrowBalance == 0) {
            fl.log("NODE_RES_escrow_empty");
        } else if (escrowBalance < 1_000 ether) {
            fl.log("NODE_RES_escrow_low_balance");
        } else {
            fl.log("NODE_RES_escrow_buffered");
        }

        uint256 allowance = asset.allowance(escrowAddr, address(node));
        if (allowance == type(uint256).max) {
            fl.log("NODE_RES_escrow_unlimited_allowance");
        } else if (allowance > 0) {
            fl.log("NODE_RES_escrow_partial_allowance");
        } else {
            fl.log("NODE_RES_escrow_no_allowance");
        }

        if (states[1].nodeEscrowAssetBalance > states[0].nodeEscrowAssetBalance) {
            fl.log("NODE_RES_escrow_balance_increased");
        } else if (states[1].nodeEscrowAssetBalance < states[0].nodeEscrowAssetBalance) {
            fl.log("NODE_RES_escrow_balance_decreased");
        }
    }

    function _checkRequestCoverageStates() private {
        uint256 totalPending;
        uint256 totalClaimableShares;
        uint256 totalClaimableAssets;
        uint256 usersWaiting;
        uint256 usersClaimableOnly;

        for (uint256 i = 0; i < USERS.length; i++) {
            address controller = USERS[i];
            (uint256 pending, uint256 claimableShares, uint256 claimableAssets) = node.requests(controller);

            if (pending > 0) {
                totalPending += pending;
                usersWaiting++;
                if (claimableAssets == 0) {
                    fl.log("NODE_RES_controller_waiting_liquidity");
                }
            }
            if (claimableAssets > 0 || claimableShares > 0) {
                totalClaimableShares += claimableShares;
                totalClaimableAssets += claimableAssets;
                if (pending == 0) {
                    usersClaimableOnly++;
                    fl.log("NODE_RES_controller_ready_to_withdraw");
                }
            }
        }

        if (usersWaiting == 0 && usersClaimableOnly == 0) {
            fl.log("NODE_RES_no_queue_pressure");
        } else if (usersWaiting > usersClaimableOnly) {
            fl.log("NODE_RES_waiting_dominates");
        } else if (usersClaimableOnly > 0) {
            fl.log("NODE_RES_claimable_dominates");
        }

        if (totalPending > totalClaimableShares && totalClaimableShares > 0) {
            fl.log("NODE_RES_partial_fulfillment_state");
        }

        if (totalClaimableAssets > asset.balanceOf(address(escrow))) {
            fl.log("NODE_RES_claimable_exceeds_escrow");
        } else if (totalClaimableAssets > 0) {
            fl.log("NODE_RES_claimable_backed_by_escrow");
        }
    }
}
