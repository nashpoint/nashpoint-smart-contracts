// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";

contract Properties_Node is Properties_ERR {
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
}