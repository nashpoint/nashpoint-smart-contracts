// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

contract PostconditionsDonate is PostconditionsBase {
    function donatePostconditions(bool success, bytes memory returnData) internal {
        if (success) {
            _after();
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
