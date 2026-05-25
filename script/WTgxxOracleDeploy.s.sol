// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {Script} from "forge-std/Script.sol";

import {Environment} from "./Utils.sol";

import {WTPriceOracle} from "src/adapters/wt/WTPriceOracle.sol";

// source .env && FOUNDRY_PROFILE=arbitrum forge script script/WTgxxOracleDeploy.s.sol:WTgxxOracleDeploy --broadcast -vvv --verify

contract WTgxxOracleDeploy is Script {
    using stdJson for string;

    // TODO: confirm initial price before broadcasting (uint64, scaled by `decimals` below).
    // Example: 100000000 == $1.00000000 at 8 decimals.
    uint64 internal constant INITIAL_PRICE = 100000000;
    uint8 internal constant DECIMALS = 8;
    string internal constant DESCRIPTION = "WTGXX / USD";
    uint64 internal constant COOLDOWN = 1 days;
    uint64 internal constant PRICE_DEVIATION = 1e16; // 1%

    function run() external {
        string memory path = Environment.getContractsPath(vm);
        string memory existingJson = vm.readFile(path);
        Environment.Config memory config = Environment.getConfig(vm);

        Environment.setRpc(vm);

        uint256 privateKey = Environment.getPrivateKey(vm);

        vm.startBroadcast(privateKey);

        WTPriceOracle wtgxxPriceOracle =
            new WTPriceOracle(config.protocolOwner, INITIAL_PRICE, DECIMALS, DESCRIPTION, COOLDOWN, PRICE_DEVIATION);

        vm.stopBroadcast();

        // Re-serialize the existing `wt` object to avoid clobbering previously-deployed entries.
        string memory wtKey = "wt";
        string memory wt =
            stdJson.serialize(wtKey, "eventVerifier", existingJson.readAddressOr(".wt.eventVerifier", address(0)));
        wt = stdJson.serialize(
            wtKey, "adapterImplementation", existingJson.readAddressOr(".wt.adapterImplementation", address(0))
        );
        wt = stdJson.serialize(wtKey, "adapterFactory", existingJson.readAddressOr(".wt.adapterFactory", address(0)));
        wt = stdJson.serialize(wtKey, "wCRDYX", existingJson.readAddressOr(".wt.wCRDYX", address(0)));
        wt =
            stdJson.serialize(wtKey, "crdyxPriceOracle", existingJson.readAddressOr(".wt.crdyxPriceOracle", address(0)));
        wt = stdJson.serialize(wtKey, "wtgxxPriceOracle", address(wtgxxPriceOracle));

        string memory jsonKey = "json";
        string memory json = stdJson.serialize(jsonKey, existingJson);
        json = stdJson.serialize(jsonKey, wtKey, wt);
        stdJson.write(json, path);
    }
}
