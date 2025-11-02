// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsDigiftEventVerifier.sol";
import "./helpers/postconditions/PostconditionsDigiftEventVerifier.sol";

import {DigiftEventVerifier} from "../../src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftEventVerifierMock} from "../mocks/DigiftEventVerifierMock.sol";

contract FuzzDigiftEventVerifier is PreconditionsDigiftEventVerifier, PostconditionsDigiftEventVerifier {
    function fuzz_digiftVerifier_configureSettlement(uint256 seed, bool isSubscribe) public {
        _forceActor(owner, seed);
        DigiftVerifierConfigureParams memory params = digiftVerifierConfigurePreconditions(seed, isSubscribe);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftEventVerifier),
            abi.encodeWithSelector(
                DigiftEventVerifierMock.configureSettlement.selector,
                params.eventType,
                params.expectedShares,
                params.expectedAssets
            ),
            owner
        );

        digiftVerifierConfigurePostconditions(success, returnData, params);
    }

    function fuzz_digiftVerifier_setWhitelist(uint256 seed, bool status) public {
        _forceActor(owner, seed);
        DigiftVerifierWhitelistParams memory params = digiftVerifierSetWhitelistPreconditions(seed, status);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftEventVerifier),
            abi.encodeWithSelector(DigiftEventVerifier.setWhitelist.selector, params.adapter, params.status),
            currentActor
        );

        digiftVerifierWhitelistPostconditions(success, returnData, params);
    }

    function fuzz_digiftVerifier_setBlockHash(uint256 seed) public {
        _forceActor(owner, seed);
        DigiftVerifierBlockHashParams memory params = digiftVerifierSetBlockHashPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftEventVerifier),
            abi.encodeWithSelector(DigiftEventVerifier.setBlockHash.selector, params.blockNumber, params.blockHash),
            currentActor
        );

        digiftVerifierBlockHashPostconditions(success, returnData, params);
    }

    function fuzz_digiftVerifier_verifySettlement(uint256 seed, bool isSubscribe) public {
        DigiftVerifierVerifyParams memory params = digiftVerifierVerifyPreconditions(seed, isSubscribe);
        _forceActor(params.adapter, seed);

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
