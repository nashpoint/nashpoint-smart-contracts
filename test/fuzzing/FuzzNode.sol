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

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC7575.deposit.selector, params.assets, params.receiver),
            currentActor
        );

        depositPostconditions(success, returnData, params);
    }

    function fuzz_mint(uint256 shareSeed) public setCurrentActor(shareSeed) {
        MintParams memory params = mintPreconditions(shareSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(IERC7575.mint.selector, params.shares, params.receiver), currentActor
        );

        mintPostconditions(success, returnData, params);
    }

    function fuzz_requestRedeem(uint256 shareSeed) public setCurrentActor(shareSeed) {
        RequestRedeemParams memory params = requestRedeemPreconditions(shareSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.requestRedeem.selector, params.shares, params.controller, params.owner),
            currentActor
        );

        requestRedeemPostconditions(success, returnData, params);
    }

    function fuzz_withdraw(uint256 controllerSeed, uint256 assetsSeed) public {
        WithdrawParams memory params = withdrawPreconditions(controllerSeed, assetsSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC7575.withdraw.selector, params.assets, params.receiver, params.controller),
            params.controller
        );

        withdrawPostconditions(success, returnData, params);
    }

    function fuzz_node_redeem(uint256 shareSeed) public {
        NodeRedeemParams memory params = nodeRedeemPreconditions(shareSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC7575.redeem.selector, params.shares, params.receiver, params.controller),
            params.controller
        );

        nodeRedeemPostconditions(success, returnData, params);
    }

    function fuzz_setOperator(uint256 operatorSeed, bool approvalSeed) public setCurrentActor(operatorSeed) {
        SetOperatorParams memory params = setOperatorPreconditions(operatorSeed, approvalSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.setOperator.selector, params.operator, params.approved),
            currentActor
        );

        setOperatorPostconditions(success, returnData, params);
    }

    function fuzz_node_approve(uint256 spenderSeed, uint256 amountSeed) public setCurrentActor(spenderSeed) {
        NodeApproveParams memory params = nodeApprovePreconditions(spenderSeed, amountSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node), abi.encodeWithSelector(IERC20.approve.selector, params.spender, params.amount), currentActor
        );

        nodeApprovePostconditions(success, returnData, currentActor, params);
    }

    function fuzz_node_transfer(uint256 receiverSeed, uint256 amountSeed) public setCurrentActor(receiverSeed) {
        NodeTransferParams memory params = nodeTransferPreconditions(receiverSeed, amountSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC20.transfer.selector, params.receiver, params.amount),
            currentActor
        );

        nodeTransferPostconditions(success, returnData, currentActor, params);
    }

    function fuzz_node_transferFrom(uint256 ownerSeed, uint256 amountSeed) public setCurrentActor(ownerSeed) {
        NodeTransferFromParams memory params = nodeTransferFromPreconditions(ownerSeed, amountSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(IERC20.transferFrom.selector, params.owner, params.receiver, params.amount),
            currentActor
        );

        nodeTransferFromPostconditions(success, returnData, currentActor, params);
    }

    function fuzz_node_submitPolicyData(uint256 seed) public {
        NodeSubmitPolicyDataParams memory params = nodeSubmitPolicyDataPreconditions(seed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.submitPolicyData.selector, params.selector, params.policy, params.data),
            params.caller
        );

        nodeSubmitPolicyDataPostconditions(success, returnData, params);
    }

    function fuzz_node_multicall(uint256 seed) public {
        NodeMulticallParams memory params = nodeMulticallPreconditions(seed);

        // Skip if preconditions indicate failure (e.g., corrupted balance)
        if (!params.shouldSucceed) {
            return;
        }

        _before();

        bytes4 multicallSelector = bytes4(keccak256("multicall(bytes[])"));

        (bool success, bytes memory returnData) =
            fl.doFunctionCall(address(node), abi.encodeWithSelector(multicallSelector, params.calls), params.caller);

        nodeMulticallPostconditions(success, returnData, params);
    }

    // ============================================
    // ENVIRONMENT SIMULATION: COMPONENT YIELDS
    // ============================================

    function fuzz_component_gainBacking(uint256 componentSeed, uint256 amountSeed) public {
        NodeYieldParams memory params = nodeGainBackingPreconditions(componentSeed, amountSeed);

        _before();

        fl.log("GAIN_BACKING:component", params.component);
        fl.log("GAIN_BACKING:delta", params.delta);
        fl.log("GAIN_BACKING:backingToken", params.backingToken);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            params.backingToken,
            abi.encodeWithSelector(ERC20Mock.mint.selector, params.component, params.delta),
            params.caller
        );

        nodeGainBackingPostconditions(success, returnData, params);
    }

    function fuzz_component_loseBacking(uint256 componentSeed, uint256 amountSeed) public {
        NodeYieldParams memory params = nodeLoseBackingPreconditions(componentSeed, amountSeed);

        _before();

        fl.log("LOSE_BACKING:component", params.component);
        fl.log("LOSE_BACKING:delta", params.delta);
        fl.log("LOSE_BACKING:backingToken", params.backingToken);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            params.backingToken,
            abi.encodeWithSelector(ERC20Mock.burn.selector, params.component, params.delta),
            params.caller
        );

        nodeLoseBackingPostconditions(success, returnData, params);
    }
}
