// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {IERC7575} from "../../../src/interfaces/IERC7575.sol";
import {INode} from "../../../src/interfaces/INode.sol";

contract LogicalPolicies is BeforeAfter {
    bytes4 internal constant SELECTOR_DEPOSIT = IERC7575.deposit.selector;
    bytes4 internal constant SELECTOR_WITHDRAW = IERC7575.withdraw.selector;
    bytes4 internal constant SELECTOR_REQUEST_REDEEM = INode.requestRedeem.selector;
    bytes4 internal constant SELECTOR_START_REBALANCE = INode.startRebalance.selector;

    function logicalPolicies() internal {
        _checkCapPolicyStates();
        _checkGatePolicyWhitelistStates();
        _checkNodePausingPolicyStates();
        _checkProtocolPausingPolicyStates();
        // NOTE: TransferPolicy has been removed and merged into GatePolicyWhitelist/GatePolicyBlacklist
    }

    function _checkCapPolicyStates() private {
        if (address(capPolicy) == address(0) || address(node) == address(0)) {
            return;
        }

        uint256 cap = capPolicy.nodeCap(address(node));
        if (cap == 0) {
            fl.log("POL_cap_disabled");
        } else {
            uint256 totalAssets = node.totalAssets();
            if (totalAssets >= cap) {
                fl.log("POL_cap_reached");
            } else if (cap - totalAssets < cap / 10) {
                fl.log("POL_cap_nearing");
            } else {
                fl.log("POL_cap_headroom_available");
            }
        }
    }

    function _checkGatePolicyWhitelistStates() private {
        if (address(gatePolicyWhitelist) == address(0) || address(node) == address(0)) {
            return;
        }

        uint256 whitelistedUsers;
        uint256 nonWhitelistedUsers;

        for (uint256 i = 0; i < USERS.length; i++) {
            address user = USERS[i];
            // NOTE: whitelist was renamed to list in ListBase
            if (gatePolicyWhitelist.list(address(node), user)) {
                whitelistedUsers++;
                fl.log("POL_gate_user_whitelisted");
            } else {
                nonWhitelistedUsers++;
            }
        }

        if (whitelistedUsers == 0) {
            fl.log("POL_gate_no_whitelisted_users");
        } else if (nonWhitelistedUsers == 0) {
            fl.log("POL_gate_all_users_whitelisted");
        } else {
            fl.log("POL_gate_partial_whitelist");
        }
    }

    function _checkNodePausingPolicyStates() private {
        if (address(nodePausingPolicy) == address(0) || address(node) == address(0)) {
            return;
        }

        bool globalPause = nodePausingPolicy.globalPause(address(node));
        if (globalPause) {
            fl.log("POL_node_pause_global");
        } else {
            fl.log("POL_node_pause_cleared");
        }

        bool depositPaused = nodePausingPolicy.sigPause(address(node), SELECTOR_DEPOSIT);
        bool withdrawPaused = nodePausingPolicy.sigPause(address(node), SELECTOR_WITHDRAW);
        bool rebalancePaused = nodePausingPolicy.sigPause(address(node), SELECTOR_START_REBALANCE);

        if (depositPaused) {
            fl.log("POL_node_pause_deposit");
        }
        if (withdrawPaused) {
            fl.log("POL_node_pause_withdraw");
        }
        if (rebalancePaused) {
            fl.log("POL_node_pause_rebalance");
        }

        if (!globalPause && !depositPaused && !withdrawPaused && !rebalancePaused) {
            fl.log("POL_node_pause_idle");
        }
    }

    function _checkProtocolPausingPolicyStates() private {
        if (address(protocolPausingPolicy) == address(0)) {
            return;
        }

        if (protocolPausingPolicy.globalPause()) {
            fl.log("POL_protocol_pause_global");
        } else {
            fl.log("POL_protocol_pause_inactive");
        }

        if (protocolPausingPolicy.sigPause(SELECTOR_DEPOSIT)) {
            fl.log("POL_protocol_pause_deposit");
        }
        if (protocolPausingPolicy.sigPause(SELECTOR_WITHDRAW)) {
            fl.log("POL_protocol_pause_withdraw");
        }
        if (protocolPausingPolicy.sigPause(SELECTOR_REQUEST_REDEEM)) {
            fl.log("POL_protocol_pause_requestRedeem");
        }

        if (protocolPausingPolicy.whitelist(owner)) {
            fl.log("POL_protocol_owner_whitelisted");
        }
        if (protocolPausingPolicy.whitelist(rebalancer)) {
            fl.log("POL_protocol_rebalancer_whitelisted");
        }
    }

    // NOTE: TransferPolicy has been removed in the remediation commit
    // function _checkTransferPolicyStates() private {
    //     ... removed ...
    // }
}
