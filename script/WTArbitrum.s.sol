// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";

import {Script, console} from "forge-std/Script.sol";

import {Environment} from "./Utils.sol";

import {WTAdapter} from "src/adapters/wt/WTAdapter.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {WTAdapterFactory} from "src/adapters/wt/WTAdapterFactory.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";

import {PriceOracleMock} from "test/mocks/PriceOracleMock.sol";

// source .env && FOUNDRY_PROFILE=arbitrum forge script script/WTArbitrum.s.sol:WTArbitrum --broadcast -vvv --verify

contract WTArbitrum is Script {
    using stdJson for string;

    function run() external {
        Environment.Config memory config = Environment.getConfig(vm);
        Environment.Contracts memory contracts = Environment.getContracts(vm);

        Environment.setRpc(vm);

        uint256 privateKey = Environment.getPrivateKey(vm);

        vm.startBroadcast(privateKey);
        PriceOracleMock crdyxPriceOracle = new PriceOracleMock(8);
        crdyxPriceOracle.setLatestRoundData(0, 847000000, block.timestamp, block.timestamp, 0);

        WTAdapter wtAdapter = WTAdapterFactory(contracts.wtAdapterFactory).deploy(
            AdapterBase.InitArgs({
                name: "CRDX Wrapper",
                symbol: "wCRDX",
                asset: config.usdc,
                assetPriceOracle: config.usdcPriceOracle,
                fund: config.wt.CRDYX,
                fundPriceOracle: address(crdyxPriceOracle),
                priceDeviation: 3e16, // 3%
                settlementDeviation: 3e16, // 3%
                priceUpdateDeviationFund: 1 days,
                priceUpdateDeviationAsset: 1 days,
                // TODO: double check
                minDepositAmount: 10e6,
                // TODO: double check
                minRedeemAmount: 1e18,
                customInitData: abi.encode(config.wt.receiverAddress, config.wt.senderAddress)
            })
        );

        wtAdapter.setManager(config.protocolOwner, true);

        TransferEventVerifier(contracts.transferEventVerifier).setWhitelist(address(wtAdapter), true);

        vm.stopBroadcast();

        console.log("CRDYX wtAdapter", address(wtAdapter));
    }
}
