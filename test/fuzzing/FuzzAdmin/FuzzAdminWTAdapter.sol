// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/preconditions/PreconditionsWTAdapter.sol";
import "../helpers/postconditions/PostconditionsWTAdapter.sol";

import {WTAdapter} from "../../../src/adapters/wt/WTAdapter.sol";
import {AdapterBase} from "../../../src/adapters/AdapterBase.sol";
import {EventVerifierBase} from "../../../src/adapters/EventVerifierBase.sol";

/**
 * @title FuzzAdminWTAdapter
 * @notice Fuzzing handlers for WTAdapter administrative functions (Category 2)
 * @dev forwardRequests, settleDeposit, settleRedeem, settleDividend
 */
contract FuzzAdminWTAdapter is PreconditionsWTAdapter, PostconditionsWTAdapter {
    function fuzz_admin_wt_forwardRequests(uint256 seed) public {
        WTForwardRequestParams memory params = wtForwardRequestsPreconditions(seed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(wtAdapter), abi.encodeWithSelector(AdapterBase.forwardRequests.selector), params.caller
        );

        wtForwardRequestsPostconditions(success, returnData, params);
    }

    function fuzz_admin_wt_settleDeposit(uint256 seed) public {
        WTSettleDepositParams memory params = wtSettleDepositFlowPreconditions(seed);

        if (params.shouldSucceed) {
            // Mint fund tokens to adapter to simulate WT fund share minting
            wtFundToken.mint(address(wtAdapter), params.sharesExpected);

            vm.startPrank(owner);
            wtEventVerifier.configureTransferAmount(params.sharesExpected);
            vm.stopPrank();
        }

        address[] memory nodes = new address[](params.records.length);
        for (uint256 i = 0; i < params.records.length; i++) {
            nodes[i] = params.records[i].node;
        }

        EventVerifierBase.OffchainArgs memory verifyArgs;

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(wtAdapter),
            abi.encodeWithSelector(AdapterBase.settleDeposit.selector, nodes, verifyArgs),
            params.caller
        );

        wtSettleDepositFlowPostconditions(success, returnData, params);
    }

    function fuzz_admin_wt_settleRedeem(uint256 seed) public {
        WTSettleRedeemParams memory params = wtSettleRedeemFlowPreconditions(seed);

        if (params.shouldSucceed) {
            vm.startPrank(owner);
            wtEventVerifier.configureTransferAmount(params.assetsExpected);
            vm.stopPrank();
        }

        address[] memory nodes = new address[](params.records.length);
        for (uint256 i = 0; i < params.records.length; i++) {
            nodes[i] = params.records[i].node;
        }

        EventVerifierBase.OffchainArgs memory verifyArgs;

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(wtAdapter),
            abi.encodeWithSelector(AdapterBase.settleRedeem.selector, nodes, verifyArgs),
            params.caller
        );

        wtSettleRedeemFlowPostconditions(success, returnData, params);
    }

    function fuzz_admin_wt_settleDividend(uint256 seed) public {
        WTSettleDividendParams memory params = wtSettleDividendPreconditions(seed);

        if (params.shouldSucceed) {
            // Mint fund tokens to adapter to simulate dividend
            wtFundToken.mint(address(wtAdapter), params.dividendAmount);

            vm.startPrank(owner);
            wtEventVerifier.configureTransferAmount(params.dividendAmount);
            vm.stopPrank();
        }

        EventVerifierBase.OffchainArgs memory verifyArgs;

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(wtAdapter),
            abi.encodeWithSelector(WTAdapter.settleDividend.selector, params.nodes, verifyArgs),
            params.caller
        );

        wtSettleDividendPostconditions(success, returnData, params);
    }
}
