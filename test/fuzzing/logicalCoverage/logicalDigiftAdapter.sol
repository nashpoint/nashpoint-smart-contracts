// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LogicalDigiftAdapter is BeforeAfter {
    function logicalDigiftAdapter() internal {
        if (address(digiftAdapter) == address(0)) {
            fl.log("DIGIFT_adapter_missing");
            return;
        }

        _checkDigiftInventoryStates();
        _checkDigiftRequestQueues();
        _checkDigiftNodeHoldings();
        _checkDigiftLimitStates();
        _checkDigiftConversionSample();
    }

    function _checkDigiftInventoryStates() private {
        uint256 totalSupply = digiftAdapter.totalSupply();
        uint256 totalAssets = digiftAdapter.totalAssets();
        uint256 nodeShares = digiftAdapter.balanceOf(address(node));
        uint256 adapterAssetBalance = IERC20(digiftAdapter.asset()).balanceOf(address(digiftAdapter));

        if (totalSupply == 0) {
            fl.log("DIGIFT_zero_supply");
        } else {
            fl.log("DIGIFT_supply_active");
        }

        if (totalAssets == 0) {
            fl.log("DIGIFT_zero_assets");
        } else {
            fl.log("DIGIFT_assets_under_management");
        }

        if (nodeShares == 0) {
            fl.log("DIGIFT_node_zero_shares");
        } else if (nodeShares > totalSupply / 2 && totalSupply > 0) {
            fl.log("DIGIFT_node_majority_holder");
        } else {
            fl.log("DIGIFT_node_partial_holder");
        }

        if (adapterAssetBalance == 0) {
            fl.log("DIGIFT_adapter_empty");
        } else {
            fl.log("DIGIFT_adapter_funded");
        }
    }

    function _checkDigiftRequestQueues() private {
        uint256 pendingDeposits = DIGIFT_PENDING_DEPOSITS.length;
        uint256 forwardedDeposits = DIGIFT_FORWARDED_DEPOSITS.length;
        uint256 pendingRedemptions = DIGIFT_PENDING_REDEMPTIONS.length;
        uint256 forwardedRedemptions = DIGIFT_FORWARDED_REDEMPTIONS.length;

        if (pendingDeposits == 0) {
            fl.log("DIGIFT_no_pending_deposits");
        } else {
            fl.log("DIGIFT_pending_deposits_exist");
        }
        if (forwardedDeposits > 0) {
            fl.log("DIGIFT_forwarded_deposits_exist");
        }

        if (pendingRedemptions == 0) {
            fl.log("DIGIFT_no_pending_redemptions");
        } else {
            fl.log("DIGIFT_pending_redemptions_exist");
        }
        if (forwardedRedemptions > 0) {
            fl.log("DIGIFT_forwarded_redemptions_exist");
        }

        if (digiftAdapter.accumulatedDeposit() > 0) {
            fl.log("DIGIFT_accumulated_deposits_buffer");
        }
        if (digiftAdapter.accumulatedRedemption() > 0) {
            fl.log("DIGIFT_accumulated_redemptions_buffer");
        }
        if (digiftAdapter.globalPendingDepositRequest() > 0) {
            fl.log("DIGIFT_global_pending_deposit");
        }
        if (digiftAdapter.globalPendingRedeemRequest() > 0) {
            fl.log("DIGIFT_global_pending_redeem");
        }
    }

    function _checkDigiftNodeHoldings() private {
        if (address(node) == address(0)) {
            return;
        }

        uint256 nodePendingDeposit = digiftAdapter.pendingDepositRequest(0, address(node));
        uint256 nodeClaimableDeposit = digiftAdapter.claimableDepositRequest(0, address(node));
        uint256 nodePendingRedeem = digiftAdapter.pendingRedeemRequest(0, address(node));
        uint256 nodeClaimableRedeem = digiftAdapter.claimableRedeemRequest(0, address(node));

        if (nodePendingDeposit > 0) {
            fl.log("DIGIFT_node_pending_deposit");
        }
        if (nodeClaimableDeposit > 0) {
            fl.log("DIGIFT_node_claimable_deposit");
        }
        if (nodePendingRedeem > 0) {
            fl.log("DIGIFT_node_pending_redeem");
        }
        if (nodeClaimableRedeem > 0) {
            fl.log("DIGIFT_node_claimable_redeem");
        }
    }

    function _checkDigiftLimitStates() private {
        uint256 minDeposit = digiftAdapter.minDepositAmount();
        uint256 minRedeem = digiftAdapter.minRedeemAmount();

        if (minDeposit == 0) {
            fl.log("DIGIFT_min_deposit_zero");
        } else if (minDeposit < 1_000e6) {
            fl.log("DIGIFT_min_deposit_low");
        } else {
            fl.log("DIGIFT_min_deposit_high");
        }

        if (minRedeem == 0) {
            fl.log("DIGIFT_min_redeem_zero");
        } else if (minRedeem < 1_000e18) {
            fl.log("DIGIFT_min_redeem_low");
        } else {
            fl.log("DIGIFT_min_redeem_high");
        }

        if (address(node) != address(0)) {
            uint256 nodeMaxMint = digiftAdapter.maxMint(address(node));
            uint256 nodeMaxWithdraw = digiftAdapter.maxWithdraw(address(node));

            if (nodeMaxMint == 0) {
                fl.log("DIGIFT_node_max_mint_zero");
            } else {
                fl.log("DIGIFT_node_max_mint_available");
            }

            if (nodeMaxWithdraw == 0) {
                fl.log("DIGIFT_node_max_withdraw_zero");
            } else {
                fl.log("DIGIFT_node_max_withdraw_available");
            }
        }
    }

    function _checkDigiftConversionSample() private {
        uint256 sampleShares = 1e18;
        uint256 sampleAssets = 1e6;

        try digiftAdapter.convertToAssets(sampleShares) returns (uint256 assetsFromShares) {
            if (assetsFromShares == 0) {
                fl.log("DIGIFT_price_zero");
            } else {
                fl.log("DIGIFT_price_active");
            }
        } catch {
            fl.log("DIGIFT_price_unavailable");
        }

        try digiftAdapter.convertToShares(sampleAssets) returns (uint256 sharesFromAssets) {
            if (sharesFromAssets == 0) {
                fl.log("DIGIFT_conversion_zero_shares");
            } else {
                fl.log("DIGIFT_conversion_positive_shares");
            }
        } catch {
            fl.log("DIGIFT_conversion_unavailable");
        }
    }
}
