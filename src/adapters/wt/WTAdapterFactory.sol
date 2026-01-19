// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {WTAdapter} from "src/adapters/wt/WTAdapter.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";

/**
 * @title WTAdapterFactory
 * @notice Factory contract for deploying WTAdapter instances using beacon proxy pattern
 * @dev Extends UpgradeableBeacon to enable upgradeable WTAdapter deployments
 * @dev All deployed adapters share the same implementation but have independent storage
 */
contract WTAdapterFactory is UpgradeableBeacon {
    // =============================
    //            Events
    // =============================

    /**
     * @notice Emitted when a new WTAdapter is deployed
     * @param wtAdapter The address of the newly deployed WTAdapter
     */
    event Deployed(address wtAdapter);

    // =============================
    //         Constructor
    // =============================

    /**
     * @notice Constructor for WTAdapterFactory
     * @dev Initializes the upgradeable beacon with the WTAdapter implementation
     * @param implementation The address of the WTAdapter implementation contract
     * @param owner The address that will own the beacon and can upgrade implementations
     */
    constructor(address implementation, address owner) UpgradeableBeacon(implementation, owner) {}

    // =============================
    //      Deployment Functions
    // =============================

    /**
     * @notice Deploy a new WTAdapter instance
     * @dev Creates a new BeaconProxy pointing to this factory and initializes it
     * @dev Only callable by the factory owner
     * @param initArgs The initialization arguments for the new WTAdapter
     * @return wtAdapter The newly deployed and initialized WTAdapter instance
     */
    function deploy(AdapterBase.InitArgs calldata initArgs) external onlyOwner returns (WTAdapter wtAdapter) {
        // Deploy a new BeaconProxy that points to this factory
        // The proxy will use the implementation set in this beacon
        address wtAdapterAddress =
            address(new BeaconProxy(address(this), abi.encodeWithSelector(AdapterBase.initialize.selector, initArgs)));

        emit Deployed(wtAdapterAddress);

        return WTAdapter(wtAdapterAddress);
    }
}
