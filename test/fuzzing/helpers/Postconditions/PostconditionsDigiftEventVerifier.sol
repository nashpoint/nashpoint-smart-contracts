// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {DigiftEventVerifierMock} from "../../../mocks/DigiftEventVerifierMock.sol";

contract PostconditionsDigiftEventVerifier is PostconditionsBase {
    function digiftVerifierConfigurePostconditions(
        bool success,
        bytes memory returnData,
        DigiftVerifierConfigureParams memory params
    ) internal {
        if (success) {
            (uint256 shares, uint256 assets) =
                DigiftEventVerifierMock(address(digiftEventVerifier)).getExpectedSettlement(params.eventType);
            // fl.eq(shares, params.expectedShares, "DIGIFT_VERIFIER_CONFIGURE_SHARES");
            // fl.eq(assets, params.expectedAssets, "DIGIFT_VERIFIER_CONFIGURE_ASSETS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftVerifierWhitelistPostconditions(
        bool success,
        bytes memory returnData,
        DigiftVerifierWhitelistParams memory params
    ) internal {
        if (success) {
            bool stored = DigiftEventVerifierMock(address(digiftEventVerifier)).whitelist(params.adapter);
            // fl.eq(stored, params.status, "DIGIFT_VERIFIER_WHITELIST_STATUS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftVerifierBlockHashPostconditions(
        bool success,
        bytes memory returnData,
        DigiftVerifierBlockHashParams memory params
    ) internal {
        if (success) {
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftVerifierVerifyPostconditions(
        bool success,
        bytes memory returnData,
        DigiftVerifierVerifyParams memory params
    ) internal {
        if (success) {
            _after();

            (uint256 shares, uint256 assets) = abi.decode(returnData, (uint256, uint256));
            // fl.eq(shares, params.expectedShares, "DIGIFT_VERIFIER_VERIFY_SHARES");
            // fl.eq(assets, params.expectedAssets, "DIGIFT_VERIFIER_VERIFY_ASSETS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
