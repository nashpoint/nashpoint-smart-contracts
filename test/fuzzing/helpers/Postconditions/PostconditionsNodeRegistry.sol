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

            invariant_REGISTRY_01(params);
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

            invariant_REGISTRY_02(params);
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

            invariant_REGISTRY_03(params);
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

            invariant_REGISTRY_04(params);
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
            invariant_REGISTRY_05(params, status);
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
            invariant_REGISTRY_06(params, newOwner);

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
        onFailInvariantsGeneral(returnData);
    }

    function registryInitializePostconditions(
        bool success,
        bytes memory returnData,
        RegistryInitializeParams memory params
    ) internal {
        params; // silence warning
        onFailInvariantsGeneral(returnData);
    }

    function registryUpgradeToAndCallPostconditions(
        bool success,
        bytes memory returnData,
        RegistryUpgradeParams memory params
    ) internal {
        params; // silence warning
        onFailInvariantsGeneral(returnData);
    }
}
