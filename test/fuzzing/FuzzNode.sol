// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsNode.sol";
import "./helpers/postconditions/PostconditionsNode.sol";

import {INode} from "../../src/interfaces/INode.sol";
import {IERC7575} from "../../src/interfaces/IERC7575.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

/**
 * @title FuzzNode
 * @notice Handler contract implementing UniversalFuzzing 5-stage pattern for Node operations
 * @dev Contains only END USER functions (Category 1)
 *      Admin functions are in FuzzAdminNode.sol
 *      Internal protocol functions have been removed
 */
contract FuzzNode is PreconditionsNode, PostconditionsNode {
    // ============================================
    // CATEGORY 1: END USER FUNCTIONS
    // ============================================

    function fuzz_deposit(uint256 amountSeed) public setCurrentActor(amountSeed) {
        DepositParams memory params = depositPreconditions(amountSeed);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = params.receiver;
        _before(actorsToUpdate);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC7575.deposit.selector, params.assets, params.receiver),
            currentActor
        );

        depositPostconditions(success, returnData, actorsToUpdate, params);
    }

    function fuzz_mint(uint256 shareSeed) public setCurrentActor(shareSeed) {
        MintParams memory params = mintPreconditions(shareSeed);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = params.receiver;
        _before(actorsToUpdate);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(IERC7575.mint.selector, params.shares, params.receiver), currentActor
        );

        mintPostconditions(success, returnData, actorsToUpdate, params);
    }

    function fuzz_requestRedeem(uint256 shareSeed) public setCurrentActor(shareSeed) {
        RequestRedeemParams memory params = requestRedeemPreconditions(shareSeed);

        address[] memory actorsToUpdate = new address[](2);
        actorsToUpdate[0] = params.owner;
        actorsToUpdate[1] = address(escrow);
        _before(actorsToUpdate);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.requestRedeem.selector, params.shares, params.controller, params.owner),
            currentActor
        );

        requestRedeemPostconditions(success, returnData, actorsToUpdate, params);
    }

    function fuzz_withdraw(uint256 controllerSeed, uint256 assetsSeed) public {
        WithdrawParams memory params = withdrawPreconditions(controllerSeed, assetsSeed);

        _forceActor(params.controller, controllerSeed);

        address[] memory actorsToUpdate = new address[](3);
        actorsToUpdate[0] = params.controller;
        actorsToUpdate[1] = params.receiver;
        actorsToUpdate[2] = address(escrow);
        _before(actorsToUpdate);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC7575.withdraw.selector, params.assets, params.receiver, params.controller),
            currentActor
        );

        withdrawPostconditions(success, returnData, actorsToUpdate, params);
    }

    function fuzz_node_redeem(uint256 shareSeed) public {
        NodeRedeemParams memory params = nodeRedeemPreconditions(shareSeed);

        _forceActor(params.controller, shareSeed);

        address[] memory actors = new address[](3);
        actors[0] = params.controller;
        actors[1] = params.receiver;
        actors[2] = address(escrow);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC7575.redeem.selector, params.shares, params.receiver, params.controller),
            currentActor
        );

        nodeRedeemPostconditions(success, returnData, actors, params);
    }

    function fuzz_setOperator(uint256 operatorSeed, bool approvalSeed) public setCurrentActor(operatorSeed) {
        SetOperatorParams memory params = setOperatorPreconditions(operatorSeed, approvalSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.setOperator.selector, params.operator, params.approved),
            currentActor
        );

        setOperatorPostconditions(success, returnData, params);
    }

    function fuzz_node_approve(uint256 spenderSeed, uint256 amountSeed) public setCurrentActor(spenderSeed) {
        NodeApproveParams memory params = nodeApprovePreconditions(spenderSeed, amountSeed);

        address[] memory actors = new address[](2);
        actors[0] = currentActor;
        actors[1] = params.spender;
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(IERC20.approve.selector, params.spender, params.amount), currentActor
        );

        nodeApprovePostconditions(success, returnData, actors, currentActor, params);
    }

    function fuzz_node_transfer(uint256 receiverSeed, uint256 amountSeed) public setCurrentActor(receiverSeed) {
        NodeTransferParams memory params = nodeTransferPreconditions(receiverSeed, amountSeed);

        address[] memory actors = new address[](2);
        actors[0] = currentActor;
        actors[1] = params.receiver;
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC20.transfer.selector, params.receiver, params.amount),
            currentActor
        );

        nodeTransferPostconditions(success, returnData, actors, currentActor, params);
    }

    function fuzz_node_transferFrom(uint256 ownerSeed, uint256 amountSeed) public setCurrentActor(ownerSeed) {
        NodeTransferFromParams memory params = nodeTransferFromPreconditions(ownerSeed, amountSeed);

        address[] memory actors = new address[](2);
        actors[0] = params.owner;
        actors[1] = params.receiver;
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC20.transferFrom.selector, params.owner, params.receiver, params.amount),
            currentActor
        );

        nodeTransferFromPostconditions(success, returnData, actors, currentActor, params);
    }

    function fuzz_node_submitPolicyData(uint256 seed) public {
        NodeSubmitPolicyDataParams memory params = nodeSubmitPolicyDataPreconditions(seed);
        _forceActor(params.caller, seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.submitPolicyData.selector, params.selector, params.policy, params.data),
            currentActor
        );

        nodeSubmitPolicyDataPostconditions(success, returnData, params);
    }

    function fuzz_node_multicall(uint256 seed) public {
        NodeMulticallParams memory params = nodeMulticallPreconditions(seed);
        _forceActor(params.caller, seed);

        bytes4 multicallSelector = bytes4(keccak256("multicall(bytes[])"));

        (bool success, bytes memory returnData) =
            fl.doFunctionCall(address(node), abi.encodeWithSelector(multicallSelector, params.calls), currentActor);

        nodeMulticallPostconditions(success, returnData, params);
    }

    // ============================================
    // ENVIRONMENT SIMULATION: COMPONENT YIELDS
    // ============================================

    function fuzz_component_gainBacking(uint256 componentSeed, uint256 amountSeed) public {
        NodeYieldParams memory params = nodeGainBackingPreconditions(componentSeed, amountSeed);

        _forceActor(params.caller, componentSeed);

        fl.log("GAIN_BACKING:component", params.component);
        fl.log("GAIN_BACKING:delta", params.delta);
        fl.log("GAIN_BACKING:backingToken", params.backingToken);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            params.backingToken,
            abi.encodeWithSelector(ERC20Mock.mint.selector, params.component, params.delta),
            currentActor
        );

        nodeGainBackingPostconditions(success, returnData, params);
    }

    function fuzz_component_loseBacking(uint256 componentSeed, uint256 amountSeed) public {
        NodeYieldParams memory params = nodeLoseBackingPreconditions(componentSeed, amountSeed);

        _forceActor(params.caller, componentSeed);

        fl.log("LOSE_BACKING:component", params.component);
        fl.log("LOSE_BACKING:delta", params.delta);
        fl.log("LOSE_BACKING:backingToken", params.backingToken);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            params.backingToken,
            abi.encodeWithSelector(ERC20Mock.burn.selector, params.component, params.delta),
            currentActor
        );

        nodeLoseBackingPostconditions(success, returnData, params);
    }

    // ============================================
    // REMOVED: CATEGORY 3 (Internal Protocol Functions)
    // ============================================
    // The following handlers have been DELETED as they are internal protocol functions:
    // - fuzz_fulfillRedeem (onlyRebalancer, onlyWhenRebalancing)
    // - fuzz_node_startRebalance (onlyRebalancer)
    // - fuzz_node_subtractProtocolExecutionFee (onlyRouter)
    // - fuzz_node_execute (onlyRouter)
    // - fuzz_node_finalizeRedemption (onlyRouter)

    // ============================================
    // MOVED: CATEGORY 2 (Admin Functions)
    // ============================================
    // The following handlers have been MOVED to FuzzAdminNode.sol:
    // - fuzz_node_payManagementFees (onlyOwnerOrRebalancer) → fuzz_admin_node_payManagementFees
    // - fuzz_node_updateTotalAssets (onlyOwnerOrRebalancer) → fuzz_admin_node_updateTotalAssets
}
