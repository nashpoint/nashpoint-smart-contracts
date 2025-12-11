// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

contract PostconditionsDigiftEventVerifier is PostconditionsBase {
    function digiftVerifierConfigurePostconditions(
        bool success,
        bytes memory returnData,
        DigiftVerifierConfigureParams memory params
    ) internal {
        if (success) {
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
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
