// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";
import {Node} from "../../../src/Node.sol";
import {ComponentAllocation} from "../../../src/interfaces/INode.sol";
import {BaseComponentRouter} from "../../../src/libraries/BaseComponentRouter.sol";

contract Properties_Node is Properties_ERR {
    // ==============================================================
    // EXISTING INVARIANTS (NODE_01 - NODE_07)
    // ==============================================================

    function invariant_NODE_01(ActorState storage beforeActor, ActorState storage afterActor) internal {
        uint256 shares = afterActor.shareBalance - beforeActor.shareBalance;
        fl.gt(shares, 0, NODE_01);
    }

    function invariant_NODE_02(RequestRedeemParams memory params) internal {
        ActorState storage beforeOwner = states[0].actorStates[params.owner];
        ActorState storage afterOwner = states[1].actorStates[params.owner];

        fl.eq(states[1].nodeEscrowShareBalance - states[0].nodeEscrowShareBalance, params.shares, NODE_02);
        fl.eq(beforeOwner.shareBalance - afterOwner.shareBalance, params.shares, NODE_02);
    }

    function invariant_NODE_03(FulfillRedeemParams memory params) internal {
        fl.lt(states[1].nodeEscrowShareBalance, states[0].nodeEscrowShareBalance, NODE_03);
    }

    function invariant_NODE_04(WithdrawParams memory params) internal {
        ActorState storage beforeReceiver = states[0].actorStates[params.receiver];
        ActorState storage afterReceiver = states[1].actorStates[params.receiver];

        fl.eq(afterReceiver.assetBalance - beforeReceiver.assetBalance, params.assets, NODE_04);
    }

    function invariant_NODE_05() internal {
        uint256 escrowAssetBalance = states[1].nodeEscrowAssetBalance;

        // Get all users' total claimable assets
        uint256 totalClaimableAssets;

        for(uint256 i; i < USERS.length; i++) {
            ActorState memory userState = states[1].actorStates[USERS[i]];
            totalClaimableAssets += userState.claimableAssets;
        }

        fl.gte(escrowAssetBalance, totalClaimableAssets, NODE_05);
    }

    function invariant_NODE_06(RouterInvestParams memory params) internal {
        uint256 currentTotalAssets = node.totalAssets();
        uint256 componentAssetValueAfterInvest = ERC4626(params.component).convertToAssets(IERC20(params.component).balanceOf(address(node)));
        uint256 componentTargetWeight = node.getComponentAllocation(params.component).targetWeight;
        uint256 realRatioAfterInvest = componentAssetValueAfterInvest * 1e18 / currentTotalAssets;

        fl.gte(componentTargetWeight, realRatioAfterInvest, NODE_06);

    }

    function invariant_NODE_07() internal {
        uint256 currentCash = node.getCashAfterRedemptions();
        uint256 totalAssets = node.totalAssets();
        uint256 ratioAfterInvest = Math.mulDiv(currentCash, 1e18, totalAssets);
        uint256 targetReserve = node.targetReserveRatio();

        fl.gte(ratioAfterInvest, targetReserve, NODE_07);
    }

    // ==============================================================
    // DEPOSIT INVARIANTS (NODE_08 - NODE_13)
    // ==============================================================

    function invariant_NODE_08(uint256 mintedShares) internal {
        // fl.t(mintedShares > 0, NODE_08);
    }

    function invariant_NODE_09(ActorState storage beforeActor, ActorState storage afterActor, uint256 mintedShares) internal {
        // fl.eq(afterActor.shareBalance, beforeActor.shareBalance + mintedShares, NODE_09);
    }

    function invariant_NODE_10(ActorState storage beforeActor, ActorState storage afterActor, uint256 assets) internal {
        // fl.eq(afterActor.assetBalance, beforeActor.assetBalance - assets, NODE_10);
    }

    function invariant_NODE_11(uint256 assets) internal {
        // fl.eq(states[1].nodeAssetBalance, states[0].nodeAssetBalance + assets, NODE_11);
    }

    function invariant_NODE_12(uint256 assets) internal {
        // fl.eq(states[1].nodeTotalAssets, states[0].nodeTotalAssets + assets, NODE_12);
    }

    function invariant_NODE_13(uint256 mintedShares) internal {
        // fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply + mintedShares, NODE_13);
    }

    // ==============================================================
    // MINT INVARIANTS (NODE_14 - NODE_19)
    // ==============================================================

    function invariant_NODE_14(uint256 assetsSpent) internal {
        // fl.t(assetsSpent > 0, NODE_14);
    }

    function invariant_NODE_15(ActorState storage beforeActor, ActorState storage afterActor, uint256 shares) internal {
        // fl.eq(afterActor.shareBalance, beforeActor.shareBalance + shares, NODE_15);
    }

    function invariant_NODE_16(ActorState storage beforeActor, ActorState storage afterActor, uint256 assetsSpent) internal {
        // fl.eq(afterActor.assetBalance, beforeActor.assetBalance - assetsSpent, NODE_16);
    }

    function invariant_NODE_17(uint256 assetsSpent) internal {
        // fl.eq(states[1].nodeAssetBalance, states[0].nodeAssetBalance + assetsSpent, NODE_17);
    }

    function invariant_NODE_18(uint256 assetsSpent) internal {
        // fl.eq(states[1].nodeTotalAssets, states[0].nodeTotalAssets + assetsSpent, NODE_18);
    }

    function invariant_NODE_19(uint256 shares) internal {
        // fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply + shares, NODE_19);
    }

    // ==============================================================
    // REQUEST REDEEM INVARIANTS (NODE_20 - NODE_25)
    // ==============================================================

    function invariant_NODE_20(ActorState storage beforeOwner, ActorState storage afterOwner, uint256 shares) internal {
        // fl.eq(afterOwner.shareBalance, beforeOwner.shareBalance - shares, NODE_20);
    }

    function invariant_NODE_21(uint256 shares) internal {
        // fl.eq(states[1].actorStates[address(escrow)].shareBalance, states[0].actorStates[address(escrow)].shareBalance + shares, NODE_21);
    }

    function invariant_NODE_22(uint256 pendingRedeemAfter, uint256 pendingBefore, uint256 shares) internal {
        // fl.eq(pendingRedeemAfter, pendingBefore + shares, NODE_22);
    }

    function invariant_NODE_23(uint256 claimableRedeemAfter, uint256 claimableRedeemBefore) internal {
        // fl.eq(claimableRedeemAfter, claimableRedeemBefore, NODE_23);
    }

    function invariant_NODE_24(uint256 claimableAssetsAfter, uint256 claimableAssetsBefore) internal {
        // fl.eq(claimableAssetsAfter, claimableAssetsBefore, NODE_24);
    }

    // ==============================================================
    // FULFILL REDEEM INVARIANTS (NODE_25 - NODE_29)
    // ==============================================================

    function invariant_NODE_25(ActorState storage beforeController, ActorState storage afterController) internal {
        // fl.t(afterController.pendingRedeem < beforeController.pendingRedeem, NODE_25);
    }

    function invariant_NODE_26(ActorState storage beforeController, ActorState storage afterController) internal {
        // fl.t(afterController.claimableAssets > beforeController.claimableAssets, NODE_26);
    }

    function invariant_NODE_27(ActorState storage beforeController, ActorState storage afterController) internal {
        // fl.t(afterController.claimableRedeem > beforeController.claimableRedeem, NODE_27);
    }

    function invariant_NODE_28() internal {
        // fl.t(states[1].nodeAssetBalance < states[0].nodeAssetBalance, NODE_28);
    }

    function invariant_NODE_29() internal {
        // fl.t(states[1].nodeEscrowAssetBalance > states[0].nodeEscrowAssetBalance, NODE_29);
    }

    // ==============================================================
    // WITHDRAW INVARIANTS (NODE_30 - NODE_33)
    // ==============================================================

    function invariant_NODE_30(ActorState storage beforeController, ActorState storage afterController, uint256 assets) internal {
        // fl.eq(afterController.claimableAssets, beforeController.claimableAssets - assets, NODE_30);
    }

    function invariant_NODE_31(ActorState storage beforeController, ActorState storage afterController, uint256 sharesBurned) internal {
        // fl.eq(afterController.claimableRedeem, beforeController.claimableRedeem - sharesBurned, NODE_31);
    }

    function invariant_NODE_32(ActorState storage beforeReceiver, ActorState storage afterReceiver, uint256 assets) internal {
        // fl.eq(afterReceiver.assetBalance, beforeReceiver.assetBalance + assets, NODE_32);
    }

    function invariant_NODE_33(uint256 assets) internal {
        // fl.eq(states[1].nodeEscrowAssetBalance, states[0].nodeEscrowAssetBalance - assets, NODE_33);
    }

    // ==============================================================
    // OPERATOR INVARIANTS (NODE_34)
    // ==============================================================

    function invariant_NODE_34(SetOperatorParams memory params, bool isApproved) internal {
        // fl.eq(isApproved, params.approved, NODE_34);
    }

    // ==============================================================
    // APPROVE INVARIANTS (NODE_35)
    // ==============================================================

    function invariant_NODE_35(uint256 allowance, NodeApproveParams memory params) internal {
        // fl.eq(allowance, params.amount, NODE_35);
    }

    // ==============================================================
    // TRANSFER INVARIANTS (NODE_36 - NODE_38)
    // ==============================================================

    function invariant_NODE_36(ActorState storage beforeSender, ActorState storage afterSender, uint256 amount) internal {
        // fl.eq(afterSender.shareBalance, beforeSender.shareBalance - amount, NODE_36);
    }

    function invariant_NODE_37(ActorState storage beforeReceiver, ActorState storage afterReceiver, uint256 amount) internal {
        // fl.eq(afterReceiver.shareBalance, beforeReceiver.shareBalance + amount, NODE_37);
    }

    function invariant_NODE_38() internal {
        // fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply, NODE_38);
    }

    // ==============================================================
    // TRANSFER FROM INVARIANTS (NODE_39 - NODE_41)
    // ==============================================================

    function invariant_NODE_39(ActorState storage beforeOwner, ActorState storage afterOwner, uint256 amount) internal {
        // fl.eq(afterOwner.shareBalance, beforeOwner.shareBalance - amount, NODE_39);
    }

    function invariant_NODE_40(ActorState storage beforeReceiver, ActorState storage afterReceiver, uint256 amount) internal {
        // fl.eq(afterReceiver.shareBalance, beforeReceiver.shareBalance + amount, NODE_40);
    }

    function invariant_NODE_41(uint256 allowanceAfter, uint256 allowanceBefore, uint256 amount) internal {
        // fl.eq(allowanceAfter, allowanceBefore >= amount ? allowanceBefore - amount : 0, NODE_41);
    }

    // ==============================================================
    // REDEEM INVARIANTS (NODE_42 - NODE_45)
    // ==============================================================

    function invariant_NODE_42(ActorState storage beforeController, ActorState storage afterController, uint256 shares) internal {
        // fl.eq(afterController.claimableRedeem, beforeController.claimableRedeem - shares, NODE_42);
    }

    function invariant_NODE_43(ActorState storage beforeController, ActorState storage afterController, uint256 assetsReturned) internal {
        // fl.eq(afterController.claimableAssets, beforeController.claimableAssets - assetsReturned, NODE_43);
    }

    function invariant_NODE_44(ActorState storage beforeReceiver, ActorState storage afterReceiver, uint256 assetsReturned) internal {
        // fl.eq(afterReceiver.assetBalance, beforeReceiver.assetBalance + assetsReturned, NODE_44);
    }

    function invariant_NODE_45(uint256 assetsReturned) internal {
        // fl.eq(states[1].nodeEscrowAssetBalance, states[0].nodeEscrowAssetBalance - assetsReturned, NODE_45);
    }

    // ==============================================================
    // OWNERSHIP INVARIANTS (NODE_46 - NODE_47)
    // ==============================================================

    function invariant_NODE_46() internal {
        // Node renounce ownership should always revert
        // fl.t(!success, NODE_46);
    }

    function invariant_NODE_47() internal {
        // Node transfer ownership should always revert
        // fl.t(!success, NODE_47);
    }

    // ==============================================================
    // INITIALIZE INVARIANTS (NODE_48)
    // ==============================================================

    function invariant_NODE_48() internal {
        // Node initialize should always revert (already initialized)
        // fl.t(!success, NODE_48);
    }

    // ==============================================================
    // FEE/CONFIG INVARIANTS (NODE_49 - NODE_54)
    // ==============================================================

    function invariant_NODE_49(NodeFeeParams memory params) internal {
        // fl.eq(node.annualManagementFee(), params.fee, NODE_49);
    }

    function invariant_NODE_50(NodeUintParams memory params) internal {
        // fl.eq(node.maxDepositSize(), params.value, NODE_50);
    }

    function invariant_NODE_51(NodeAddressParams memory params) internal {
        // fl.eq(node.nodeOwnerFeeAddress(), params.target, NODE_51);
    }

    function invariant_NODE_52(NodeAddressParams memory params) internal {
        // fl.eq(address(node.quoter()), params.target, NODE_52);
    }

    function invariant_NODE_53(NodeFeeParams memory params) internal {
        // fl.eq(uint256(Node(address(node)).rebalanceCooldown()), uint256(params.fee), NODE_53);
    }

    function invariant_NODE_54(NodeFeeParams memory params) internal {
        // fl.eq(uint256(Node(address(node)).rebalanceWindow()), uint256(params.fee), NODE_54);
    }

    // ==============================================================
    // COMPONENT INVARIANTS (NODE_55 - NODE_60)
    // ==============================================================

    function invariant_NODE_55(NodeComponentAllocationParams memory params) internal {
        // fl.t(node.isComponent(params.component), NODE_55);
    }

    function invariant_NODE_56(NodeComponentAllocationParams memory params) internal {
        ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
        // fl.eq(uint256(allocation.targetWeight), uint256(uint64(params.targetWeight)), NODE_56);
    }

    function invariant_NODE_57(NodeComponentAllocationParams memory params) internal {
        ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
        // fl.eq(uint256(allocation.maxDelta), uint256(uint64(params.maxDelta)), NODE_57);
    }

    function invariant_NODE_58(NodeComponentAllocationParams memory params) internal {
        ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
        // fl.eq(allocation.router, params.router, NODE_58);
    }

    function invariant_NODE_59(NodeRemoveComponentParams memory params) internal {
        // fl.t(!node.isComponent(params.component), NODE_59);
    }

    function invariant_NODE_60(NodeQueueParams memory params) internal {
        address[] memory components = node.getComponents();
        // fl.eq(components.length, params.queue.length, NODE_60);
    }

    // ==============================================================
    // RESCUE TOKENS INVARIANTS (NODE_61 - NODE_62)
    // ==============================================================

    function invariant_NODE_61(NodeRescueParams memory params, uint256 nodeBalanceAfter) internal {
        // fl.eq(nodeBalanceAfter, params.nodeBalanceBefore - params.amount, NODE_61);
    }

    function invariant_NODE_62(NodeRescueParams memory params, uint256 recipientBalanceAfter) internal {
        // fl.eq(recipientBalanceAfter, params.recipientBalanceBefore + params.amount, NODE_62);
    }

    // ==============================================================
    // POLICIES INVARIANTS (NODE_63 - NODE_64)
    // ==============================================================

    function invariant_NODE_63(bytes4 selector, address policy) internal {
        // fl.t(node.isSigPolicy(selector, policy), NODE_63);
    }

    function invariant_NODE_64(bytes4 selector, address policy) internal {
        // fl.t(!node.isSigPolicy(selector, policy), NODE_64);
    }

    // ==============================================================
    // REBALANCER/ROUTER INVARIANTS (NODE_65 - NODE_68)
    // ==============================================================

    function invariant_NODE_65(NodeAddressParams memory params) internal {
        // fl.t(node.isRebalancer(params.target), NODE_65);
    }

    function invariant_NODE_66(NodeAddressParams memory params) internal {
        // fl.t(!node.isRebalancer(params.target), NODE_66);
    }

    function invariant_NODE_67(NodeAddressParams memory params) internal {
        // fl.t(node.isRouter(params.target), NODE_67);
    }

    function invariant_NODE_68(NodeAddressParams memory params) internal {
        // fl.t(!node.isRouter(params.target), NODE_68);
    }

    // ==============================================================
    // REBALANCE INVARIANTS (NODE_69 - NODE_74)
    // ==============================================================

    function invariant_NODE_69(uint256 lastRebalanceAfter, uint256 lastRebalanceBefore) internal {
        // fl.t(lastRebalanceAfter >= lastRebalanceBefore, NODE_69);
    }

    function invariant_NODE_70() internal {
        // fl.t(node.isCacheValid(), NODE_70);
    }

    function invariant_NODE_71() internal {
        // fl.t(node.validateComponentRatios(), NODE_71);
    }

    function invariant_NODE_72(uint256 ownerDelta, uint256 protocolDelta, uint256 nodeDelta) internal {
        // fl.eq(ownerDelta + protocolDelta, nodeDelta, NODE_72);
    }

    function invariant_NODE_73() internal {
        // fl.t(states[1].nodeTotalAssets <= states[0].nodeTotalAssets, NODE_73);
    }

    // ==============================================================
    // PAY MANAGEMENT FEES INVARIANTS (NODE_74 - NODE_77)
    // ==============================================================

    function invariant_NODE_74(uint256 ownerDelta, uint256 protocolDelta, uint256 nodeDelta) internal {
        // fl.eq(ownerDelta + protocolDelta, nodeDelta, NODE_74);
    }

    function invariant_NODE_75(uint256 feeForPeriod, uint256 ownerDelta, uint256 protocolDelta) internal {
        // fl.eq(feeForPeriod, ownerDelta + protocolDelta, NODE_75);
    }

    function invariant_NODE_76(uint256 lastPaymentAfter, uint256 lastPaymentBefore) internal {
        // fl.t(lastPaymentAfter > lastPaymentBefore, NODE_76);
    }

    function invariant_NODE_77(uint256 lastPaymentAfter, uint256 lastPaymentBefore) internal {
        // fl.eq(lastPaymentAfter, lastPaymentBefore, NODE_77);
    }

    // ==============================================================
    // UPDATE TOTAL ASSETS INVARIANTS (NODE_78)
    // ==============================================================

    function invariant_NODE_78() internal {
        // fl.t(uint256(node.totalAssets()) == states[1].nodeTotalAssets, NODE_78);
    }

    // ==============================================================
    // SUBTRACT EXECUTION FEE INVARIANTS (NODE_79 - NODE_80)
    // ==============================================================

    function invariant_NODE_79(uint256 nodeDelta, uint256 fee) internal {
        // fl.eq(nodeDelta, fee, NODE_79);
    }

    function invariant_NODE_80(uint256 protocolDelta, uint256 fee) internal {
        // fl.eq(protocolDelta, fee, NODE_80);
    }

    // ==============================================================
    // EXECUTE INVARIANTS (NODE_81 - NODE_82)
    // ==============================================================

    function invariant_NODE_81(NodeExecuteParams memory params, uint256 allowanceAfter) internal {
        // fl.eq(allowanceAfter, params.allowance, NODE_81);
    }

    function invariant_NODE_82() internal {
        // fl.eq(states[0].nodeAssetBalance, states[1].nodeAssetBalance, NODE_82);
    }

    // ==============================================================
    // FINALIZE REDEMPTION INVARIANTS (NODE_83 - NODE_88)
    // ==============================================================

    function invariant_NODE_83(ActorState storage beforeState, ActorState storage afterState, uint256 sharesPending) internal {
        // fl.eq(afterState.pendingRedeem, beforeState.pendingRedeem - sharesPending, NODE_83);
    }

    function invariant_NODE_84(ActorState storage beforeState, ActorState storage afterState, uint256 sharesPending) internal {
        // fl.eq(afterState.claimableRedeem, beforeState.claimableRedeem + sharesPending, NODE_84);
    }

    function invariant_NODE_85(ActorState storage beforeState, ActorState storage afterState, uint256 assetsToReturn) internal {
        // fl.eq(afterState.claimableAssets, beforeState.claimableAssets + assetsToReturn, NODE_85);
    }

    function invariant_NODE_86(ActorState storage beforeState, ActorState storage afterState, uint256 assetsToReturn) internal {
        // fl.eq(afterState.assetBalance, beforeState.assetBalance + assetsToReturn, NODE_86);
    }

    function invariant_NODE_87(uint256 nodeBalanceBefore, uint256 assetsToReturn) internal {
        // fl.eq(states[1].nodeAssetBalance, nodeBalanceBefore - assetsToReturn, NODE_87);
    }

    function invariant_NODE_88(uint256 sharesExitingBefore, uint256 sharesAdjusted) internal {
        // fl.eq(states[1].sharesExiting, sharesExitingBefore - sharesAdjusted, NODE_88);
    }

    // ==============================================================
    // TARGET RESERVE / SWING PRICING INVARIANTS (NODE_89 - NODE_91)
    // ==============================================================

    function invariant_NODE_89(NodeTargetReserveParams memory params) internal {
        // fl.eq(uint256(Node(address(node)).targetReserveRatio()), uint256(params.target), NODE_89);
    }

    function invariant_NODE_90(NodeSwingPricingParams memory params) internal {
        // fl.eq(Node(address(node)).swingPricingEnabled(), params.status, NODE_90);
    }

    function invariant_NODE_91(NodeSwingPricingParams memory params) internal {
        // fl.eq(uint256(Node(address(node)).maxSwingFactor()), uint256(params.maxSwingFactor), NODE_91);
    }

    // ==============================================================
    // ROUTER INVARIANTS (NODE_92 - NODE_94)
    // ==============================================================

    function invariant_NODE_92(RouterSingleStatusParams memory params) internal {
        bool stored = BaseComponentRouter(params.router).isBlacklisted(params.component);
        fl.eq(stored, params.status, NODE_92);
    }

    function invariant_NODE_93(address router, address component, bool expectedStatus) internal {
        bool stored = BaseComponentRouter(router).isWhitelisted(component);
        fl.eq(stored, expectedStatus, NODE_93);
    }

    function invariant_NODE_94(RouterToleranceParams memory params) internal {
        uint256 stored = BaseComponentRouter(params.router).tolerance();
        fl.eq(stored, params.newTolerance, NODE_94);
    }
}