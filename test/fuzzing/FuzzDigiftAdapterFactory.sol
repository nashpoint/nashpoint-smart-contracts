// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsDigiftAdapterFactory.sol";
import "./helpers/postconditions/PostconditionsDigiftAdapterFactory.sol";

import {DigiftAdapterFactory} from "../../src/adapters/digift/DigiftAdapterFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract FuzzDigiftAdapterFactory is PreconditionsDigiftAdapterFactory, PostconditionsDigiftAdapterFactory {
    function fuzz_digiftFactory_deploy(uint256 seed) public setCurrentActor(seed) {
        DigiftFactoryDeployParams memory params = digiftFactoryDeployPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftFactory),
            abi.encodeWithSelector(DigiftAdapterFactory.deploy.selector, params.initArgs),
            currentActor
        );

        digiftFactoryDeployPostconditions(success, returnData, params);
    }

    function fuzz_digiftFactory_transferOwnership(uint256 seed) public setCurrentActor(seed) {
        DigiftFactoryOwnershipParams memory params = digiftFactoryTransferOwnershipPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftFactory),
            abi.encodeWithSelector(Ownable.transferOwnership.selector, params.newOwner),
            currentActor
        );

        digiftFactoryOwnershipPostconditions(success, returnData, params);
    }

    function fuzz_digiftFactory_renounceOwnership(uint256 seed) public setCurrentActor(seed) {
        DigiftFactoryOwnershipParams memory params = digiftFactoryRenouncePreconditions();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftFactory), abi.encodeWithSelector(Ownable.renounceOwnership.selector), currentActor
        );

        digiftFactoryOwnershipPostconditions(success, returnData, params);
    }

    function fuzz_digiftFactory_upgrade(uint256 seed) public setCurrentActor(seed) {
        DigiftFactoryUpgradeParams memory params = digiftFactoryUpgradePreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftFactory),
            abi.encodeWithSelector(UpgradeableBeacon.upgradeTo.selector, params.newImplementation),
            currentActor
        );

        digiftFactoryUpgradePostconditions(success, returnData, params);
    }
}
