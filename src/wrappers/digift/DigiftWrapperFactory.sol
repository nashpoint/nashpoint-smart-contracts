// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DigiftWrapper} from "./DigiftWrapper.sol";

contract DigiftWrapperFactory is UpgradeableBeacon {
    event Deployed(address digiftWrapper);

    constructor(address implementation, address owner) UpgradeableBeacon(implementation, owner) {}

    function deploy(DigiftWrapper.InitArgs calldata initArgs) external onlyOwner {
        address digiftWrapper =
            address(new BeaconProxy(address(this), abi.encodeWithSelector(DigiftWrapper.initialize.selector, initArgs)));

        emit Deployed(digiftWrapper);
    }
}
