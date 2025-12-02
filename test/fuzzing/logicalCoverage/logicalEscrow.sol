// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {Escrow} from "../../../src/Escrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LogicalEscrow is BeforeAfter {
    function logicalEscrow() internal {
        if (address(escrow) == address(0)) {
            fl.log("ESCROW_missing_instance");
            return;
        }

        _checkEscrowNodeBinding();
        _checkEscrowBalances();
        _checkEscrowAllowances();
        _checkEscrowLedgerStates();
    }

    function _checkEscrowNodeBinding() private {
        address boundNode = Escrow(address(escrow)).node();
        if (boundNode == address(node)) {
            fl.log("ESCROW_bound_to_active_node");
        } else if (boundNode == address(0)) {
            fl.log("ESCROW_unbound");
        } else {
            fl.log("ESCROW_bound_to_other_node");
        }
    }

    function _checkEscrowBalances() private {
        uint256 assetBalance = asset.balanceOf(address(escrow));
        uint256 shareBalance = node.balanceOf(address(escrow));

        if (assetBalance == 0) {
            fl.log("ESCROW_zero_asset_balance");
        } else if (assetBalance < 1_000 ether) {
            fl.log("ESCROW_low_asset_balance");
        } else {
            fl.log("ESCROW_high_asset_balance");
        }

        if (shareBalance == 0) {
            fl.log("ESCROW_zero_share_balance");
        } else {
            fl.log("ESCROW_holds_shares");
        }
    }

    function _checkEscrowAllowances() private {
        uint256 allowanceToNode = asset.allowance(address(escrow), address(node));
        if (allowanceToNode == type(uint256).max) {
            fl.log("ESCROW_unbounded_asset_allowance");
        } else if (allowanceToNode > 0) {
            fl.log("ESCROW_partial_asset_allowance");
        } else {
            fl.log("ESCROW_no_asset_allowance");
        }

        uint256 shareAllowance = IERC20(address(node)).allowance(address(escrow), address(node));
        if (shareAllowance > 0) {
            fl.log("ESCROW_share_allowance_set");
        } else {
            fl.log("ESCROW_share_allowance_zero");
        }
    }

    function _checkEscrowLedgerStates() private {
        uint256 claimableAssets = states[1].actorStates[address(escrow)].claimableAssets;
        uint256 pendingRedeem = states[1].actorStates[address(escrow)].pendingRedeem;

        if (claimableAssets > 0) {
            fl.log("ESCROW_claimable_assets_recorded");
        }
        if (pendingRedeem > 0) {
            fl.log("ESCROW_pending_redeem_recorded");
        }

        if (claimableAssets == 0 && pendingRedeem == 0) {
            fl.log("ESCROW_idle_state");
        }
    }
}
