// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../properties/Properties.sol";

contract PostconditionsBase is Properties {
    function onSuccessInvariantsGeneral(bytes memory returnData) internal {
        // invariant_GLOB_01();
    }

    function onFailInvariantsGeneral(bytes memory returnData) internal {
        // fl.t(false, "Handler failed a call");
        // Failure path currently does not enforce global invariants.
        // invariant_ERR(returnData);
    }
}
