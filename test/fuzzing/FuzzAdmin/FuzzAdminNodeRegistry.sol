// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/preconditions/PreconditionsNodeRegistry.sol";
import "../helpers/postconditions/PostconditionsNodeRegistry.sol";

import {INodeRegistry} from "../../../src/interfaces/INodeRegistry.sol";
import {NodeRegistry} from "../../../src/NodeRegistry.sol";

/**
 * @title FuzzAdminNodeRegistry
 * @notice Fuzzing handlers for NodeRegistry admin functions (Category 2: onlyOwner)
 * @dev All handlers are commented out pending integration with admin fuzzing infrastructure
 *
 * Category 2 Functions (onlyOwner):
 * - renounceOwnership
 * - setPoliciesRoot
 * - setProtocolExecutionFee
 * - setProtocolFeeAddress
 * - setProtocolManagementFee
 * - setProtocolMaxSwingFactor
 * - setRegistryType
 * - transferOwnership
 * - upgradeToAndCall
 */
contract FuzzAdminNodeRegistry is PreconditionsNodeRegistry, PostconditionsNodeRegistry {
// function fuzz_admin_registry_setProtocolFeeAddress(uint256 seed) public {
//     RegistryAddressParams memory params = registrySetProtocolFeeAddressPreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry),
//         abi.encodeWithSelector(NodeRegistry.setProtocolFeeAddress.selector, params.target),
//         currentActor
//     );
//
//     registrySetProtocolFeeAddressPostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_setProtocolManagementFee(uint256 seed) public {
//     RegistryFeeParams memory params = registrySetProtocolManagementFeePreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry),
//         abi.encodeWithSelector(NodeRegistry.setProtocolManagementFee.selector, params.value),
//         currentActor
//     );
//
//     registrySetProtocolManagementFeePostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_setProtocolExecutionFee(uint256 seed) public {
//     RegistryExecutionFeeParams memory params = registrySetProtocolExecutionFeePreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry),
//         abi.encodeWithSelector(NodeRegistry.setProtocolExecutionFee.selector, params.value),
//         currentActor
//     );
//
//     registrySetProtocolExecutionFeePostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_setProtocolMaxSwingFactor(uint256 seed) public {
//     RegistrySwingParams memory params = registrySetProtocolMaxSwingFactorPreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry),
//         abi.encodeWithSelector(NodeRegistry.setProtocolMaxSwingFactor.selector, params.value),
//         currentActor
//     );
//
//     registrySetProtocolMaxSwingFactorPostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_setPoliciesRoot(uint256 seed) public {
//     RegistryPoliciesParams memory params = registrySetPoliciesRootPreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry), abi.encodeWithSelector(NodeRegistry.setPoliciesRoot.selector, params.root), currentActor
//     );
//
//     registrySetPoliciesRootPostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_setRegistryType(uint256 seed) public {
//     RegistrySetTypeParams memory params = registrySetRegistryTypePreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry),
//         abi.encodeWithSelector(
//             INodeRegistry.setRegistryType.selector, params.target, params.typeEnum, params.status
//         ),
//         currentActor
//     );
//
//     registrySetRegistryTypePostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_transferOwnership(uint256 seed) public {
//     RegistryTransferOwnershipParams memory params = registryTransferOwnershipPreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry),
//         abi.encodeWithSelector(bytes4(keccak256("transferOwnership(address)")), params.newOwner),
//         currentActor
//     );
//
//     registryTransferOwnershipPostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_renounceOwnership(uint256 seed) public {
//     RegistryOwnershipCallParams memory params = registryRenounceOwnershipPreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry), abi.encodeWithSelector(bytes4(keccak256("renounceOwnership()"))), currentActor
//     );
//
//     registryRenounceOwnershipPostconditions(success, returnData, params);
// }
// function fuzz_admin_registry_upgradeToAndCall(uint256 seed) public {
//     RegistryUpgradeParams memory params = registryUpgradeToAndCallPreconditions(seed);
//     // Actor selection handled in registry preconditions
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(registry),
//         abi.encodeWithSelector(
//             bytes4(keccak256("upgradeToAndCall(address,bytes)")), params.implementation, params.data
//         ),
//         currentActor
//     );
//
//     registryUpgradeToAndCallPostconditions(success, returnData, params);
// }
}
