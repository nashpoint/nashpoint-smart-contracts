// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC7575} from "../../../src/interfaces/IERC7575.sol";
import {IERC7540Redeem} from "../../../src/interfaces/IERC7540.sol";

contract LogicalRouters is BeforeAfter {
    function logicalRouters() internal {
        _checkRouterWhitelistStates();
        _checkRouterToleranceStates();
        _checkRouterBlacklistCoverage();
        _checkRouter4626Components();
        _checkRouter7540Components();
        _checkRouterOneInchIntegration();
    }

    function _checkRouterWhitelistStates() private {
        uint256 w4626;
        for (uint256 i = 0; i < COMPONENTS_ERC4626.length; i++) {
            address component = COMPONENTS_ERC4626[i];
            if (router4626.isWhitelisted(component)) {
                w4626++;
            } else {
                fl.log("ROUTER_component_not_whitelisted_4626");
            }
        }
        if (COMPONENTS_ERC4626.length > 0 && w4626 == COMPONENTS_ERC4626.length) {
            fl.log("ROUTER_all_4626_components_whitelisted");
        }

        uint256 w7540;
        for (uint256 i = 0; i < COMPONENTS_ERC7540.length; i++) {
            address component = COMPONENTS_ERC7540[i];
            if (router7540.isWhitelisted(component)) {
                w7540++;
            } else {
                fl.log("ROUTER_component_not_whitelisted_7540");
            }
        }
        if (COMPONENTS_ERC7540.length > 0 && w7540 == COMPONENTS_ERC7540.length) {
            fl.log("ROUTER_all_7540_components_whitelisted");
        }
    }

    function _checkRouterToleranceStates() private {
        uint256 tol4626 = router4626.tolerance();
        uint256 tol7540 = router7540.tolerance();
        uint256 tolOneInch = routerOneInch.tolerance();

        if (tol4626 == 0) {
            fl.log("ROUTER_4626_zero_tolerance");
        } else if (tol4626 <= 1) {
            fl.log("ROUTER_4626_min_tolerance");
        } else {
            fl.log("ROUTER_4626_custom_tolerance");
        }

        if (tol7540 == 0) {
            fl.log("ROUTER_7540_zero_tolerance");
        } else if (tol7540 > 1e4) {
            fl.log("ROUTER_7540_high_tolerance");
        } else {
            fl.log("ROUTER_7540_controlled_tolerance");
        }

        if (tolOneInch == 0) {
            fl.log("ROUTER_ONEINCH_zero_tolerance");
        } else {
            fl.log("ROUTER_ONEINCH_tolerance_configured");
        }
    }

    function _checkRouterBlacklistCoverage() private {
        if (REMOVABLE_COMPONENTS.length == 0) {
            return;
        }

        bool anyBlacklisted;
        for (uint256 i = 0; i < REMOVABLE_COMPONENTS.length; i++) {
            address component = REMOVABLE_COMPONENTS[i];
            if (router4626.isBlacklisted(component) || router7540.isBlacklisted(component)) {
                anyBlacklisted = true;
                fl.log("ROUTER_component_blacklisted");
            }
        }

        if (!anyBlacklisted) {
            fl.log("ROUTER_no_blacklisted_components");
        }
    }

    function _checkRouter4626Components() private {
        if (address(node) == address(0)) {
            return;
        }

        uint256 componentsTracked = COMPONENTS_ERC4626.length;
        if (componentsTracked == 0) {
            fl.log("ROUTER_4626_no_components_tracked");
            return;
        }

        for (uint256 i = 0; i < componentsTracked; i++) {
            address component = COMPONENTS_ERC4626[i];
            uint256 balance = IERC20(component).balanceOf(address(node));
            if (balance == 0) {
                fl.log("ROUTER_4626_component_empty_balance");
            } else if (balance < 100e18) {
                fl.log("ROUTER_4626_component_low_balance");
            } else {
                fl.log("ROUTER_4626_component_healthy_balance");
            }

            if (router4626.isBlacklisted(component)) {
                fl.log("ROUTER_4626_component_blacklisted");
            }

            uint256 maxDeposit = IERC4626(component).maxDeposit(address(node));
            if (maxDeposit == type(uint256).max) {
                fl.log("ROUTER_4626_unbounded_max_deposit");
            } else if (maxDeposit == 0) {
                fl.log("ROUTER_4626_max_deposit_zero");
            } else {
                fl.log("ROUTER_4626_max_deposit_limited");
            }
        }
    }

    function _checkRouter7540Components() private {
        if (address(node) == address(0)) {
            return;
        }
        if (COMPONENTS_ERC7540.length == 0) {
            fl.log("ROUTER_7540_no_components_tracked");
            return;
        }

        for (uint256 i = 0; i < COMPONENTS_ERC7540.length; i++) {
            address component = COMPONENTS_ERC7540[i];
            address shareToken = IERC7575(component).share();
            uint256 shareBalance = IERC20(shareToken).balanceOf(address(node));

            if (shareBalance == 0) {
                fl.log("ROUTER_7540_share_balance_zero");
            } else {
                fl.log("ROUTER_7540_share_balance_positive");
            }

            uint256 pending = IERC7540Redeem(component).pendingRedeemRequest(0, address(node));
            uint256 claimable = IERC7540Redeem(component).claimableRedeemRequest(0, address(node));

            if (pending > 0) {
                fl.log("ROUTER_7540_pending_requests");
            }
            if (claimable > 0) {
                fl.log("ROUTER_7540_claimable_requests");
            }
            if (pending > 0 && claimable == 0) {
                fl.log("ROUTER_7540_waiting_settlement");
            }

            uint256 maxMint = IERC7575(component).maxMint(address(node));
            if (maxMint == 0) {
                fl.log("ROUTER_7540_max_mint_zero");
            } else if (maxMint < shareBalance) {
                fl.log("ROUTER_7540_max_mint_below_holdings");
            } else {
                fl.log("ROUTER_7540_max_mint_healthy");
            }

            if (router7540.isBlacklisted(component)) {
                fl.log("ROUTER_7540_component_blacklisted");
            }
        }
    }

    function _checkRouterOneInchIntegration() private {
        if (address(routerOneInch) == address(0)) {
            fl.log("ROUTER_ONEINCH_missing");
            return;
        }

        if (routerOneInch.ONE_INCH_AGGREGATION_ROUTER_V6() == address(0)) {
            fl.log("ROUTER_ONEINCH_aggregation_missing");
        } else {
            fl.log("ROUTER_ONEINCH_aggregation_defined");
        }

        if (routerOneInch.tolerance() == 0) {
            fl.log("ROUTER_ONEINCH_zero_tolerance");
        }

        address nodeAsset = address(asset);
        uint256 incentiveBalance = IERC20(nodeAsset).balanceOf(address(node));
        if (incentiveBalance == 0) {
            fl.log("ROUTER_ONEINCH_node_no_asset_balance");
        } else {
            fl.log("ROUTER_ONEINCH_node_holds_assets");
        }
    }
}
