// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {DigiftWrapper} from "./DigiftWrapper.sol";

/**
 * @title DigiftWrapperFactory
 * @notice Factory contract for deploying DigiftWrapper instances using beacon proxy pattern
 * @dev Extends UpgradeableBeacon to enable upgradeable DigiftWrapper deployments
 * @dev All deployed wrappers share the same implementation but have independent storage
 */
contract DigiftWrapperFactory is UpgradeableBeacon {
    // =============================
    //            Events
    // =============================

    /**
     * @notice Emitted when a new DigiftWrapper is deployed
     * @param digiftWrapper The address of the newly deployed DigiftWrapper
     */
    event Deployed(address digiftWrapper);

    // =============================
    //         Constructor
    // =============================

    /**
     * @notice Constructor for DigiftWrapperFactory
     * @dev Initializes the upgradeable beacon with the DigiftWrapper implementation
     * @param implementation The address of the DigiftWrapper implementation contract
     * @param owner The address that will own the beacon and can upgrade implementations
     */
    constructor(address implementation, address owner) UpgradeableBeacon(implementation, owner) {}

    // =============================
    //      Deployment Functions
    // =============================

    /**
     * @notice Deploy a new DigiftWrapper instance
     * @dev Creates a new BeaconProxy pointing to this factory and initializes it
     * @dev Only callable by the factory owner
     * @param initArgs The initialization arguments for the new DigiftWrapper
     * @return digiftWrapper The newly deployed and initialized DigiftWrapper instance
     */
    function deploy(DigiftWrapper.InitArgs calldata initArgs)
        external
        onlyOwner
        returns (DigiftWrapper digiftWrapper)
    {
        // Deploy a new BeaconProxy that points to this factory
        // The proxy will use the implementation set in this beacon
        address digiftWrapperAddress =
            address(new BeaconProxy(address(this), abi.encodeWithSelector(DigiftWrapper.initialize.selector, initArgs)));

        emit Deployed(digiftWrapperAddress);

        return DigiftWrapper(digiftWrapperAddress);
    }
}
