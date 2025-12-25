// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {Script, console} from "forge-std/Script.sol";

import {Environment} from "./Utils.sol";

import {DigiftAdapter} from "src/adapters/digift/DigiftAdapter.sol";
import {DigiftAdapterFactory} from "src/adapters/digift/DigiftAdapterFactory.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";

import {PriceOracleMock} from "test/mocks/PriceOracleMock.sol";

// source .env && FOUNDRY_PROFILE=sepolia forge script script/DigiftSepolia.s.sol:DigiftSepolia --broadcast -vvv --verify

contract DigiftSepolia is Script {
    using stdJson for string;

    function run() external {
        Environment.Config memory config = Environment.getConfig(vm);
        Environment.Contracts memory contracts = Environment.getContracts(vm);

        Environment.setRpc(vm);

        uint256 privateKey = Environment.getPrivateKey(vm);

        vm.startBroadcast(privateKey);
        PriceOracleMock usdcPriceOracle = new PriceOracleMock(8);
        usdcPriceOracle.setLatestRoundData(
            18446744073709556890, 99974000, block.timestamp, block.timestamp, 18446744073709556890
        );

        DigiftAdapter digiftAdapter = DigiftAdapterFactory(contracts.digiftAdapterFactory).deploy(
            DigiftAdapter.InitArgs(
                "iSNR Wrapper",
                "wiSNR",
                config.usdc,
                address(usdcPriceOracle),
                config.iSNR,
                config.iSNRPriceOracle,
                // 0.1%
                1e15,
                // 1%
                1e16,
                2 days,
                1 days,
                1000e6,
                1e18
            )
        );

        digiftAdapter.setManager(config.protocolOwner, true);

        DigiftEventVerifier(contracts.digiftEventVerifier).setWhitelist(address(digiftAdapter), true);

        vm.stopBroadcast();

        console.log("iSNR digiftAdapter", address(digiftAdapter));
        console.log("usdcPriceOracle", address(usdcPriceOracle));
    }
}
