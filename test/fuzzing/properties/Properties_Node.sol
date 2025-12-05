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
    // DEPOSIT INVARIANTS (NODE_08 - NODE_11)
    // ==============================================================

    function invariant_NODE_08(ActorState storage beforeActor, ActorState storage afterActor, uint256 mintedShares) internal {
        fl.eq(afterActor.shareBalance, beforeActor.shareBalance + mintedShares, NODE_08);
    }

    function invariant_NODE_09(uint256 assets) internal {
        fl.eq(states[1].nodeAssetBalance, states[0].nodeAssetBalance + assets, NODE_09);
    }

    function invariant_NODE_10(uint256 assets) internal {
        fl.eq(states[1].nodeTotalAssets, states[0].nodeTotalAssets + assets, NODE_10);
    }

    function invariant_NODE_11(uint256 mintedShares) internal {
        fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply + mintedShares, NODE_11);
    }

    // ==============================================================
    // MINT INVARIANTS (NODE_12 - NODE_15)
    // ==============================================================

    function invariant_NODE_12(ActorState storage beforeActor, ActorState storage afterActor, uint256 shares) internal {
        fl.eq(afterActor.shareBalance, beforeActor.shareBalance + shares, NODE_12);
    }

    function invariant_NODE_13(uint256 assetsSpent) internal {
        fl.eq(states[1].nodeAssetBalance, states[0].nodeAssetBalance + assetsSpent, NODE_13);
    }

    function invariant_NODE_14(uint256 assetsSpent) internal {
        fl.eq(states[1].nodeTotalAssets, states[0].nodeTotalAssets + assetsSpent, NODE_14);
    }

    function invariant_NODE_15(uint256 shares) internal {
        fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply + shares, NODE_15);
    }

    // ==============================================================
    // REQUEST REDEEM INVARIANTS (NODE_16 - NODE_19)
    // ==============================================================

    function invariant_NODE_16(ActorState storage beforeOwner, ActorState storage afterOwner, uint256 shares) internal {
        fl.eq(afterOwner.shareBalance, beforeOwner.shareBalance - shares, NODE_16);
    }

    function invariant_NODE_17(uint256 pendingRedeemAfter, uint256 pendingBefore, uint256 shares) internal {
        fl.eq(pendingRedeemAfter, pendingBefore + shares, NODE_17);
    }

    function invariant_NODE_18(uint256 claimableRedeemAfter, uint256 claimableRedeemBefore) internal {
        fl.eq(claimableRedeemAfter, claimableRedeemBefore, NODE_18);
    }

    function invariant_NODE_19(uint256 claimableAssetsAfter, uint256 claimableAssetsBefore) internal {
        fl.eq(claimableAssetsAfter, claimableAssetsBefore, NODE_19);
    }

    // ==============================================================
    // FULFILL REDEEM INVARIANTS (NODE_20 - NODE_21)
    // ==============================================================

    function invariant_NODE_20(ActorState storage beforeController, ActorState storage afterController) internal {
        fl.t(afterController.pendingRedeem < beforeController.pendingRedeem, NODE_20);
    }

    function invariant_NODE_21(ActorState storage beforeController, ActorState storage afterController) internal {
        fl.t(afterController.claimableRedeem > beforeController.claimableRedeem, NODE_21);
    }

    // ==============================================================
    // WITHDRAW INVARIANTS (NODE_30 - NODE_33)
    // ==============================================================

    function invariant_NODE_22(ActorState storage beforeController, ActorState storage afterController, uint256 assets) internal {
        fl.eq(afterController.claimableAssets, beforeController.claimableAssets - assets, NODE_22);
    }

    function invariant_NODE_23(uint256 assets) internal {
        fl.eq(states[1].nodeEscrowAssetBalance, states[0].nodeEscrowAssetBalance - assets, NODE_23);
    }

    // ==============================================================
    // FINALIZE REDEMPTION INVARIANTS (NODE_39 - NODE_43)
    // ==============================================================

    function invariant_NODE_24(ActorState storage beforeState, ActorState storage afterState, uint256 sharesPending) internal {
        fl.eq(afterState.pendingRedeem, beforeState.pendingRedeem - sharesPending, NODE_24);
    }

    function invariant_NODE_25(ActorState storage beforeState, ActorState storage afterState, uint256 sharesPending) internal {
        fl.eq(afterState.claimableRedeem, beforeState.claimableRedeem + sharesPending, NODE_25);
    }

    function invariant_NODE_26(ActorState storage beforeState, ActorState storage afterState, uint256 assetsToReturn) internal {
        fl.eq(afterState.claimableAssets, beforeState.claimableAssets + assetsToReturn, NODE_26);
    }

    function invariant_NODE_27(uint256 assetsToReturn) internal {
        fl.eq(states[1].nodeEscrowAssetBalance, states[0].nodeEscrowAssetBalance + assetsToReturn, NODE_27);
    }

    function invariant_NODE_28(uint256 nodeBalanceBefore, uint256 assetsToReturn) internal {
        fl.eq(states[1].nodeAssetBalance, nodeBalanceBefore - assetsToReturn, NODE_28);
    }

    // ==============================================================
    // REDEEM INVARIANTS (NODE_29 - NODE_32)
    // ==============================================================

    function invariant_NODE_29(ActorState storage beforeController, ActorState storage afterController, uint256 shares) internal {
        fl.eq(afterController.claimableRedeem, beforeController.claimableRedeem - shares, NODE_29);
    }

    function invariant_NODE_30(ActorState storage beforeController, ActorState storage afterController, uint256 assetsReturned) internal {
        fl.eq(afterController.claimableAssets, beforeController.claimableAssets - assetsReturned, NODE_30);
    }

    function invariant_NODE_31(ActorState storage beforeReceiver, ActorState storage afterReceiver, uint256 assetsReturned) internal {
        fl.eq(afterReceiver.assetBalance, beforeReceiver.assetBalance + assetsReturned, NODE_31);
    }

    function invariant_NODE_32(uint256 assetsReturned) internal {
        fl.eq(states[1].nodeEscrowAssetBalance, states[0].nodeEscrowAssetBalance - assetsReturned, NODE_32);
    }

    // ==============================================================
    // COMPONENT INVARIANTS (NODE_55 - NODE_60)
    // ==============================================================

    function invariant_NODE_33(NodeComponentAllocationParams memory params) internal {
        fl.t(node.isComponent(params.component), NODE_33);
    }

    function invariant_NODE_34(NodeRemoveComponentParams memory params) internal {
        fl.t(!node.isComponent(params.component), NODE_34);
    }

    // ==============================================================
    // RESCUE TOKENS INVARIANTS (NODE_35 - NODE_36)
    // ==============================================================

    function invariant_NODE_35(NodeRescueParams memory params, uint256 nodeBalanceAfter) internal {
        fl.eq(nodeBalanceAfter, params.nodeBalanceBefore - params.amount, NODE_35);
    }

    function invariant_NODE_36(NodeRescueParams memory params, uint256 recipientBalanceAfter) internal {
        fl.eq(recipientBalanceAfter, params.recipientBalanceBefore + params.amount, NODE_36);
    }

    // ==============================================================
    // POLICIES INVARIANTS (NODE_37 - NODE_38)
    // ==============================================================

    function invariant_NODE_37(bytes4 selector, address policy) internal {
        fl.t(node.isSigPolicy(selector, policy), NODE_37);
    }

    function invariant_NODE_38(bytes4 selector, address policy) internal {
        fl.t(!node.isSigPolicy(selector, policy), NODE_38);
    }

    // ==============================================================
    // NODE BACKING INVARIANTS (NODE_39 - NODE_40)
    // ==============================================================

    function invariant_NODE_39(uint256 balanceAfter, uint256 currentBacking, uint256 delta) internal {
        fl.eq(balanceAfter, currentBacking + delta, NODE_39);
    }

    function invariant_NODE_40(uint256 balanceAfter, uint256 currentBacking, uint256 delta) internal {
        fl.eq(balanceAfter, currentBacking - delta, NODE_40);
    }

    // ==============================================================
    // NODE GLOBAL INVARIANTS (NODE_41)
    // ==============================================================

    function invariant_NODE_41() internal {
        uint256 totalSupply = node.totalSupply();
        uint256 exitingShares = node.sharesExiting();
        fl.gte(totalSupply, exitingShares, NODE_41);
    }

    // ==============================================================
    // ROUTER 4626 INVARIANTS (ROUTER4626_01 - ROUTER4626_09)
    // ==============================================================

    function invariant_ROUTER4626_01(uint256 depositAmount) internal {
        fl.t(depositAmount > 0, ROUTER4626_01);
    }

    function invariant_ROUTER4626_02(uint256 sharesAfter, uint256 sharesBefore) internal {
        fl.t(sharesAfter >= sharesBefore, ROUTER4626_02);
    }

    function invariant_ROUTER4626_03(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter <= nodeBalanceBefore, ROUTER4626_03);
    }

    function invariant_ROUTER4626_04(uint256 assetsReturned) internal {
        fl.t(assetsReturned > 0, ROUTER4626_04);
    }

    function invariant_ROUTER4626_05(uint256 sharesAfter, uint256 sharesBefore) internal {
        fl.t(sharesAfter <= sharesBefore, ROUTER4626_05);
    }

    function invariant_ROUTER4626_06(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter >= nodeBalanceBefore, ROUTER4626_06);
    }

    function invariant_ROUTER4626_07(uint256 assetsReturned) internal {
        fl.t(assetsReturned > 0, ROUTER4626_07);
    }

    function invariant_ROUTER4626_08(uint256 escrowAfter, uint256 escrowBefore) internal {
        fl.t(escrowAfter >= escrowBefore, ROUTER4626_08);
    }

    function invariant_ROUTER4626_09(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter <= nodeBalanceBefore, ROUTER4626_09);
    }

    // ==============================================================
    // ROUTER 7540 INVARIANTS (ROUTER7540_01 - ROUTER7540_16)
    // ==============================================================

    function invariant_ROUTER7540_01(uint256 assetsRequested) internal {
        fl.t(assetsRequested > 0, ROUTER7540_01);
    }

    function invariant_ROUTER7540_02(uint256 pendingAfter, uint256 pendingBefore) internal {
        fl.t(pendingAfter >= pendingBefore, ROUTER7540_02);
    }

    function invariant_ROUTER7540_03(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter <= nodeBalanceBefore, ROUTER7540_03);
    }

    function invariant_ROUTER7540_04(uint256 shareBalanceAfter, uint256 shareBalanceBefore, uint256 sharesReceived) internal {
        fl.t(shareBalanceAfter >= shareBalanceBefore + sharesReceived, ROUTER7540_04);
    }

    function invariant_ROUTER7540_05(uint256 claimableAfter, uint256 claimableBefore) internal {
        fl.t(claimableAfter <= claimableBefore, ROUTER7540_05);
    }

    function invariant_ROUTER7540_06(uint256 pendingAfter, uint256 pendingBefore) internal {
        fl.t(pendingAfter >= pendingBefore, ROUTER7540_06);
    }

    function invariant_ROUTER7540_07(uint256 shareBalanceAfter, uint256 shareBalanceBefore) internal {
        fl.t(shareBalanceAfter <= shareBalanceBefore, ROUTER7540_07);
    }

    function invariant_ROUTER7540_08(uint256 assetsReturned) internal {
        fl.t(assetsReturned > 0, ROUTER7540_08);
    }

    function invariant_ROUTER7540_09(uint256 assets, uint256 maxWithdrawBefore) internal {
        fl.eq(assets, maxWithdrawBefore, ROUTER7540_09);
    }

    function invariant_ROUTER7540_10(uint256 claimableAfter, uint256 claimableBefore) internal {
        fl.t(claimableAfter <= claimableBefore, ROUTER7540_10);
    }

    function invariant_ROUTER7540_11(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter >= nodeBalanceBefore, ROUTER7540_11);
    }

    function invariant_ROUTER7540_12(uint256 maxWithdrawAfter) internal {
        fl.eq(maxWithdrawAfter, 0, ROUTER7540_12);
    }

    function invariant_ROUTER7540_13(uint256 assetsReturned) internal {
        fl.t(assetsReturned > 0, ROUTER7540_13);
    }

    function invariant_ROUTER7540_14(uint256 escrowBalanceAfter, uint256 escrowBalanceBefore) internal {
        fl.t(escrowBalanceAfter >= escrowBalanceBefore, ROUTER7540_14);
    }

    function invariant_ROUTER7540_15(uint256 nodeBalanceAfter, uint256 nodeBalanceBefore) internal {
        fl.t(nodeBalanceAfter <= nodeBalanceBefore, ROUTER7540_15);
    }

    function invariant_ROUTER7540_16(uint256 componentSharesAfter, uint256 componentSharesBefore) internal {
        fl.t(componentSharesAfter <= componentSharesBefore, ROUTER7540_16);
    }

    // ==============================================================
    // ROUTER SETTINGS INVARIANTS (ROUTER_01 - ROUTER_03)
    // ==============================================================

    function invariant_ROUTER_01(bool stored, bool expected) internal {
        fl.eq(stored, expected, ROUTER_01);
    }

    function invariant_ROUTER_02(bool stored, bool expected) internal {
        fl.eq(stored, expected, ROUTER_02);
    }

    function invariant_ROUTER_03(uint256 stored, uint256 expected) internal {
        fl.eq(stored, expected, ROUTER_03);
    }

    // ==============================================================
    // POOL INVARIANTS (POOL_01 - POOL_02)
    // ==============================================================

    function invariant_POOL_01(uint256 pendingAfter, uint256 pendingBefore) internal {
        fl.t(pendingAfter <= pendingBefore, POOL_01);
    }

    function invariant_POOL_02(uint256 pendingAfter) internal {
        fl.t(pendingAfter == 0, POOL_02);
    }
}