// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzNode.sol";

import {INode} from "../../src/interfaces/INode.sol";
import {Node} from "../../src/Node.sol";
import {Node} from "../../src/Node.sol";

contract FuzzNodeAdmin is FuzzNode {
    function fuzz_node_setAnnualManagementFee(uint256 seed) public {
        _forceActor(owner, seed);
        NodeFeeParams memory params = nodeSetAnnualFeePreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.setAnnualManagementFee.selector, params.fee), currentActor
        );

        nodeSetAnnualFeePostconditions(success, returnData, params);
    }

    function fuzz_node_setMaxDepositSize(uint256 seed) public {
        _forceActor(owner, seed);
        NodeUintParams memory params = nodeSetMaxDepositPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.setMaxDepositSize.selector, params.value), currentActor
        );

        nodeSetMaxDepositPostconditions(success, returnData, params);
    }

    function fuzz_node_setNodeOwnerFeeAddress(uint256 seed) public {
        _forceActor(owner, seed);
        NodeAddressParams memory params = nodeSetNodeOwnerFeeAddressPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.setNodeOwnerFeeAddress.selector, params.target), currentActor
        );

        nodeSetNodeOwnerFeeAddressPostconditions(success, returnData, params);
    }

    function fuzz_node_setQuoter() public {
        _forceActor(owner, 0);
        NodeAddressParams memory params = nodeSetQuoterPreconditions();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.setQuoter.selector, params.target), currentActor
        );

        nodeSetQuoterPostconditions(success, returnData, params);
    }

    function fuzz_node_setRebalanceCooldown(uint256 seed) public {
        _forceActor(owner, seed);
        NodeFeeParams memory params = nodeSetRebalanceCooldownPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.setRebalanceCooldown.selector, params.fee), currentActor
        );

        nodeSetRebalanceCooldownPostconditions(success, returnData, params);
    }

    function fuzz_node_setRebalanceWindow(uint256 seed) public {
        _forceActor(owner, seed);
        NodeFeeParams memory params = nodeSetRebalanceWindowPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.setRebalanceWindow.selector, params.fee), currentActor
        );

        nodeSetRebalanceWindowPostconditions(success, returnData, params);
    }

    function fuzz_node_setLiquidationQueue(uint256 seed) public {
        _forceActor(owner, seed);
        NodeQueueParams memory params = nodeSetLiquidationQueuePreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.setLiquidationQueue.selector, params.queue), currentActor
        );

        nodeSetLiquidationQueuePostconditions(success, returnData, params);
    }

    function fuzz_node_rescueTokens(uint256 amountSeed) public {
        _forceActor(owner, amountSeed);
        NodeRescueParams memory params = nodeRescueTokensPreconditions(amountSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.rescueTokens.selector, params.token, params.recipient, params.amount),
            currentActor
        );

        nodeRescueTokensPostconditions(success, returnData, params);
    }

    function fuzz_node_addComponent(uint256 seed) public {
        _forceActor(owner, seed);
        NodeComponentAllocationParams memory params = nodeAddComponentPreconditions(seed);

        uint64 targetWeight = uint64(params.targetWeight);
        uint64 maxDelta = uint64(params.maxDelta);
        params.targetWeight = targetWeight;
        params.maxDelta = maxDelta;

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.addComponent.selector, params.component, targetWeight, maxDelta, params.router),
            currentActor
        );

        nodeAddComponentPostconditions(success, returnData, params);
    }

    function fuzz_node_removeComponent(uint256 seed, bool forceFlag) public {
        _forceActor(owner, seed);
        NodeRemoveComponentParams memory params = nodeRemoveComponentPreconditions(seed, forceFlag);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.removeComponent.selector, params.component, params.force),
            currentActor
        );

        nodeRemoveComponentPostconditions(success, returnData, params);
    }

    function fuzz_node_updateComponentAllocation(uint256 seed) public {
        _forceActor(owner, seed);
        NodeComponentAllocationParams memory params = nodeUpdateComponentAllocationPreconditions(seed);

        uint64 targetWeight = uint64(params.targetWeight);
        uint64 maxDelta = uint64(params.maxDelta);
        params.targetWeight = targetWeight;
        params.maxDelta = maxDelta;

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(
                INode.updateComponentAllocation.selector, params.component, targetWeight, maxDelta, params.router
            ),
            currentActor
        );

        nodeUpdateComponentAllocationPostconditions(success, returnData, params);
    }

    function fuzz_node_updateTargetReserveRatio(uint256 seed) public {
        _forceActor(owner, seed);
        NodeTargetReserveParams memory params = nodeUpdateTargetReserveRatioPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, params.target), currentActor
        );

        nodeUpdateTargetReserveRatioPostconditions(success, returnData, params);
    }

    function fuzz_node_enableSwingPricing(uint256 seed, bool statusSeed) public {
        _forceActor(owner, seed);
        NodeSwingPricingParams memory params = nodeEnableSwingPricingPreconditions(seed, statusSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.enableSwingPricing.selector, params.status, params.maxSwingFactor),
            currentActor
        );

        nodeEnableSwingPricingPostconditions(success, returnData, params);
    }

    function fuzz_node_addPolicies(uint256 seed) public {
        _forceActor(owner, seed);
        NodePoliciesParams memory params = nodeAddPoliciesPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(
                INode.addPolicies.selector, params.proof, params.proofFlags, params.selectors, params.policies
            ),
            currentActor
        );

        nodeAddPoliciesPostconditions(success, returnData, params);
    }

    function fuzz_node_removePolicies(uint256 seed) public {
        _forceActor(owner, seed);
        NodePoliciesRemovalParams memory params = nodeRemovePoliciesPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.removePolicies.selector, params.selectors, params.policies),
            currentActor
        );

        nodeRemovePoliciesPostconditions(success, returnData, params);
    }

    function fuzz_node_addRebalancer(uint256 seed) public {
        _forceActor(owner, seed);
        NodeAddressParams memory params = nodeAddRebalancerPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.addRebalancer.selector, params.target), currentActor
        );

        nodeAddRebalancerPostconditions(success, returnData, params);
    }

    function fuzz_node_removeRebalancer(uint256 seed) public {
        _forceActor(owner, seed);
        NodeAddressParams memory params = nodeRemoveRebalancerPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.removeRebalancer.selector, params.target), currentActor
        );

        nodeRemoveRebalancerPostconditions(success, returnData, params);
    }

    function fuzz_node_addRouter(uint256 seed) public {
        _forceActor(owner, seed);
        NodeAddressParams memory params = nodeAddRouterPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.addRouter.selector, params.target), currentActor
        );

        nodeAddRouterPostconditions(success, returnData, params);
    }

    function fuzz_node_removeRouter(uint256 seed) public {
        _forceActor(owner, seed);
        NodeAddressParams memory params = nodeRemoveRouterPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(INode.removeRouter.selector, params.target), currentActor
        );

        nodeRemoveRouterPostconditions(success, returnData, params);
    }

    function fuzz_node_renounceOwnership(uint256 seed) public {
        NodeOwnershipParams memory params = nodeRenounceOwnershipPreconditions(seed);
        _forceActor(params.caller, seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(bytes4(keccak256("renounceOwnership()"))), currentActor
        );

        nodeRenounceOwnershipPostconditions(success, returnData, params);
    }

    function fuzz_node_transferOwnership(uint256 seed) public {
        NodeOwnershipParams memory params = nodeTransferOwnershipPreconditions(seed);
        _forceActor(params.caller, seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("transferOwnership(address)")), params.newOwner),
            currentActor
        );

        nodeTransferOwnershipPostconditions(success, returnData, params);
    }

    function fuzz_node_initialize(uint256 seed) public {
        NodeInitializeParams memory params = nodeInitializePreconditions(seed);
        _forceActor(owner, seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(Node.initialize.selector, params.initArgs, params.escrow),
            currentActor
        );

        nodeInitializePostconditions(success, returnData, params);
    }
}
