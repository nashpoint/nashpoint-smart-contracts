// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../properties/Properties.sol";

contract PostconditionsBase is Properties {
    function onSuccessInvariantsGeneral(bytes memory returnData) internal {
        checkLogicalCoverage(true);
    }

    function onFailInvariantsGeneral(bytes memory returnData) internal {
        // invariant_ERR(returnData);
    }
}
