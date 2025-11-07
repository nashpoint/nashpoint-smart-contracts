// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/preconditions/PreconditionsDigiftEventVerifier.sol";
import "../helpers/postconditions/PostconditionsDigiftEventVerifier.sol";

import {DigiftEventVerifier} from "../../../src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftEventVerifierMock} from "../../mocks/DigiftEventVerifierMock.sol";

/**
 * @title FuzzAdminDigiftEventVerifier
 * @notice Fuzzing handlers for DigiftEventVerifier administrative functions (Category 2)
 * @dev These handlers test functions restricted to onlyRegistryOwner:
 *      - setBlockHash
 *      - setWhitelist
 *      - configureSettlement (internal helper, not an actual entry point)
 *
 * All handlers are currently commented out and can be enabled for targeted admin testing.
 */
contract FuzzAdminDigiftEventVerifier is PreconditionsDigiftEventVerifier, PostconditionsDigiftEventVerifier {
// ========================================
// CATEGORY 2: ADMIN FUNCTIONS (onlyRegistryOwner)
// ========================================
// function fuzz_admin_digiftVerifier_setWhitelist(uint256 seed, bool status) public {
//     // Actor selection handled in preconditions
//     DigiftVerifierWhitelistParams memory params = digiftVerifierSetWhitelistPreconditions(seed, status);
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftEventVerifier),
//         abi.encodeWithSelector(DigiftEventVerifier.setWhitelist.selector, params.adapter, params.status),
//         currentActor
//     );
//
//     digiftVerifierWhitelistPostconditions(success, returnData, params);
// }
// function fuzz_admin_digiftVerifier_setBlockHash(uint256 seed) public {
//     // Actor selection handled in preconditions
//     DigiftVerifierBlockHashParams memory params = digiftVerifierSetBlockHashPreconditions(seed);
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftEventVerifier),
//         abi.encodeWithSelector(DigiftEventVerifier.setBlockHash.selector, params.blockNumber, params.blockHash),
//         currentActor
//     );
//
//     digiftVerifierBlockHashPostconditions(success, returnData, params);
// }
// ========================================
// CATEGORY 3: INTERNAL/HELPER FUNCTIONS
// ========================================
// function fuzz_admin_digiftVerifier_configureSettlement(uint256 seed, bool isSubscribe) public {
//     // Actor selection handled in preconditions
//     DigiftVerifierConfigureParams memory params = digiftVerifierConfigurePreconditions(seed, isSubscribe);
//
//     (bool success, bytes memory returnData) = fl.doFunctionCall(
//         address(digiftEventVerifier),
//         abi.encodeWithSelector(
//             DigiftEventVerifierMock.configureSettlement.selector,
//             params.eventType,
//             params.expectedShares,
//             params.expectedAssets
//         ),
//         owner
//     );
//
//     digiftVerifierConfigurePostconditions(success, returnData, params);
// }
}
