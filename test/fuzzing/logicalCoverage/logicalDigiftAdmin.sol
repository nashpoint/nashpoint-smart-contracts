// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";

contract LogicalDigiftAdmin is BeforeAfter {
    function logicalDigiftAdmin() internal {
        if (address(digiftAdapter) == address(0)) {
            fl.log("DIGIFT_ADMIN_adapter_missing");
            return;
        }

        _checkDigiftParameterStates();
        _checkDigiftAccessStates();
        _checkDigiftFactoryState();
    }

    // NOTE: priceUpdateDeviation was split into priceUpdateDeviationDigift and priceUpdateDeviationAsset
    function _checkDigiftParameterStates() private {
        uint256 minDeposit = digiftAdapter.minDepositAmount();
        uint256 minRedeem = digiftAdapter.minRedeemAmount();
        uint64 priceDeviation = digiftAdapter.priceDeviation();
        uint64 settlementDeviation = digiftAdapter.settlementDeviation();
        uint64 priceUpdateDeviationDigift = digiftAdapter.priceUpdateDeviationDigift();
        uint64 priceUpdateDeviationAsset = digiftAdapter.priceUpdateDeviationAsset();

        if (minDeposit == 0) {
            fl.log("DIGIFT_ADMIN_min_deposit_zero");
        } else {
            fl.log("DIGIFT_ADMIN_min_deposit_set");
        }

        if (minRedeem == 0) {
            fl.log("DIGIFT_ADMIN_min_redeem_zero");
        } else {
            fl.log("DIGIFT_ADMIN_min_redeem_set");
        }

        if (priceDeviation == 0) {
            fl.log("DIGIFT_ADMIN_price_deviation_zero");
        } else {
            fl.log("DIGIFT_ADMIN_price_deviation_set");
        }

        if (settlementDeviation == 0) {
            fl.log("DIGIFT_ADMIN_settlement_deviation_zero");
        } else {
            fl.log("DIGIFT_ADMIN_settlement_deviation_set");
        }

        if (priceUpdateDeviationDigift == 0 || priceUpdateDeviationAsset == 0) {
            fl.log("DIGIFT_ADMIN_price_update_window_zero");
        } else {
            fl.log("DIGIFT_ADMIN_price_update_window_set");
        }
    }

    function _checkDigiftAccessStates() private {
        if (digiftAdapter.managerWhitelisted(rebalancer)) {
            fl.log("DIGIFT_ADMIN_rebalancer_whitelisted");
        } else {
            fl.log("DIGIFT_ADMIN_rebalancer_not_whitelisted");
        }

        if (digiftAdapter.managerWhitelisted(owner)) {
            fl.log("DIGIFT_ADMIN_owner_whitelisted");
        }

        if (address(node) != address(0)) {
            if (digiftAdapter.nodeWhitelisted(address(node))) {
                fl.log("DIGIFT_ADMIN_node_whitelisted");
            } else {
                fl.log("DIGIFT_ADMIN_node_not_whitelisted");
            }
        }

        if (address(digiftEventVerifier) != address(0)) {
            if (digiftEventVerifier.whitelist(address(digiftAdapter))) {
                fl.log("DIGIFT_ADMIN_verifier_whitelists_adapter");
            } else {
                fl.log("DIGIFT_ADMIN_verifier_missing_adapter");
            }
        }
    }

    function _checkDigiftFactoryState() private {
        if (address(digiftFactory) == address(0)) {
            fl.log("DIGIFT_ADMIN_factory_missing");
            return;
        }

        if (digiftFactory.implementation() == address(0)) {
            fl.log("DIGIFT_ADMIN_factory_implementation_missing");
        } else {
            fl.log("DIGIFT_ADMIN_factory_implementation_set");
        }

        if (digiftFactory.owner() == owner) {
            fl.log("DIGIFT_ADMIN_factory_owned_by_protocol");
        } else {
            fl.log("DIGIFT_ADMIN_factory_custom_owner");
        }
    }
}
