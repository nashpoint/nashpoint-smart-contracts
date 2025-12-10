// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Node} from "../../../../src/Node.sol";
import {ComponentAllocation} from "../../../../src/interfaces/INode.sol";
import {IERC7575} from "../../../../src/interfaces/IERC7575.sol";
import {IERC7540Deposit, IERC7540Redeem} from "../../../../src/interfaces/IERC7540.sol";
import {ERC7540Mock} from "../../../mocks/ERC7540Mock.sol";
import {BaseComponentRouter} from "../../../../src/libraries/BaseComponentRouter.sol";

contract PostconditionsNode is PostconditionsBase {
    function depositPostconditions(bool success, bytes memory returnData, DepositParams memory params) internal {
        if (success) {
            _after();

            uint256 mintedShares = abi.decode(returnData, (uint256));

            ActorState storage beforeActor = states[0].actorStates[params.receiver];
            ActorState storage afterActor = states[1].actorStates[params.receiver];

            invariant_NODE_08(beforeActor, afterActor, mintedShares);
            invariant_NODE_09(params.assets);
            invariant_NODE_10(params.assets);
            invariant_NODE_11(mintedShares);

            invariant_NODE_01(beforeActor, afterActor);
            invariant_NODE_05();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function mintPostconditions(bool success, bytes memory returnData, MintParams memory params) internal {
        if (success) {
            _after();

            uint256 assetsSpent = abi.decode(returnData, (uint256));

            ActorState storage beforeActor = states[0].actorStates[params.receiver];
            ActorState storage afterActor = states[1].actorStates[params.receiver];

            invariant_NODE_12(beforeActor, afterActor, params.shares);
            invariant_NODE_13(assetsSpent);
            invariant_NODE_14(assetsSpent);
            invariant_NODE_15(params.shares);

            invariant_NODE_01(beforeActor, afterActor);
            invariant_NODE_05();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function requestRedeemPostconditions(bool success, bytes memory returnData, RequestRedeemParams memory params)
        internal
    {
        if (success) {
            _after();

            ActorState storage beforeOwner = states[0].actorStates[params.owner];
            ActorState storage afterOwner = states[1].actorStates[params.owner];

            (uint256 pendingRedeemAfter, uint256 claimableRedeemAfter, uint256 claimableAssetsAfter) =
                node.requests(params.controller);

            invariant_NODE_16(beforeOwner, afterOwner, params.shares);
            invariant_NODE_17(pendingRedeemAfter, params.pendingBefore, params.shares);
            invariant_NODE_18(claimableRedeemAfter, states[0].actorStates[params.controller].claimableRedeem);
            invariant_NODE_19(claimableAssetsAfter, states[0].actorStates[params.controller].claimableAssets);

            invariant_NODE_02(params);
            invariant_NODE_05();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function fulfillRedeemPostconditions(bool success, bytes memory returnData, FulfillRedeemParams memory params)
        internal
    {
        if (success) {
            _after();

            ActorState storage beforeController = states[0].actorStates[params.controller];
            ActorState storage afterController = states[1].actorStates[params.controller];

            invariant_NODE_20(beforeController, afterController);
            invariant_NODE_21(beforeController, afterController);

            invariant_NODE_03(params);
            invariant_NODE_05();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function withdrawPostconditions(bool success, bytes memory returnData, WithdrawParams memory params) internal {
        if (success) {
            _after();

            ActorState storage beforeController = states[0].actorStates[params.controller];
            ActorState storage afterController = states[1].actorStates[params.controller];

            invariant_NODE_22(beforeController, afterController, params.assets);
            invariant_NODE_23(params.assets);

            invariant_NODE_04(params);
            invariant_NODE_05();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function setOperatorPostconditions(bool success, bytes memory returnData, SetOperatorParams memory params)
        internal
    {
        if (success) {
            _after();
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeApprovePostconditions(
        bool success,
        bytes memory returnData,
        address caller,
        NodeApproveParams memory params
    ) internal {
        if (success) {
            _after();
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeTransferPostconditions(
        bool success,
        bytes memory returnData,
        address sender,
        NodeTransferParams memory params
    ) internal {
        if (success) {
            _after();
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeTransferFromPostconditions(
        bool success,
        bytes memory returnData,
        address spender,
        NodeTransferFromParams memory params
    ) internal {
        if (success) {
            _after();
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeRedeemPostconditions(bool success, bytes memory returnData, NodeRedeemParams memory params) internal {
        if (success) {
            uint256 assetsReturned = abi.decode(returnData, (uint256));
            _after();

            ActorState storage beforeController = states[0].actorStates[params.controller];
            ActorState storage afterController = states[1].actorStates[params.controller];
            ActorState storage beforeReceiver = states[0].actorStates[params.receiver];
            ActorState storage afterReceiver = states[1].actorStates[params.receiver];

            invariant_NODE_29(beforeController, afterController, params.shares);
            invariant_NODE_30(beforeController, afterController, assetsReturned);
            invariant_NODE_31(beforeReceiver, afterReceiver, assetsReturned);
            invariant_NODE_32(assetsReturned);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeRenounceOwnershipPostconditions(
        bool success,
        bytes memory returnData,
        NodeOwnershipParams memory params
    ) internal {
        onFailInvariantsGeneral(returnData);
    }

    function nodeTransferOwnershipPostconditions(
        bool success,
        bytes memory returnData,
        NodeOwnershipParams memory params
    ) internal {
        onFailInvariantsGeneral(returnData);
    }

    function nodeInitializePostconditions(bool success, bytes memory returnData, NodeInitializeParams memory params)
        internal
    {
        params; // silence warning
        onFailInvariantsGeneral(returnData);
    }

    function nodeSetAnnualFeePostconditions(bool success, bytes memory returnData, NodeFeeParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetMaxDepositPostconditions(bool success, bytes memory returnData, NodeUintParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetNodeOwnerFeeAddressPostconditions(
        bool success,
        bytes memory returnData,
        NodeAddressParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetQuoterPostconditions(bool success, bytes memory returnData, NodeAddressParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetRebalanceCooldownPostconditions(bool success, bytes memory returnData, NodeFeeParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetRebalanceWindowPostconditions(bool success, bytes memory returnData, NodeFeeParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeRescueTokensPostconditions(bool success, bytes memory returnData, NodeRescueParams memory params)
        internal
    {
        if (success) {
            uint256 nodeBalanceAfter = IERC20(params.token).balanceOf(address(node));
            uint256 recipientBalanceAfter = IERC20(params.token).balanceOf(params.recipient);

            invariant_NODE_35(params, nodeBalanceAfter);
            invariant_NODE_36(params, recipientBalanceAfter);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeAddComponentPostconditions(
        bool success,
        bytes memory returnData,
        NodeComponentAllocationParams memory params
    ) internal {
        if (success) {
            ComponentAllocation memory allocation = node.getComponentAllocation(params.component);

            invariant_NODE_33(params);

            _pushUnique(COMPONENTS, params.component);
            _pushUnique(REMOVABLE_COMPONENTS, params.component);
            if (params.router == address(router4626)) {
                _pushUnique(COMPONENTS_ERC4626, params.component);
            } else if (params.router == address(router7540)) {
                _pushUnique(COMPONENTS_ERC7540, params.component);
            }

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeRemoveComponentPostconditions(
        bool success,
        bytes memory returnData,
        NodeRemoveComponentParams memory params
    ) internal {
        if (success) {
            invariant_NODE_34(params);
            _removeAddress(COMPONENTS, params.component);
            _removeAddress(REMOVABLE_COMPONENTS, params.component);
            _removeAddress(COMPONENTS_ERC4626, params.component);
            _removeAddress(COMPONENTS_ERC7540, params.component);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeUpdateComponentAllocationPostconditions(
        bool success,
        bytes memory returnData,
        NodeComponentAllocationParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeUpdateTargetReserveRatioPostconditions(
        bool success,
        bytes memory returnData,
        NodeTargetReserveParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeAddPoliciesPostconditions(bool success, bytes memory returnData, NodePoliciesParams memory params)
        internal
    {
        if (success) {
            for (uint256 i = 0; i < params.selectors.length; i++) {
                invariant_NODE_37(params.selectors[i], params.policies[i]);
                _pushUniquePolicyBinding(params.selectors[i], params.policies[i]);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeRemovePoliciesPostconditions(
        bool success,
        bytes memory returnData,
        NodePoliciesRemovalParams memory params
    ) internal {
        if (success) {
            for (uint256 i = 0; i < params.selectors.length; i++) {
                invariant_NODE_38(params.selectors[i], params.policies[i]);
                _removePolicyBinding(params.selectors[i], params.policies[i]);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeAddRebalancerPostconditions(bool success, bytes memory returnData, NodeAddressParams memory params)
        internal
    {
        if (success) {
            _pushUnique(REBALANCERS, params.target);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeRemoveRebalancerPostconditions(bool success, bytes memory returnData, NodeAddressParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeAddRouterPostconditions(bool success, bytes memory returnData, NodeAddressParams memory params)
        internal
    {
        if (success) {
            _pushUnique(ROUTERS, params.target);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeRemoveRouterPostconditions(bool success, bytes memory returnData, NodeAddressParams memory params)
        internal
    {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeStartRebalancePostconditions(
        bool success,
        bytes memory returnData,
        NodeStartRebalanceParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 lastRebalanceAfter = uint256(Node(address(node)).lastRebalance());

            ActorState storage ownerBefore = states[0].actorStates[node.nodeOwnerFeeAddress()];
            ActorState storage ownerAfter = states[1].actorStates[node.nodeOwnerFeeAddress()];
            ActorState storage protocolBefore = states[0].actorStates[protocolFeesAddress];
            ActorState storage protocolAfter = states[1].actorStates[protocolFeesAddress];

            uint256 ownerDelta = ownerAfter.assetBalance - ownerBefore.assetBalance;
            uint256 protocolDelta = protocolAfter.assetBalance - protocolBefore.assetBalance;
            uint256 nodeDelta = states[0].nodeAssetBalance - states[1].nodeAssetBalance;

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodePayManagementFeesPostconditions(
        bool success,
        bytes memory returnData,
        NodePayManagementFeesParams memory params
    ) internal {
        if (success) {
            uint256 feeForPeriod = abi.decode(returnData, (uint256));

            ActorState storage ownerBefore = states[0].actorStates[node.nodeOwnerFeeAddress()];
            ActorState storage ownerAfter = states[1].actorStates[node.nodeOwnerFeeAddress()];
            ActorState storage protocolBefore = states[0].actorStates[protocolFeesAddress];
            ActorState storage protocolAfter = states[1].actorStates[protocolFeesAddress];

            uint256 ownerDelta = ownerAfter.assetBalance - ownerBefore.assetBalance;
            uint256 protocolDelta = protocolAfter.assetBalance - protocolBefore.assetBalance;
            uint256 nodeDelta = states[0].nodeAssetBalance - states[1].nodeAssetBalance;

            uint256 lastPaymentAfter = uint256(Node(address(node)).lastPayment());

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeUpdateTotalAssetsPostconditions(
        bool success,
        bytes memory returnData,
        NodeUpdateTotalAssetsParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSubtractExecutionFeePostconditions(
        bool success,
        bytes memory returnData,
        NodeSubtractExecutionFeeParams memory params
    ) internal {
        if (success) {
            ActorState storage protocolBefore = states[0].actorStates[protocolFeesAddress];
            ActorState storage protocolAfter = states[1].actorStates[protocolFeesAddress];

            uint256 nodeDelta = states[0].nodeAssetBalance - states[1].nodeAssetBalance;
            uint256 protocolDelta = protocolAfter.assetBalance - protocolBefore.assetBalance;

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeExecutePostconditions(bool success, bytes memory returnData, NodeExecuteParams memory params)
        internal
    {
        if (success) {
            uint256 allowanceAfter = asset.allowance(address(node), params.allowanceSpender);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSubmitPolicyDataPostconditions(
        bool success,
        bytes memory returnData,
        NodeSubmitPolicyDataParams memory params
    ) internal {
        if (success) {
            _after();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeFinalizeRedemptionPostconditions(
        bool success,
        bytes memory returnData,
        NodeFinalizeParams memory params
    ) internal {
        if (success) {
            _after();

            ActorState storage controllerBefore = states[0].actorStates[params.controller];
            ActorState storage controllerAfter = states[1].actorStates[params.controller];

            invariant_NODE_24(controllerBefore, controllerAfter, params.sharesPending);
            invariant_NODE_25(controllerBefore, controllerAfter, params.sharesPending);
            invariant_NODE_26(controllerBefore, controllerAfter, params.assetsToReturn);
            invariant_NODE_27(params.assetsToReturn);
            invariant_NODE_28(params.nodeAssetBalanceBefore, params.assetsToReturn);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeMulticallPostconditions(bool success, bytes memory returnData, NodeMulticallParams memory params)
        internal
    {
        if (success) {
            _after();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeGainBackingPostconditions(bool success, bytes memory returnData, NodeYieldParams memory params)
        internal
    {
        if (success) {
            _after();

            uint256 balanceAfter = asset.balanceOf(params.component);
            invariant_NODE_39(balanceAfter, params.currentBacking, params.delta);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeLoseBackingPostconditions(bool success, bytes memory returnData, NodeYieldParams memory params)
        internal
    {
        if (success) {
            _after();

            uint256 balanceAfter = asset.balanceOf(params.component);
            invariant_NODE_40(balanceAfter, params.currentBacking, params.delta);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626InvestPostconditions(bool success, bytes memory returnData, RouterInvestParams memory params)
        internal
    {
        if (success) {
            _after();

            uint256 depositAmount = abi.decode(returnData, (uint256));
            invariant_ROUTER4626_01(depositAmount);

            uint256 sharesAfter = IERC20(params.component).balanceOf(address(node));
            invariant_ROUTER4626_02(sharesAfter, params.sharesBefore);

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            invariant_ROUTER4626_03(nodeBalanceAfter, params.nodeAssetBalanceBefore);

            invariant_NODE_06(params);
            invariant_NODE_07();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626LiquidatePostconditions(
        bool success,
        bytes memory returnData,
        RouterLiquidateParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 assetsReturned = abi.decode(returnData, (uint256));
            // Only assert assetsReturned > 0 if we expected the call to succeed normally.
            // When shouldSucceed=false (e.g., previewRedeem returned 0), a successful call
            // returning 0 assets is expected behavior for invalid/edge-case inputs.
            if (params.shouldSucceed) {
                invariant_ROUTER4626_04(assetsReturned);
            }

            uint256 sharesAfter = IERC20(params.component).balanceOf(address(node));
            invariant_ROUTER4626_05(sharesAfter, params.sharesBefore);

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            invariant_ROUTER4626_06(nodeBalanceAfter, params.nodeAssetBalanceBefore);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router4626FulfillPostconditions(bool success, bytes memory returnData, RouterFulfillParams memory params)
        internal
    {
        if (success) {
            _after();

            uint256 assetsReturned = abi.decode(returnData, (uint256));
            invariant_ROUTER4626_07(assetsReturned);

            uint256 escrowAfter = asset.balanceOf(address(escrow));
            uint256 nodeBalanceAfter = asset.balanceOf(address(node));

            invariant_ROUTER4626_08(escrowAfter, params.escrowBalanceBefore);
            invariant_ROUTER4626_09(nodeBalanceAfter, params.nodeAssetBalanceBefore);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function routerSetBlacklistPostconditions(
        bool success,
        bytes memory returnData,
        RouterSingleStatusParams memory params
    ) internal {
        if (success) {
            _after();
            bool stored = BaseComponentRouter(params.router).isBlacklisted(params.component);
            invariant_ROUTER_01(stored, params.status);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function routerBatchWhitelistPostconditions(
        bool success,
        bytes memory returnData,
        RouterBatchWhitelistParams memory params
    ) internal {
        if (success) {
            _after();
            for (uint256 i = 0; i < params.components.length; i++) {
                bool stored = BaseComponentRouter(params.router).isWhitelisted(params.components[i]);
                invariant_ROUTER_02(stored, params.statuses[i]);
            }
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function routerTolerancePostconditions(bool success, bytes memory returnData, RouterToleranceParams memory params)
        internal
    {
        if (success) {
            _after();
            uint256 stored = BaseComponentRouter(params.router).tolerance();
            invariant_ROUTER_03(stored, params.newTolerance);
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540InvestPostconditions(
        bool success,
        bytes memory returnData,
        RouterAsyncInvestParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 assetsRequested = abi.decode(returnData, (uint256));
            invariant_ROUTER7540_01(assetsRequested);

            if (params.component != address(digiftAdapter)) {
                uint256 pendingAfter = ERC7540Mock(params.component).pendingAssets();
                invariant_ROUTER7540_02(pendingAfter, params.pendingDepositBefore);
            }

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            invariant_ROUTER7540_03(nodeBalanceAfter, params.nodeAssetBalanceBefore);

            if (params.component == address(digiftAdapter)) {
                _recordDigiftPendingDeposit(address(node), params.component, assetsRequested);
            }

            invariant_NODE_07();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540MintClaimablePostconditions(
        // solhint-disable-line max-line-length
        bool success,
        bytes memory returnData,
        RouterMintClaimableParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 sharesReceived = abi.decode(returnData, (uint256));

            uint256 shareBalanceAfter = IERC20(params.component).balanceOf(address(node));
            invariant_ROUTER7540_04(shareBalanceAfter, params.shareBalanceBefore, sharesReceived);

            uint256 claimableAfter = IERC7540Deposit(params.component).claimableDepositRequest(0, address(node));
            invariant_ROUTER7540_05(claimableAfter, params.claimableAssetsBefore);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540RequestWithdrawalPostconditions(
        bool success,
        bytes memory returnData,
        RouterRequestAsyncWithdrawalParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 pendingAfter = IERC7540Redeem(params.component).pendingRedeemRequest(0, address(node));
            invariant_ROUTER7540_06(pendingAfter, params.pendingRedeemBefore);

            uint256 shareBalanceAfter = IERC20(params.component).balanceOf(address(node));
            invariant_ROUTER7540_07(shareBalanceAfter, params.shareBalanceBefore);

            if (params.component == address(digiftAdapter)) {
                _recordDigiftPendingRedemption(address(node), params.component, params.shares);
            }

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540ExecuteWithdrawalPostconditions(
        bool success,
        bytes memory returnData,
        RouterExecuteAsyncWithdrawalParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 assetsReturned = abi.decode(returnData, (uint256));
            invariant_ROUTER7540_08(assetsReturned);
            invariant_ROUTER7540_09(params.assets, params.maxWithdrawBefore);

            uint256 claimableAfter = IERC7540Redeem(params.component).claimableRedeemRequest(0, address(node));
            invariant_ROUTER7540_10(claimableAfter, params.claimableAssetsBefore);

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            invariant_ROUTER7540_11(nodeBalanceAfter, params.nodeAssetBalanceBefore);

            uint256 maxWithdrawAfter = IERC7575(params.component).maxWithdraw(address(node));
            invariant_ROUTER7540_12(maxWithdrawAfter);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540FulfillRedeemPostconditions(
        bool success,
        bytes memory returnData,
        RouterFulfillAsyncRedeemParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 assetsReturned = abi.decode(returnData, (uint256));
            // Only assert assetsReturned > 0 when we expected to fulfill shares
            // (i.e., the user had pending shares). The router can succeed with 0 assets
            // when called for a user with no pending shares - this is valid behavior.
            if (params.shouldSucceed) {
                invariant_ROUTER7540_13(assetsReturned);
            }

            uint256 escrowBalanceAfter = asset.balanceOf(address(escrow));
            invariant_ROUTER7540_14(escrowBalanceAfter, params.escrowBalanceBefore);

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            invariant_ROUTER7540_15(nodeBalanceAfter, params.nodeAssetBalanceBefore);

            uint256 componentSharesAfter = IERC20(params.component).balanceOf(address(node));
            invariant_ROUTER7540_16(componentSharesAfter, params.componentSharesBefore);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function poolProcessPendingDepositsPostconditions(
        // solhint-disable-line max-line-length
        bool success,
        bytes memory returnData,
        PoolProcessParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 pendingAfter = ERC7540Mock(params.pool).pendingAssets();
            invariant_POOL_01(pendingAfter, params.pendingBefore);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function poolProcessPendingRedemptionsPostconditions(
        bool success,
        bytes memory returnData,
        PoolProcessRedemptionsParams memory params
    ) internal {
        if (success) {
            _after();

            uint256 pendingAfter = IERC7540Redeem(params.pool).pendingRedeemRequest(0, address(node));
            invariant_POOL_02(pendingAfter);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function _pushUnique(address[] storage list, address candidate) internal {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == candidate) {
                return;
            }
        }
        list.push(candidate);
    }

    function _removeAddress(address[] storage list, address candidate) internal {
        uint256 length = list.length;
        for (uint256 i = 0; i < length; i++) {
            if (list[i] == candidate) {
                if (i != length - 1) {
                    list[i] = list[length - 1];
                }
                list.pop();
                return;
            }
        }
    }

    function _pushUniquePolicyBinding(bytes4 selector, address policy) internal {
        for (uint256 i = 0; i < REGISTERED_POLICY_SELECTORS.length; i++) {
            if (REGISTERED_POLICY_SELECTORS[i] == selector && REGISTERED_POLICY_ADDRESSES[i] == policy) {
                return;
            }
        }
        REGISTERED_POLICY_SELECTORS.push(selector);
        REGISTERED_POLICY_ADDRESSES.push(policy);
    }

    function _removePolicyBinding(bytes4 selector, address policy) internal {
        uint256 length = REGISTERED_POLICY_SELECTORS.length;
        for (uint256 i = 0; i < length; i++) {
            if (REGISTERED_POLICY_SELECTORS[i] == selector && REGISTERED_POLICY_ADDRESSES[i] == policy) {
                if (i != length - 1) {
                    REGISTERED_POLICY_SELECTORS[i] = REGISTERED_POLICY_SELECTORS[length - 1];
                    REGISTERED_POLICY_ADDRESSES[i] = REGISTERED_POLICY_ADDRESSES[length - 1];
                }
                REGISTERED_POLICY_SELECTORS.pop();
                REGISTERED_POLICY_ADDRESSES.pop();
                return;
            }
        }
    }

    /**
     * @notice Postconditions for OneInch swap operation
     * @dev Verifies:
     *      1. Swap succeeded/failed as expected
     *      2. Incentive tokens were transferred from node to executor
     *      3. Asset tokens were received by node
     *      4. Asset amount accounts for execution fee subtraction
     */
    function oneInchSwapPostconditions(bool success, bytes memory returnData, OneInchSwapParams memory params)
        internal
    {
        if (success) {
            _after();

            address nodeAddr = address(node);
            address executorAddr = params.executor;

            // Node should have received assets
            uint256 nodeAssetBalanceAfter = asset.balanceOf(nodeAddr);
            uint256 assetGain = nodeAssetBalanceAfter - params.nodeAssetBalanceBefore;

            // Assets should be at least minAssetsOut (after fee)
            // Fee is subtracted by _subtractExecutionFee, so actual amount might be slightly less
            invariant_ONEINCH_03(assetGain, params.minAssetsOut);

            // Incentive tokens should be transferred from node
            uint256 incentiveBalanceAfter = IERC20(params.incentive).balanceOf(nodeAddr);
            uint256 incentiveLoss = params.incentiveBalanceBefore - incentiveBalanceAfter;
            invariant_ONEINCH_04(incentiveLoss, params.incentiveAmount);

            // Executor should have received incentive tokens
            uint256 executorIncentiveBalance = IERC20(params.incentive).balanceOf(executorAddr);
            invariant_ONEINCH_05(executorIncentiveBalance, params.incentiveAmount);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
