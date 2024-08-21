// SPDX-License_identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Bestia} from "../src/Bestia.sol";

contract DeployBestia is Script {
    function run() external returns (Bestia, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address manager, // Not used in this contract
            address banker,
            address usdc,
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
