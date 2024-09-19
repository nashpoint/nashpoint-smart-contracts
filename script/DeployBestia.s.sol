// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Bestia} from "../src/Bestia.sol";

contract DeployBestia is Script {
    function run() external returns (Bestia, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            , // ignore manager
            address banker,
            address usdc,
            // address escrow,
            address vaultA,
            address vaultB,
            address vaultC,
            address liquidityPool
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        Bestia bestia = new Bestia(
            address(usdc),
            "Bestia",
            "BEST",
            address(vaultA),
            address(vaultB),
            address(vaultC),
            address(liquidityPool),
            address(banker)
        );
        vm.stopBroadcast();
        return (bestia, helperConfig);
    }
}
