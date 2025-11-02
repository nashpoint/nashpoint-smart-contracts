// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsDigiftAdapter.sol";
import "./helpers/postconditions/PostconditionsDigiftAdapter.sol";

import {DigiftAdapter} from "../../src/adapters/digift/DigiftAdapter.sol";
import {DigiftEventVerifier} from "../../src/adapters/digift/DigiftEventVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract FuzzDigiftAdapter is PreconditionsDigiftAdapter, PostconditionsDigiftAdapter {
// function fuzz_digift_seedNodeAssets(uint256 amountSeed) public {
//     _forceActor(owner, amountSeed);
//     DigiftAssetFundingParams memory params = digiftAssetFundingPreconditions(amountSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(assetToken),
//         abi.encodeWithSelector(ERC20Mock.mint.selector, address(node), params.amount),
//         owner
//     );
//     digiftAssetFundingPostconditions(success, returnData, params);
// }
// function fuzz_digift_approveNodeAssets(uint256 amountSeed) public {
//     _forceActor(address(node), amountSeed);
//     DigiftAssetApprovalParams memory params = digiftAssetApprovalPreconditions(amountSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(assetToken),
//         abi.encodeWithSelector(IERC20.approve.selector, address(digiftAdapter), params.amount),
//         address(node)
//     );
//     digiftAssetApprovalPostconditions(success, returnData, params);
// }
// function fuzz_digift_approve(uint256 spenderSeed, uint256 amountSeed) public {
//     _forceActor(address(node), amountSeed);
//     DigiftApproveParams memory params = digiftApprovePreconditions(spenderSeed, amountSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(IERC20.approve.selector, params.spender, params.amount),
//         address(node)
//     );
//     digiftApprovePostconditions(success, returnData, address(node), params);
// }
// function fuzz_digift_transfer(uint256 recipientSeed, uint256 amountSeed) public {
//     _forceActor(address(node), amountSeed);
//     DigiftTransferParams memory params = digiftTransferPreconditions(recipientSeed, amountSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(IERC20.transfer.selector, params.to, params.amount),
//         address(node)
//     );
//     digiftTransferPostconditions(success, returnData, address(node), params);
// }
// function fuzz_digift_transferFrom(uint256 recipientSeed, uint256 amountSeed) public {
//     address spender = _selectAddressFromSeed(amountSeed);
//     _forceActor(spender, amountSeed);
//     DigiftTransferParams memory params = digiftTransferFromPreconditions(spender, recipientSeed, amountSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(IERC20.transferFrom.selector, address(node), params.to, params.amount),
//         spender
//     );
//     digiftTransferPostconditions(success, returnData, address(node), params);
// }
// function fuzz_digift_requestDeposit(uint256 amountSeed) public {
//     _forceActor(address(node), amountSeed);
//     DigiftRequestParams memory params = digiftRequestDepositPreconditions(amountSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.requestDeposit.selector, params.amount, address(node), address(node)),
//         address(node)
//     );
//     digiftRequestDepositPostconditions(success, returnData, params);
// }
// function fuzz_digift_requestRedeem(uint256 shareSeed) public {
//     _forceActor(address(node), shareSeed);
//     DigiftRequestParams memory params = digiftRequestRedeemPreconditions(shareSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.requestRedeem.selector, params.amount, address(node), address(node)),
//         address(node)
//     );
//     digiftRequestRedeemPostconditions(success, returnData, params);
// }
// function fuzz_digift_forwardRequests(bool expectDeposit, bool expectRedeem) public {
//     _forceActor(rebalancer, expectDeposit ? 1 : 2);
//     DigiftForwardParams memory params = digiftForwardPreconditions(expectDeposit, expectRedeem);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter), abi.encodeWithSelector(DigiftAdapter.forwardRequestsToDigift.selector), rebalancer
//     );
//     digiftForwardPostconditions(success, returnData, params);
// }
// function fuzz_digift_settleDeposit(uint256 shareSeed, uint256 assetSeed) public {
//     _forceActor(rebalancer, shareSeed);
//     DigiftSettleParams memory params = digiftSettleDepositPreconditions(shareSeed, assetSeed);
//     DigiftEventVerifier.OffchainArgs memory args = DigiftEventVerifier.OffchainArgs({
//         blockNumber: block.number,
//         headerRlp: bytes(""),
//         txIndex: bytes(""),
//         proof: new bytes[](0)
//     });
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.settleDeposit.selector, params.nodes, args),
//         rebalancer
//     );
//     digiftSettlePostconditions(success, returnData, params, true);
// }
// function fuzz_digift_settleRedeem(uint256 shareSeed, uint256 assetSeed) public {
//     _forceActor(rebalancer, shareSeed);
//     DigiftSettleParams memory params = digiftSettleRedeemPreconditions(shareSeed, assetSeed);
//     DigiftEventVerifier.OffchainArgs memory args = DigiftEventVerifier.OffchainArgs({
//         blockNumber: block.number,
//         headerRlp: bytes(""),
//         txIndex: bytes(""),
//         proof: new bytes[](0)
//     });
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.settleRedeem.selector, params.nodes, args),
//         rebalancer
//     );
//     digiftSettlePostconditions(success, returnData, params, false);
// }
// function fuzz_digift_mint(uint256 shareSeed) public {
//     _forceActor(address(node), shareSeed);
//     DigiftMintParams memory params = digiftMintPreconditions(shareSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSignature("mint(uint256,address,address)", params.shares, address(node), address(node)),
//         address(node)
//     );
//     digiftMintPostconditions(success, returnData, params);
// }
// function fuzz_digift_withdraw(uint256 assetSeed) public {
//     _forceActor(address(node), assetSeed);
//     DigiftWithdrawParams memory params = digiftWithdrawPreconditions(assetSeed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.withdraw.selector, params.assets, address(node), address(node)),
//         address(node)
//     );
//     digiftWithdrawPostconditions(success, returnData, params);
// }
// function fuzz_digift_setManager(uint256 seed, bool status) public {
//     DigiftSetAddressBoolParams memory params = digiftSetAddressBoolPreconditions(seed, status);
//     vm.startPrank(owner);
//     params.target = params.target == address(0) ? rebalancer : params.target;
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setManager.selector, params.target, params.status),
//         owner
//     );
//     vm.stopPrank();
//     digiftSetAddressBoolPostconditions(success, returnData, params, true);
// }
// function fuzz_digift_setNode(uint256 seed, bool status) public {
//     DigiftSetAddressBoolParams memory params = digiftSetAddressBoolPreconditions(seed, status);
//     params.target = address(node);
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setNode.selector, params.target, params.status),
//         owner
//     );
//     vm.stopPrank();
//     digiftSetAddressBoolPostconditions(success, returnData, params, false);
// }
// function fuzz_digift_setMinDeposit(uint256 valueSeed) public {
//     DigiftSetUintParams memory params = digiftSetUintPreconditions(valueSeed, 10_000e6);
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setMinDepositAmount.selector, params.value),
//         owner
//     );
//     vm.stopPrank();
//     digiftSetUintPostconditions(success, returnData, params, 0);
// }
// function fuzz_digift_setMinRedeem(uint256 valueSeed) public {
//     DigiftSetUintParams memory params = digiftSetUintPreconditions(valueSeed, 100e18);
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setMinRedeemAmount.selector, params.value),
//         owner
//     );
//     vm.stopPrank();
//     digiftSetUintPostconditions(success, returnData, params, 1);
// }
// function fuzz_digift_setPriceDeviation(uint256 valueSeed) public {
//     DigiftSetUintParams memory params = digiftSetUintPreconditions(valueSeed, 1e17);
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setPriceDeviation.selector, params.value),
//         owner
//     );
//     vm.stopPrank();
//     digiftSetUintPostconditions(success, returnData, params, 2);
// }
// function fuzz_digift_setSettlementDeviation(uint256 valueSeed) public {
//     DigiftSetUintParams memory params = digiftSetUintPreconditions(valueSeed, 1e17);
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setSettlementDeviation.selector, params.value),
//         owner
//     );
//     vm.stopPrank();
//     digiftSetUintPostconditions(success, returnData, params, 3);
// }
// function fuzz_digift_setPriceUpdateDeviation(uint256 valueSeed) public {
//     DigiftSetUintParams memory params = digiftSetUintPreconditions(valueSeed, 7 days);
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setPriceUpdateDeviation.selector, params.value),
//         owner
//     );
//     vm.stopPrank();
//     digiftSetUintPostconditions(success, returnData, params, 4);
// }
// function fuzz_digift_forceUpdateLastPrice() public {
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter), abi.encodeWithSelector(DigiftAdapter.forceUpdateLastPrice.selector), owner
//     );
//     vm.stopPrank();
//     digiftUpdatePricePostconditions(success, returnData);
// }
// function fuzz_digift_updateLastPrice() public {
//     _forceActor(rebalancer, 0);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter), abi.encodeWithSelector(DigiftAdapter.updateLastPrice.selector), rebalancer
//     );
//     digiftUpdatePricePostconditions(success, returnData);
// }
// function fuzz_digift_setOperator(uint256 seed, bool approval) public {
//     address operator = _selectAddressFromSeed(seed);
//     _forceActor(address(node), seed);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter),
//         abi.encodeWithSelector(DigiftAdapter.setOperator.selector, operator, approval),
//         address(node)
//     );
//     fl.t(!success, "DIGIFT_SET_OPERATOR_SHOULD_REVERT");
//     onFailInvariantsGeneral(returnData);
// }
// function fuzz_digift_depositUnsupported(uint256 amountSeed) public {
//     _forceActor(address(node), amountSeed);
//     uint256 amount = fl.clamp(amountSeed, 1, 1_000e6);
//     bytes memory callData = abi.encodeWithSelector(
//         bytes4(keccak256("deposit(uint256,address,address)")), amount, address(node), address(node)
//     );
//     (bool success, bytes memory returnData) = fl.doFunctionCall(address(digiftAdapter), callData, address(node));
//     fl.t(!success, "DIGIFT_DEPOSIT_SHOULD_REVERT");
//     onFailInvariantsGeneral(returnData);
// }
// function fuzz_digift_redeemUnsupported(uint256 shareSeed) public {
//     _forceActor(address(node), shareSeed);
//     uint256 shares = fl.clamp(shareSeed, 1, 1e18);
//     bytes memory callData = abi.encodeWithSelector(
//         bytes4(keccak256("redeem(uint256,address,address)")), shares, address(node), address(node)
//     );
//     (bool success, bytes memory returnData) = fl.doFunctionCall(address(digiftAdapter), callData, address(node));
//     fl.t(!success, "DIGIFT_REDEEM_SHOULD_REVERT");
//     onFailInvariantsGeneral(returnData);
// }
// function fuzz_digift_initialize() public {
//     DigiftAdapter.InitArgs memory dummy = DigiftAdapter.InitArgs({
//         name: "dup",
//         symbol: "dup",
//         asset: address(assetToken),
//         assetPriceOracle: address(assetPriceOracleMock),
//         stToken: address(stToken),
//         dFeedPriceOracle: address(digiftPriceOracleMock),
//         priceDeviation: 1,
//         settlementDeviation: 1,
//         priceUpdateDeviation: 1,
//         minDepositAmount: 1,
//         minRedeemAmount: 1
//     });
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter), abi.encodeWithSelector(DigiftAdapter.initialize.selector, dummy), owner
//     );
//     fl.t(!success, "DIGIFT_INITIALIZE_SHOULD_REVERT");
//     onFailInvariantsGeneral(returnData);
// }
}
