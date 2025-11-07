// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsDigiftEventVerifier.sol";
import "./helpers/postconditions/PostconditionsDigiftEventVerifier.sol";

import {DigiftEventVerifier} from "../../src/adapters/digift/DigiftEventVerifier.sol";

/**
 * @title FuzzDigiftEventVerifier
 * @notice Fuzzing handlers for DigiftEventVerifier public functions (Category 1)
 * @dev This contract tests the public verification function callable by anyone:
 *      - verifySettlementEvent
 */
contract FuzzDigiftEventVerifier is PreconditionsDigiftEventVerifier, PostconditionsDigiftEventVerifier {
    // ========================================
    // CATEGORY 1: USER FUNCTIONS (Public)
    // ========================================

    function fuzz_digiftVerifier_verifySettlement(uint256 seed, bool isSubscribe) public {
        DigiftVerifierVerifyParams memory params = digiftVerifierVerifyPreconditions(seed, isSubscribe);

        DigiftEventVerifier.OffchainArgs memory offchain = DigiftEventVerifier.OffchainArgs({
            blockNumber: block.number,
            headerRlp: bytes(""),
            txIndex: bytes(""),
            proof: new bytes[](0)
        });

        DigiftEventVerifier.OnchainArgs memory onchain = DigiftEventVerifier.OnchainArgs({
            eventType: params.eventType,
            emittingAddress: address(subRedManagement),
            securityToken: params.securityToken,
            currencyToken: params.currencyToken
        });

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftEventVerifier),
            abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, offchain, onchain),
            params.adapter
        );

        digiftVerifierVerifyPostconditions(success, returnData, params);
    }
}
