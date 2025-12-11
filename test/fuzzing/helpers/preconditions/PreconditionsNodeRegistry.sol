// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {RegistryType} from "../../../../src/interfaces/INodeRegistry.sol";

contract PreconditionsNodeRegistry is PreconditionsBase {
    function registrySetProtocolFeeAddressPreconditions(uint256 seed)
        internal
        returns (RegistryAddressParams memory params)
    {
        bool attemptSuccess = seed % 4 != 0;
        if (attemptSuccess) {
            params.target = address(uint160(uint256(keccak256(abi.encodePacked(seed, "REG_FEE_ADDR")))));
            if (params.target == address(0)) {
                params.target = address(0x1);
            }
            params.shouldSucceed = params.target != registry.protocolFeeAddress();
        } else {
            params.target = seed % 2 == 0 ? address(0) : registry.protocolFeeAddress();
            params.shouldSucceed = false;
        }
    }

    function registrySetProtocolManagementFeePreconditions(uint256 seed)
        internal
        pure
        returns (RegistryFeeParams memory params)
    {
        bool attemptSuccess = seed % 3 != 0;
        if (attemptSuccess) {
            params.value = uint64(seed % 1e18);
            params.shouldSucceed = params.value < 1e18;
        } else {
            params.value = uint64(1e18);
            params.shouldSucceed = false;
        }
    }

    function registrySetProtocolExecutionFeePreconditions(uint256 seed)
        internal
        pure
        returns (RegistryExecutionFeeParams memory params)
    {
        bool attemptSuccess = seed % 3 != 0;
        if (attemptSuccess) {
            params.value = uint64(seed % 1e18);
            params.shouldSucceed = params.value < 1e18;
        } else {
            params.value = uint64(1e18);
            params.shouldSucceed = false;
        }
    }

    function registrySetProtocolMaxSwingFactorPreconditions(uint256 seed)
        internal
        pure
        returns (RegistrySwingParams memory params)
    {
        bool attemptSuccess = seed % 3 != 0;
        if (attemptSuccess) {
            params.value = uint64(seed % 1e18);
            params.shouldSucceed = params.value < 1e18;
        } else {
            params.value = uint64(1e18);
            params.shouldSucceed = false;
        }
    }

    function registrySetPoliciesRootPreconditions(uint256 seed)
        internal
        pure
        returns (RegistryPoliciesParams memory params)
    {
        params.root = keccak256(abi.encodePacked(seed, "POL_ROOT"));
        params.shouldSucceed = seed % 2 == 0;
    }

    function registrySetRegistryTypePreconditions(uint256 seed)
        internal
        returns (RegistrySetTypeParams memory params)
    {
        params.typeEnum = RegistryType((seed % 5) + 1);
        params.status = true;
        bool attemptSuccess = seed % 4 != 0;

        if (attemptSuccess) {
            params.target = address(uint160(uint256(keccak256(abi.encodePacked(seed, params.typeEnum)))));
            params.status = true;
            params.shouldSucceed = true;
        } else {
            params.target = address(0);
            params.status = false;
            params.shouldSucceed = false;
        }
    }

    function registryTransferOwnershipPreconditions(uint256 seed)
        internal
        returns (RegistryTransferOwnershipParams memory params)
    {
        bool attemptSuccess = seed % 3 != 0;
        if (attemptSuccess) {
            params.newOwner = address(uint160(uint256(keccak256(abi.encodePacked(seed, "REG_NEW_OWNER")))));
            if (params.newOwner == address(0)) {
                params.newOwner = address(0x1);
            }
            params.shouldSucceed = params.newOwner != owner;
        } else {
            params.newOwner = address(0);
            params.shouldSucceed = false;
        }
    }

    function registryAddNodePreconditions(uint256 seed) internal returns (RegistryAddNodeParams memory params) {
        bool attemptSuccess = seed % 4 != 0;
        params.caller = attemptSuccess ? address(factory) : randomUser;
        params.node = address(uint160(uint256(keccak256(abi.encodePacked(seed, "NODE_REG")))));
        params.shouldSucceed = params.caller == address(factory);
    }

    function registryInitializePreconditions(uint256 seed) internal returns (RegistryInitializeParams memory params) {
        params.owner = USERS[seed % USERS.length];
        params.feeAddress = USERS[(seed + 1) % USERS.length];
        params.managementFee = uint64(seed % 1e18);
        params.executionFee = uint64((seed + 1) % 1e18);
        params.maxSwingFactor = uint64((seed + 2) % 1e18);
        params.shouldSucceed = false;
    }

    function registryRenounceOwnershipPreconditions(uint256 seed)
        internal
        view
        returns (RegistryOwnershipCallParams memory params)
    {
        params.caller = seed % 2 == 0 ? randomUser : USERS[seed % USERS.length];
        params.shouldSucceed = false;
    }

    function registryUpgradeToAndCallPreconditions(uint256 seed)
        internal
        returns (RegistryUpgradeParams memory params)
    {
        params.implementation = address(uint160(uint256(keccak256(abi.encodePacked(seed, "REG_UPGRADE_IMPL")))));
        params.data = abi.encode(seed);
        params.shouldSucceed = false;
    }
}
