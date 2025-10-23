// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {DigiftAdapter} from "./DigiftAdapter.sol";

/**
 * @title DigiftAdapterFactory
 * @notice Factory contract for deploying DigiftAdapter instances using beacon proxy pattern
 * @dev Extends UpgradeableBeacon to enable upgradeable DigiftAdapter deployments
 * @dev All deployed adapters share the same implementation but have independent storage
 */
contract DigiftAdapterFactory is UpgradeableBeacon {
    // =============================
    //            Events
    // =============================

    /**
     * @notice Emitted when a new DigiftAdapter is deployed
     * @param digiftAdapter The address of the newly deployed DigiftAdapter
     */
    event Deployed(address digiftAdapter);

    // =============================
    //         Constructor
    // =============================

    /**
     * @notice Constructor for DigiftAdapterFactory
     * @dev Initializes the upgradeable beacon with the DigiftAdapter implementation
     * @param implementation The address of the DigiftAdapter implementation contract
     * @param owner The address that will own the beacon and can upgrade implementations
     */
    constructor(address implementation, address owner) UpgradeableBeacon(implementation, owner) {}

    // =============================
    //      Deployment Functions
    // =============================

    /**
     * @notice Deploy a new DigiftAdapter instance
     * @dev Creates a new BeaconProxy pointing to this factory and initializes it
     * @dev Only callable by the factory owner
     * @param initArgs The initialization arguments for the new DigiftAdapter
     * @return digiftAdapter The newly deployed and initialized DigiftAdapter instance
     */
    function deploy(DigiftAdapter.InitArgs calldata initArgs)
        external
        onlyOwner
        returns (DigiftAdapter digiftAdapter)
    {
        // Deploy a new BeaconProxy that points to this factory
        // The proxy will use the implementation set in this beacon
        address digiftAdapterAddress =
            address(new BeaconProxy(address(this), abi.encodeWithSelector(DigiftAdapter.initialize.selector, initArgs)));

        emit Deployed(digiftAdapterAddress);

        return DigiftAdapter(digiftAdapterAddress);
    }
}
