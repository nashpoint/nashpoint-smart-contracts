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

            // fl.t(mintedShares > 0, "NODE_DEPOSIT_ZERO_SHARES");
            // fl.eq(afterActor.shareBalance, beforeActor.shareBalance + mintedShares, "NODE_DEPOSIT_SHARE_DELTA");
            // fl.eq(afterActor.assetBalance, beforeActor.assetBalance - params.assets, "NODE_DEPOSIT_ASSET_DELTA");
            // fl.eq(states[1].nodeAssetBalance, states[0].nodeAssetBalance + params.assets, "NODE_DEPOSIT_NODE_ASSETS");
            // fl.eq(states[1].nodeTotalAssets, states[0].nodeTotalAssets + params.assets, "NODE_DEPOSIT_TOTAL_ASSETS");
            // fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply + mintedShares, "NODE_DEPOSIT_SUPPLY_DELTA");

    //        invariant_NODE_01(beforeActor, afterActor);
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

            // fl.t(assetsSpent > 0, "NODE_MINT_ZERO_ASSETS");
            // fl.eq(afterActor.shareBalance, beforeActor.shareBalance + params.shares, "NODE_MINT_SHARE_DELTA");
            // fl.eq(afterActor.assetBalance, beforeActor.assetBalance - assetsSpent, "NODE_MINT_ASSET_DELTA");
            // fl.eq(states[1].nodeAssetBalance, states[0].nodeAssetBalance + assetsSpent, "NODE_MINT_NODE_ASSETS");
            // fl.eq(states[1].nodeTotalAssets, states[0].nodeTotalAssets + assetsSpent, "NODE_MINT_TOTAL_ASSETS");
            // fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply + params.shares, "NODE_MINT_SUPPLY_DELTA");

    //        invariant_NODE_01(beforeActor, afterActor);
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
            ActorState storage afterEscrow = states[1].actorStates[address(escrow)];
            ActorState storage beforeEscrow = states[0].actorStates[address(escrow)];

            // fl.eq(afterOwner.shareBalance, beforeOwner.shareBalance - params.shares, "NODE_REQUEST_REDEEM_SHARE_DELTA");
            // fl.eq(
            // afterEscrow.shareBalance,
            // states[0].actorStates[address(escrow)].shareBalance + params.shares,
            // "NODE_REQUEST_REDEEM_ESCROW_BALANCE"
            // );

            (uint256 pendingRedeemAfter, uint256 claimableRedeemAfter, uint256 claimableAssetsAfter,) =
                node.requests(params.controller);

            // fl.eq(pendingRedeemAfter, params.pendingBefore + params.shares, "NODE_REQUEST_REDEEM_PENDING");
            // fl.eq(
            // claimableRedeemAfter,
            // states[0].actorStates[params.controller].claimableRedeem,
            // "NODE_REQUEST_REDEEM_CLAIMABLE_SHARES"
            // );
            // fl.eq(
            // claimableAssetsAfter,
            // states[0].actorStates[params.controller].claimableAssets,
            // "NODE_REQUEST_REDEEM_CLAIMABLE_ASSETS"
            // );

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

            // fl.t(afterController.pendingRedeem < beforeController.pendingRedeem, "NODE_FULFILL_PENDING_NOT_REDUCED");
            // fl.t(
            // afterController.claimableAssets > beforeController.claimableAssets,
            // "NODE_FULFILL_CLAIMABLE_ASSETS_NOT_INCREASED"
            // );
            // fl.t(
            // afterController.claimableRedeem > beforeController.claimableRedeem,
            // "NODE_FULFILL_CLAIMABLE_SHARES_NOT_INCREASED"
            // );
            // fl.t(states[1].nodeAssetBalance < states[0].nodeAssetBalance, "NODE_FULFILL_NODE_ASSETS_NOT_SENT");
            // fl.t(states[1].nodeEscrowAssetBalance > states[0].nodeEscrowAssetBalance, "NODE_FULFILL_ESCROW_NOT_FUNDED");

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

            uint256 sharesBurned = abi.decode(returnData, (uint256));

            ActorState storage beforeController = states[0].actorStates[params.controller];
            ActorState storage afterController = states[1].actorStates[params.controller];
            ActorState storage beforeReceiver = states[0].actorStates[params.receiver];
            ActorState storage afterReceiver = states[1].actorStates[params.receiver];

            // fl.eq(
            // afterController.claimableAssets,
            // beforeController.claimableAssets - params.assets,
            // "NODE_WITHDRAW_CLAIMABLE_ASSETS"
            // );
            // fl.eq(
            // afterController.claimableRedeem,
            // beforeController.claimableRedeem - sharesBurned,
            // "NODE_WITHDRAW_CLAIMABLE_SHARES"
            // );
            // fl.eq(afterReceiver.assetBalance, beforeReceiver.assetBalance + params.assets, "NODE_WITHDRAW_RECEIVER_BALANCE");
            // fl.eq(
            // states[1].nodeEscrowAssetBalance,
            // states[0].nodeEscrowAssetBalance - params.assets,
            // "NODE_WITHDRAW_ESCROW_BALANCE"
            // );

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

            bool isApproved = node.isOperator(params.controller, params.operator);
            // fl.eq(isApproved, params.approved, "NODE_OPERATOR_STATUS");

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
            uint256 allowance = node.allowance(caller, params.spender);
            // fl.eq(allowance, params.amount, "NODE_APPROVE_ALLOWANCE");
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

            ActorState storage beforeSender = states[0].actorStates[sender];
            ActorState storage afterSender = states[1].actorStates[sender];
            ActorState storage beforeReceiver = states[0].actorStates[params.receiver];
            ActorState storage afterReceiver = states[1].actorStates[params.receiver];

            // fl.eq(afterSender.shareBalance, beforeSender.shareBalance - params.amount, "NODE_TRANSFER_SENDER_BALANCE");
            // fl.eq(
            // afterReceiver.shareBalance,
            // beforeReceiver.shareBalance + params.amount,
            // "NODE_TRANSFER_RECEIVER_BALANCE"
            // );
            // fl.eq(states[1].nodeTotalSupply, states[0].nodeTotalSupply, "NODE_TRANSFER_TOTAL_SUPPLY");
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

            ActorState storage beforeOwner = states[0].actorStates[params.owner];
            ActorState storage afterOwner = states[1].actorStates[params.owner];
            ActorState storage beforeReceiver = states[0].actorStates[params.receiver];
            ActorState storage afterReceiver = states[1].actorStates[params.receiver];

            // fl.eq(afterOwner.shareBalance, beforeOwner.shareBalance - params.amount, "NODE_TRANSFER_FROM_OWNER_BAL");
            // fl.eq(afterReceiver.shareBalance, beforeReceiver.shareBalance + params.amount, "NODE_TRANSFER_FROM_RCV_BAL");

            uint256 allowanceAfter = node.allowance(params.owner, spender);
            // fl.eq(
            // allowanceAfter,
            // params.allowanceBefore >= params.amount ? params.allowanceBefore - params.amount : 0,
            // "NODE_TRANSFER_FROM_ALLOWANCE"
            // );

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

            // fl.eq(
            // afterController.claimableRedeem,
            // beforeController.claimableRedeem - params.shares,
            // "NODE_REDEEM_CLAIMABLE_SHARES"
            // );
            // fl.eq(
            // afterController.claimableAssets,
            // beforeController.claimableAssets - assetsReturned,
            // "NODE_REDEEM_CLAIMABLE_ASSETS"
            // );
            // fl.eq(afterReceiver.assetBalance, beforeReceiver.assetBalance + assetsReturned, "NODE_REDEEM_RECEIVER_ASSETS");
            // fl.eq(
            // states[1].nodeEscrowAssetBalance,
            // states[0].nodeEscrowAssetBalance - assetsReturned,
            // "NODE_REDEEM_ESCROW_BALANCE"
            // );

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
        // fl.t(!success, "NODE_RENOUNCE_SHOULD_REVERT");
        onFailInvariantsGeneral(returnData);
    }

    function nodeTransferOwnershipPostconditions(
        bool success,
        bytes memory returnData,
        NodeOwnershipParams memory params
    ) internal {
        // fl.t(!success, "NODE_TRANSFER_OWNERSHIP_SHOULD_REVERT");
        onFailInvariantsGeneral(returnData);
    }

    function nodeInitializePostconditions(bool success, bytes memory returnData, NodeInitializeParams memory params)
        internal
    {
        params; // silence warning
        // fl.t(!success, "NODE_INITIALIZE_SHOULD_REVERT");
        onFailInvariantsGeneral(returnData);
    }

    function nodeSetAnnualFeePostconditions(bool success, bytes memory returnData, NodeFeeParams memory params)
        internal
    {
        if (success) {
            // fl.eq(node.annualManagementFee(), params.fee, "NODE_SET_ANNUAL_FEE_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetMaxDepositPostconditions(bool success, bytes memory returnData, NodeUintParams memory params)
        internal
    {
        if (success) {
            // fl.eq(node.maxDepositSize(), params.value, "NODE_SET_MAX_DEPOSIT_VALUE");
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
            // fl.eq(node.nodeOwnerFeeAddress(), params.target, "NODE_SET_FEE_ADDRESS_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetQuoterPostconditions(bool success, bytes memory returnData, NodeAddressParams memory params)
        internal
    {
        if (success) {
            // fl.eq(address(node.quoter()), params.target, "NODE_SET_QUOTER_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetRebalanceCooldownPostconditions(bool success, bytes memory returnData, NodeFeeParams memory params)
        internal
    {
        if (success) {
            // fl.eq(uint256(Node(address(node)).rebalanceCooldown()), uint256(params.fee), "NODE_SET_COOLDOWN_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetRebalanceWindowPostconditions(bool success, bytes memory returnData, NodeFeeParams memory params)
        internal
    {
        if (success) {
            // fl.eq(uint256(Node(address(node)).rebalanceWindow()), uint256(params.fee), "NODE_SET_WINDOW_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeSetLiquidationQueuePostconditions(bool success, bytes memory returnData, NodeQueueParams memory params)
        internal
    {
        if (success) {
            address[] memory queue = node.getLiquidationsQueue();
            // fl.eq(queue.length, params.queue.length, "NODE_SET_QUEUE_LENGTH");
            for (uint256 i = 0; i < queue.length; i++) {
                // fl.eq(queue[i], params.queue[i], "NODE_SET_QUEUE_VALUE");
            }
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

            // fl.eq(nodeBalanceAfter, params.nodeBalanceBefore - params.amount, "NODE_RESCUE_NODE_BALANCE");
            // fl.eq(
            // recipientBalanceAfter,
            // params.recipientBalanceBefore + params.amount,
            // "NODE_RESCUE_RECIPIENT_BALANCE"
            // );

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
            // fl.t(node.isComponent(params.component), "NODE_ADD_COMPONENT_STATUS");
            ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
            // fl.eq(uint256(allocation.targetWeight), uint256(uint64(params.targetWeight)), "NODE_ADD_COMPONENT_WEIGHT");
            // fl.eq(uint256(allocation.maxDelta), uint256(uint64(params.maxDelta)), "NODE_ADD_COMPONENT_DELTA");
            // fl.eq(allocation.router, params.router, "NODE_ADD_COMPONENT_ROUTER");

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
            // fl.t(!node.isComponent(params.component), "NODE_REMOVE_COMPONENT_STATUS");
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
            ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
            // fl.eq(uint256(allocation.targetWeight), uint256(uint64(params.targetWeight)), "NODE_UPDATE_COMPONENT_WEIGHT");
            // fl.eq(uint256(allocation.maxDelta), uint256(uint64(params.maxDelta)), "NODE_UPDATE_COMPONENT_DELTA");
            // fl.eq(allocation.router, params.router, "NODE_UPDATE_COMPONENT_ROUTER");
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
            // fl.eq(uint256(Node(address(node)).targetReserveRatio()), uint256(params.target), "NODE_UPDATE_TARGET_RESERVE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeEnableSwingPricingPostconditions(
        bool success,
        bytes memory returnData,
        NodeSwingPricingParams memory params
    ) internal {
        if (success) {
            // fl.eq(Node(address(node)).swingPricingEnabled(), params.status, "NODE_SWING_PRICING_STATUS");
            // fl.eq(uint256(Node(address(node)).maxSwingFactor()), uint256(params.maxSwingFactor), "NODE_SWING_PRICING_FACTOR");
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
                // fl.t(node.isSigPolicy(params.selectors[i], params.policies[i]), "NODE_POLICY_REGISTERED");
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
                // fl.t(!node.isSigPolicy(params.selectors[i], params.policies[i]), "NODE_POLICY_REMOVED");
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
            // fl.t(node.isRebalancer(params.target), "NODE_ADD_REBALANCER_STATUS");
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
            // fl.t(!node.isRebalancer(params.target), "NODE_REMOVE_REBALANCER_STATUS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function nodeAddRouterPostconditions(bool success, bytes memory returnData, NodeAddressParams memory params)
        internal
    {
        if (success) {
            // fl.t(node.isRouter(params.target), "NODE_ADD_ROUTER_STATUS");
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
            // fl.t(!node.isRouter(params.target), "NODE_REMOVE_ROUTER_STATUS");
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
            // fl.t(lastRebalanceAfter >= params.lastRebalanceBefore, "NODE_START_REBALANCE_TIMESTAMP");
            // fl.t(node.isCacheValid(), "NODE_START_REBALANCE_CACHE");
            // fl.t(node.validateComponentRatios(), "NODE_START_REBALANCE_RATIOS");

            ActorState storage ownerBefore = states[0].actorStates[node.nodeOwnerFeeAddress()];
            ActorState storage ownerAfter = states[1].actorStates[node.nodeOwnerFeeAddress()];
            ActorState storage protocolBefore = states[0].actorStates[protocolFeesAddress];
            ActorState storage protocolAfter = states[1].actorStates[protocolFeesAddress];

            uint256 ownerDelta = ownerAfter.assetBalance - ownerBefore.assetBalance;
            uint256 protocolDelta = protocolAfter.assetBalance - protocolBefore.assetBalance;
            uint256 nodeDelta = states[0].nodeAssetBalance - states[1].nodeAssetBalance;

            // fl.eq(ownerDelta + protocolDelta, nodeDelta, "NODE_START_REBALANCE_FEE_FLOW");
            // fl.t(states[1].nodeTotalAssets <= states[0].nodeTotalAssets, "NODE_START_REBALANCE_TOTAL_ASSETS");
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

            // fl.eq(ownerDelta + protocolDelta, nodeDelta, "NODE_PAY_FEES_FLOW");
            // fl.eq(feeForPeriod, ownerDelta + protocolDelta, "NODE_PAY_FEES_RETURN");
            uint256 lastPaymentAfter = uint256(Node(address(node)).lastPayment());
            if (feeForPeriod > 0) {
                // fl.t(lastPaymentAfter > params.lastPaymentBefore, "NODE_PAY_FEES_LAST_PAYMENT");
            } else {
                // fl.eq(lastPaymentAfter, params.lastPaymentBefore, "NODE_PAY_FEES_LAST_PAYMENT_ZERO");
            }
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
            // fl.t(uint256(node.totalAssets()) == states[1].nodeTotalAssets, "NODE_UPDATE_TOTAL_ASSETS_CACHE");
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

            // fl.eq(nodeDelta, params.fee, "NODE_SUBTRACT_FEE_NODE_DELTA");
            // fl.eq(protocolDelta, params.fee, "NODE_SUBTRACT_FEE_PROTOCOL_DELTA");
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
            // fl.eq(allowanceAfter, params.allowance, "NODE_EXECUTE_ALLOWANCE");
            // fl.eq(states[0].nodeAssetBalance, states[1].nodeAssetBalance, "NODE_EXECUTE_NODE_BALANCE");
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
            ActorState storage escrowAfter = states[1].actorStates[address(escrow)];
            ActorState storage escrowBefore = states[0].actorStates[address(escrow)];

            // fl.eq(
            // controllerAfter.pendingRedeem,
            // controllerBefore.pendingRedeem - params.sharesPending,
            // "NODE_FINALIZE_PENDING"
            // );
            // fl.eq(
            // controllerAfter.claimableRedeem,
            // controllerBefore.claimableRedeem + params.sharesPending,
            // "NODE_FINALIZE_CLAIMABLE_SHARES"
            // );
            // fl.eq(
            // controllerAfter.claimableAssets,
            // controllerBefore.claimableAssets + params.assetsToReturn,
            // "NODE_FINALIZE_CLAIMABLE_ASSETS"
            // );

            // fl.eq(
            // escrowAfter.assetBalance,
            // escrowBefore.assetBalance + params.assetsToReturn,
            // "NODE_FINALIZE_ESCROW_ASSETS"
            // );
            // fl.eq(
            // states[1].nodeAssetBalance,
            // params.nodeAssetBalanceBefore - params.assetsToReturn,
            // "NODE_FINALIZE_NODE_BALANCE"
            // );
            // fl.eq(states[1].sharesExiting, params.sharesExitingBefore - params.sharesAdjusted, "NODE_FINALIZE_SHARES_EXITING");
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
            fl.eq(balanceAfter, params.currentBacking + params.delta, "NODE_GAIN_BACKING_BALANCE_MISMATCH");
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
            fl.eq(balanceAfter, params.currentBacking - params.delta, "NODE_LOSE_BACKING_BALANCE_MISMATCH");
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
            fl.t(depositAmount > 0, "ROUTER4626_INVEST_ZERO_DEPOSIT");

            uint256 sharesAfter = IERC20(params.component).balanceOf(address(node));
            fl.t(sharesAfter >= params.sharesBefore, "ROUTER4626_INVEST_SHARES");

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            fl.t(nodeBalanceAfter <= params.nodeAssetBalanceBefore, "ROUTER4626_INVEST_NODE_BALANCE");

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
            fl.t(assetsReturned > 0, "ROUTER4626_LIQUIDATE_NO_ASSETS");

            uint256 sharesAfter = IERC20(params.component).balanceOf(address(node));
            fl.t(sharesAfter <= params.sharesBefore, "ROUTER4626_LIQUIDATE_SHARES");

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            fl.t(nodeBalanceAfter >= params.nodeAssetBalanceBefore, "ROUTER4626_LIQUIDATE_NODE_BALANCE");

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
            fl.t(assetsReturned > 0, "ROUTER4626_FULFILL_NO_ASSETS");

            uint256 escrowAfter = asset.balanceOf(address(escrow));
            uint256 nodeBalanceAfter = asset.balanceOf(address(node));

            fl.t(escrowAfter >= params.escrowBalanceBefore, "ROUTER4626_FULFILL_ESCROW");
            fl.t(nodeBalanceAfter <= params.nodeAssetBalanceBefore, "ROUTER4626_FULFILL_NODE_BALANCE");

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
            fl.eq(stored, params.status, "ROUTER_BLACKLIST_STATUS");
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
                fl.eq(stored, params.statuses[i], "ROUTER_WHITELIST_STATUS");
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
            fl.eq(stored, params.newTolerance, "ROUTER_TOLERANCE_VALUE");
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
            fl.t(assetsRequested > 0, "ROUTER7540_INVEST_ZERO");

            if (params.component != address(digiftAdapter)) {
                uint256 pendingAfter = ERC7540Mock(params.component).pendingAssets();
                fl.t(pendingAfter >= params.pendingDepositBefore, "ROUTER7540_INVEST_PENDING");
            }

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            fl.t(nodeBalanceAfter <= params.nodeAssetBalanceBefore, "ROUTER7540_INVEST_NODE_BALANCE");

            if (params.component == address(digiftAdapter)) {
                _recordDigiftPendingDeposit(address(node), params.component, assetsRequested);
            }

            invariant_NODE_07();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function router7540MintClaimablePostconditions( // solhint-disable-line max-line-length
    bool success, bytes memory returnData, RouterMintClaimableParams memory params)
        internal
    {
        if (success) {
            _after();

            uint256 sharesReceived = abi.decode(returnData, (uint256));
            fl.t(sharesReceived > 0, "ROUTER7540_MINT_ZERO");

            uint256 shareBalanceAfter = IERC20(params.component).balanceOf(address(node));
            fl.t(shareBalanceAfter >= params.shareBalanceBefore + sharesReceived, "ROUTER7540_MINT_SHARES");

            uint256 claimableAfter = IERC7540Deposit(params.component).claimableDepositRequest(0, address(node));
            fl.t(claimableAfter <= params.claimableAssetsBefore, "ROUTER7540_MINT_CLAIMABLE");

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
            fl.t(pendingAfter >= params.pendingRedeemBefore, "ROUTER7540_REQUEST_PENDING");

            uint256 shareBalanceAfter = IERC20(params.component).balanceOf(address(node));
            fl.t(shareBalanceAfter <= params.shareBalanceBefore, "ROUTER7540_REQUEST_SHARES");

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
            fl.t(assetsReturned > 0, "ROUTER7540_EXECUTE_NO_ASSETS");
            fl.eq(params.assets, params.maxWithdrawBefore, "ROUTER7540_EXECUTE_ASSET_PARAM");

            uint256 claimableAfter = IERC7540Redeem(params.component).claimableRedeemRequest(0, address(node));
            fl.t(claimableAfter <= params.claimableAssetsBefore, "ROUTER7540_EXECUTE_CLAIMABLE");

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            fl.t(nodeBalanceAfter >= params.nodeAssetBalanceBefore, "ROUTER7540_EXECUTE_NODE_BALANCE");

            uint256 maxWithdrawAfter = IERC7575(params.component).maxWithdraw(address(node));
            fl.eq(maxWithdrawAfter, 0, "ROUTER7540_EXECUTE_MAX_WITHDRAW");

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
            fl.t(assetsReturned > 0, "ROUTER7540_FULFILL_NO_ASSETS");

            uint256 escrowBalanceAfter = asset.balanceOf(address(escrow));
            fl.t(escrowBalanceAfter >= params.escrowBalanceBefore, "ROUTER7540_FULFILL_ESCROW_BALANCE");

            uint256 nodeBalanceAfter = asset.balanceOf(address(node));
            fl.t(nodeBalanceAfter <= params.nodeAssetBalanceBefore, "ROUTER7540_FULFILL_NODE_BALANCE");

            uint256 componentSharesAfter = IERC20(params.component).balanceOf(address(node));
            fl.t(componentSharesAfter <= params.componentSharesBefore, "ROUTER7540_FULFILL_COMPONENT_SHARES");

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function poolProcessPendingDepositsPostconditions( // solhint-disable-line max-line-length
    bool success, bytes memory returnData, PoolProcessParams memory params)
        internal
    {
        if (success) {
            _after();

            uint256 pendingAfter = ERC7540Mock(params.pool).pendingAssets();
            fl.t(pendingAfter <= params.pendingBefore, "POOL_PROCESS_PENDING_DELTA");

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
            fl.t(pendingAfter == 0, "POOL_PROCESS_REDEEM_PENDING_NOT_ZERO");

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
            fl.t(assetGain >= (params.minAssetsOut * 99) / 100, "Node should receive close to expected assets");

            // Incentive tokens should be transferred from node
            uint256 incentiveBalanceAfter = IERC20(params.incentive).balanceOf(nodeAddr);
            uint256 incentiveLoss = params.incentiveBalanceBefore - incentiveBalanceAfter;
            fl.eq(incentiveLoss, params.incentiveAmount, "Node should have spent incentive amount");

            // Executor should have received incentive tokens
            uint256 executorIncentiveBalance = IERC20(params.incentive).balanceOf(executorAddr);
            fl.gte(executorIncentiveBalance, params.incentiveAmount, "Executor should receive incentive tokens");

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
