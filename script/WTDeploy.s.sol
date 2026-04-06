// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {Script} from "forge-std/Script.sol";

import {Environment} from "./Utils.sol";

import {WTAdapterFactory} from "src/adapters/wt/WTAdapterFactory.sol";
import {WTAdapter} from "src/adapters/wt/WTAdapter.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {WTPriceOracle} from "src/adapters/wt/WTPriceOracle.sol";

// source .env && FOUNDRY_PROFILE=arbitrum forge script script/WTDeploy.s.sol:WTDeploy --broadcast -vvv --verify

contract WTDeploy is Script {
    using stdJson for string;

    function run() external {
        string memory path = Environment.getContractsPath(vm);
        string memory existingJson = vm.readFile(path);
        Environment.Config memory config = Environment.getConfig(vm);
        address nodeRegistryProxy = existingJson.readAddress(".nodeRegistryProxy");

        Environment.setRpc(vm);

        uint256 privateKey = Environment.getPrivateKey(vm);

        vm.startBroadcast(privateKey);

        TransferEventVerifier transferEventVerifier = new TransferEventVerifier(nodeRegistryProxy);

        WTAdapter wtAdapterImplementation = new WTAdapter(nodeRegistryProxy, address(transferEventVerifier));

        WTAdapterFactory wtAdapterFactory = new WTAdapterFactory(address(wtAdapterImplementation), config.protocolOwner);

        WTPriceOracle crdyxPriceOracle =
            new WTPriceOracle(config.protocolOwner, 805300000, 8, "CRDYX / USD", 1 days, 5e16);

        vm.stopBroadcast();

        string memory wtKey = "wt";
        string memory wt = stdJson.serialize(wtKey, "eventVerifier", address(transferEventVerifier));
        wt = stdJson.serialize(wtKey, "adapterImplementation", address(wtAdapterImplementation));
        wt = stdJson.serialize(wtKey, "adapterFactory", address(wtAdapterFactory));
        wt = stdJson.serialize(wtKey, "crdyxPriceOracle", address(crdyxPriceOracle));

        string memory jsonKey = "json";
        string memory json = stdJson.serialize(jsonKey, existingJson);
        json = stdJson.serialize(jsonKey, wtKey, wt);
        stdJson.write(json, path);
    }
}
