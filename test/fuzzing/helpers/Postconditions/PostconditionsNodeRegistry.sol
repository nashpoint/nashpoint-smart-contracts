// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {NodeRegistry} from "../../../../src/NodeRegistry.sol";
import {INodeRegistry, RegistryType} from "../../../../src/interfaces/INodeRegistry.sol";

contract PostconditionsNodeRegistry is PostconditionsBase {
    function registrySetProtocolFeeAddressPostconditions(
        bool success,
        bytes memory returnData,
        RegistryAddressParams memory params
    ) internal {
        if (success) {
            _after();

            // fl.t(registry.protocolFeeAddress() == params.target, "REGISTRY_FEE_ADDRESS_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registrySetProtocolManagementFeePostconditions(
        bool success,
        bytes memory returnData,
        RegistryFeeParams memory params
    ) internal {
        if (success) {
            _after();

            // fl.t(registry.protocolManagementFee() == params.value, "REGISTRY_MANAGEMENT_FEE_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registrySetProtocolExecutionFeePostconditions(
        bool success,
        bytes memory returnData,
        RegistryExecutionFeeParams memory params
    ) internal {
        if (success) {
            _after();

            // fl.t(registry.protocolExecutionFee() == params.value, "REGISTRY_EXECUTION_FEE_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registrySetProtocolMaxSwingFactorPostconditions(
        bool success,
        bytes memory returnData,
        RegistrySwingParams memory params
    ) internal {
        if (success) {
            _after();

            // fl.t(registry.protocolMaxSwingFactor() == params.value, "REGISTRY_SWING_FACTOR_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registrySetPoliciesRootPostconditions(
        bool success,
        bytes memory returnData,
        RegistryPoliciesParams memory params
    ) internal {
        if (success) {
            _after();

            // fl.t(registry.policiesRoot() == params.root, "REGISTRY_POLICIES_ROOT_VALUE");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registrySetRegistryTypePostconditions(
        bool success,
        bytes memory returnData,
        RegistrySetTypeParams memory params
    ) internal {
        if (success) {
            _after();

            bool status = registry.isRegistryType(params.target, params.typeEnum);
            // fl.t(status == params.status, "REGISTRY_TYPE_STATUS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registryAddNodePostconditions(bool success, bytes memory returnData, RegistryAddNodeParams memory params)
        internal
    {
        if (success) {
            _after();

            // fl.t(registry.isNode(params.node), "REGISTRY_ADD_NODE_STATUS");
            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registryTransferOwnershipPostconditions(
        bool success,
        bytes memory returnData,
        RegistryTransferOwnershipParams memory params
    ) internal {
        if (success) {
            _after();

            address newOwner = registry.owner();
            // fl.t(newOwner == params.newOwner, "REGISTRY_TRANSFER_OWNER_VALUE");

            // Restore original owner to keep environment consistent
            vm.startPrank(newOwner);
            registry.transferOwnership(owner);
            vm.stopPrank();

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function registryRenounceOwnershipPostconditions(
        bool success,
        bytes memory returnData,
        RegistryOwnershipCallParams memory params
    ) internal {
        params; // silence warning
        // fl.t(!success, "REGISTRY_RENOUNCE_EXPECTED_REVERT");
        onFailInvariantsGeneral(returnData);
    }

    function registryInitializePostconditions(
        bool success,
        bytes memory returnData,
        RegistryInitializeParams memory params
    ) internal {
        params; // silence warning
        // fl.t(!success, "REGISTRY_INITIALIZE_EXPECTED_REVERT");
        onFailInvariantsGeneral(returnData);
    }

    function registryUpgradeToAndCallPostconditions(
        bool success,
        bytes memory returnData,
        RegistryUpgradeParams memory params
    ) internal {
        params; // silence warning
        // fl.t(!success, "REGISTRY_UPGRADE_EXPECTED_REVERT");
        onFailInvariantsGeneral(returnData);
    }
}
