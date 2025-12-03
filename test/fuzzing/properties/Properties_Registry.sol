// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";

contract Properties_Registry is Properties_ERR {
    // ==============================================================
    // NODE REGISTRY INVARIANTS
    // ==============================================================

    function invariant_REGISTRY_01(RegistryAddressParams memory params) internal {
        // fl.t(registry.protocolFeeAddress() == params.target, REGISTRY_01);
    }

    function invariant_REGISTRY_02(RegistryFeeParams memory params) internal {
        // fl.t(registry.protocolManagementFee() == params.value, REGISTRY_02);
    }

    function invariant_REGISTRY_03(RegistryExecutionFeeParams memory params) internal {
        // fl.t(registry.protocolExecutionFee() == params.value, REGISTRY_03);
    }

    function invariant_REGISTRY_04(RegistrySwingParams memory params) internal {
        // fl.t(registry.protocolMaxSwingFactor() == params.value, REGISTRY_04);
    }

    function invariant_REGISTRY_05(RegistryPoliciesParams memory params) internal {
        // fl.t(registry.policiesRoot() == params.root, REGISTRY_05);
    }

    function invariant_REGISTRY_06(RegistrySetTypeParams memory params, bool status) internal {
        // fl.t(status == params.status, REGISTRY_06);
    }

    function invariant_REGISTRY_07(RegistryAddNodeParams memory params) internal {
        // fl.t(registry.isNode(params.node), REGISTRY_07);
    }

    function invariant_REGISTRY_08(RegistryTransferOwnershipParams memory params, address newOwner) internal {
        // fl.t(newOwner == params.newOwner, REGISTRY_08);
    }

    function invariant_REGISTRY_10() internal {
        // Registry initialize should always revert (already initialized)
        // fl.t(!success, REGISTRY_10);
    }

    function invariant_REGISTRY_11() internal {
        // Registry upgrade should revert for unauthorized callers
        // fl.t(!success, REGISTRY_11);
    }
}
