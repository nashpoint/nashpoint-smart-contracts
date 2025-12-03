// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import {ComponentAllocation} from "../../../src/interfaces/INode.sol";
import {Escrow} from "../../../src/Escrow.sol";

contract LogicalCoverageBase is BeforeAfter {
    bool internal constant LOGICAL_COVERAGE_ENABLED = true;

    function checkLogicalCoverage(bool enable) internal {
        if (!(enable && LOGICAL_COVERAGE_ENABLED)) {
            return;
        }

        _logicalNode();
        _logicalNodeReserves();
        _logicalNodeFactory();
        _logicalRewardRouters();
        _logicalDigiftAdapter();
        _logicalEscrow();
    }

    // ============ Node ============

    function _logicalNode() private {
        if (address(node) == address(0)) {
            fl.log("NODE_uninitialized");
            return;
        }

        uint256 totalAssets = node.totalAssets();
        uint256 totalSupply = node.totalSupply();
        uint256 sharesExiting = node.sharesExiting();

        if (totalAssets == 0) {
            fl.log("NODE_zero_total_assets");
        }
        if (totalSupply == 0) {
            fl.log("NODE_zero_total_supply");
        }
        if (sharesExiting > 0 && totalSupply > 0 && sharesExiting * 10 > totalSupply) {
            fl.log("NODE_high_exit_pressure");
        }

        // Redemption requests
        uint256 usersWithPending;
        uint256 usersWithClaimable;
        for (uint256 i = 0; i < USERS.length; i++) {
            (uint256 pending, uint256 claimableShares, uint256 claimableAssets) = node.requests(USERS[i]);
            if (pending > 0) usersWithPending++;
            if (claimableAssets > 0 || claimableShares > 0) usersWithClaimable++;
        }
        if (usersWithPending > 0) fl.log("NODE_pending_requests_exist");
        if (usersWithClaimable > 0) fl.log("NODE_claimable_available");
        if (usersWithPending > USERS.length / 2 && USERS.length > 0) fl.log("NODE_majority_pending_requests");

        // Component allocation
        address[] memory activeComponents = node.getComponents();
        if (activeComponents.length == 0) {
            fl.log("NODE_no_active_components");
        } else {
            uint256 asyncCount;
            uint256 highWeightCount;
            for (uint256 i = 0; i < activeComponents.length; i++) {
                ComponentAllocation memory alloc = node.getComponentAllocation(activeComponents[i]);
                if (alloc.targetWeight >= 0.5 ether) highWeightCount++;
                if (_isTrackedComponent(activeComponents[i], COMPONENTS_ERC7540)) asyncCount++;
            }
            if (asyncCount > 0) fl.log("NODE_has_async_components");
            if (highWeightCount > 0) fl.log("NODE_has_concentrated_weight");
        }
    }

    // ============ Node Reserves ============

    function _logicalNodeReserves() private {
        if (address(node) == address(0)) return;

        uint256 totalAssets = node.totalAssets();
        if (totalAssets == 0) return;

        uint256 sharesExiting = node.sharesExiting();
        uint256 pendingAssets = sharesExiting == 0 ? 0 : node.convertToAssets(sharesExiting);
        uint256 cashAfterRedemptions = node.getCashAfterRedemptions();
        uint64 targetReserveRatio = node.targetReserveRatio();

        uint256 reserveRatio = (cashAfterRedemptions * 1e18) / totalAssets;
        if (reserveRatio < targetReserveRatio) {
            fl.log("NODE_RES_ratio_below_target");
        }
        if (pendingAssets > 0 && cashAfterRedemptions < pendingAssets) {
            fl.log("NODE_RES_cash_shortfall");
        }

        // Check claimable vs escrow
        uint256 totalClaimableAssets;
        for (uint256 i = 0; i < USERS.length; i++) {
            (, , uint256 claimableAssets) = node.requests(USERS[i]);
            totalClaimableAssets += claimableAssets;
        }
        if (totalClaimableAssets > 0 && totalClaimableAssets > asset.balanceOf(address(escrow))) {
            fl.log("NODE_RES_claimable_exceeds_escrow");
        }
    }

    // ============ Node Factory ============

    function _logicalNodeFactory() private {
        if (address(factory) == address(0)) {
            fl.log("FACTORY_contract_missing");
            return;
        }

        if (address(factory.registry()) != address(registry)) {
            fl.log("FACTORY_registry_mismatch");
        }
        if (factory.nodeImplementation() == address(0)) {
            fl.log("FACTORY_implementation_missing");
        }

        for (uint256 i = 0; i < MANAGED_NODES.length; i++) {
            address managedNode = MANAGED_NODES[i];
            if (!registry.isNode(managedNode)) {
                fl.log("FACTORY_node_missing_registry_role");
            }
            if (MANAGED_NODE_ESCROWS[managedNode] == address(0)) {
                fl.log("FACTORY_managed_node_missing_escrow");
            }
        }
    }

    // ============ Reward Routers ============

    function _logicalRewardRouters() private {
        if (address(routerFluid) != address(0)) {
            if (routerFluid.distributor() == address(0)) fl.log("REWARD_fluid_distributor_missing");
            if (address(routerFluid.registry()) != address(registry)) fl.log("REWARD_fluid_registry_mismatch");
        }
        if (address(routerIncentra) != address(0)) {
            if (routerIncentra.distributor() == address(0)) fl.log("REWARD_incentra_distributor_missing");
            if (address(routerIncentra.registry()) != address(registry)) fl.log("REWARD_incentra_registry_mismatch");
        }
        if (address(routerMerkl) != address(0)) {
            if (routerMerkl.distributor() == address(0)) fl.log("REWARD_merkl_distributor_missing");
            if (address(routerMerkl.registry()) != address(registry)) fl.log("REWARD_merkl_registry_mismatch");
        }
    }

    // ============ Digift Adapter ============

    function _logicalDigiftAdapter() private {
        if (address(digiftAdapter) == address(0)) return;

        if (digiftAdapter.globalPendingDepositRequest() > 0) fl.log("DIGIFT_global_pending_deposit");
        if (digiftAdapter.globalPendingRedeemRequest() > 0) fl.log("DIGIFT_global_pending_redeem");

        if (address(node) != address(0)) {
            if (digiftAdapter.pendingDepositRequest(0, address(node)) > 0) fl.log("DIGIFT_node_pending_deposit");
            if (digiftAdapter.claimableDepositRequest(0, address(node)) > 0) fl.log("DIGIFT_node_claimable_deposit");
            if (digiftAdapter.pendingRedeemRequest(0, address(node)) > 0) fl.log("DIGIFT_node_pending_redeem");
            if (digiftAdapter.claimableRedeemRequest(0, address(node)) > 0) fl.log("DIGIFT_node_claimable_redeem");
        }
    }

    // ============ Escrow ============

    function _logicalEscrow() private {
        if (address(escrow) == address(0)) return;

        address boundNode = Escrow(address(escrow)).node();
        if (boundNode != address(node) && boundNode != address(0)) {
            fl.log("ESCROW_bound_to_other_node");
        }
        if (boundNode == address(0)) {
            fl.log("ESCROW_unbound");
        }
    }

    // ============ Helpers ============

    function _isTrackedComponent(address target, address[] storage list) private view returns (bool) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == target) return true;
        }
        return false;
    }
}
