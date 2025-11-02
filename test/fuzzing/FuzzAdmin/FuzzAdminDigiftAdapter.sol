// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/preconditions/PreconditionsDigiftAdapter.sol";
import "../helpers/postconditions/PostconditionsDigiftAdapter.sol";

import {DigiftAdapter} from "../../../src/adapters/digift/DigiftAdapter.sol";

/**
 * @title FuzzAdminDigiftAdapter
 * @notice Fuzzing handlers for DigiftAdapter administrative functions (Category 2)
 * @dev These handlers test functions restricted to onlyRegistryOwner:
 *      - forceUpdateLastPrice
 *      - setManager
 *      - setMinDepositAmount
 *      - setMinRedeemAmount
 *      - setNode
 *      - setPriceDeviation
 *      - setPriceUpdateDeviation
 *      - setSettlementDeviation
 *
 * All handlers are currently commented out and can be enabled for targeted admin testing.
 */
contract FuzzAdminDigiftAdapter is PreconditionsDigiftAdapter, PostconditionsDigiftAdapter {
// ========================================
// CATEGORY 2: ADMIN FUNCTIONS (onlyRegistryOwner)
// ========================================

// function fuzz_admin_digift_forceUpdateLastPrice() public {
//     vm.startPrank(owner);
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftAdapter), abi.encodeWithSelector(DigiftAdapter.forceUpdateLastPrice.selector), owner
//     );
//     vm.stopPrank();
//     digiftUpdatePricePostconditions(success, returnData);
// }

// function fuzz_admin_digift_setManager(uint256 seed, bool status) public {
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

// function fuzz_admin_digift_setMinDepositAmount(uint256 valueSeed) public {
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

// function fuzz_admin_digift_setMinRedeemAmount(uint256 valueSeed) public {
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

// function fuzz_admin_digift_setNode(uint256 seed, bool status) public {
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

// function fuzz_admin_digift_setPriceDeviation(uint256 valueSeed) public {
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

// function fuzz_admin_digift_setPriceUpdateDeviation(uint256 valueSeed) public {
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

// function fuzz_admin_digift_setSettlementDeviation(uint256 valueSeed) public {
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
}
