// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {Script, console} from "forge-std/Script.sol";

import {Environment} from "./Utils.sol";

import {DigiftAdapter} from "src/adapters/digift/DigiftAdapter.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {DigiftAdapterFactory} from "src/adapters/digift/DigiftAdapterFactory.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";

// source .env && FOUNDRY_PROFILE=arbitrum forge script script/DigiftArbitrum.s.sol:DigiftArbitrum --broadcast -vvv --verify

contract DigiftArbitrum is Script {
    using stdJson for string;

    function run() external {
        Environment.Config memory config = Environment.getConfig(vm);
        Environment.Contracts memory contracts = Environment.getContracts(vm);

        Environment.setRpc(vm);

        uint256 privateKey = Environment.getPrivateKey(vm);

        vm.startBroadcast(privateKey);
        DigiftAdapter digiftAdapter = DigiftAdapterFactory(contracts.digiftAdapterFactory).deploy(
            AdapterBase.InitArgs({
                name: "iSNR Wrapper",
                symbol: "wiSNR",
                asset: config.usdc,
                assetPriceOracle: config.usdcPriceOracle,
                fund: config.digift.iSNR,
                fundPriceOracle: config.digift.iSNRPriceOracle,
                priceDeviation: 1e15, // 0.1%
                settlementDeviation: 1e16, // 1%
                priceUpdateDeviationFund: 1 days,
                priceUpdateDeviationAsset: 1 days,
                // TODO: double check
                minDepositAmount: 10000e6,
                // TODO: double check
                minRedeemAmount: 1e18,
                customInitData: ""
            })
        );

        digiftAdapter.setManager(config.protocolOwner, true);

        DigiftEventVerifier(contracts.digiftEventVerifier).setWhitelist(address(digiftAdapter), true);

        vm.stopBroadcast();

        console.log("iSNR digiftAdapter", address(digiftAdapter));
    }
}
