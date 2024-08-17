// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Bestia} from "../src/Bestia.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract DeployContracts is Script {
    // CONTRACTS
    Bestia public bestia;
    ERC20Mock public usdc;
    ERC4626Mock public vaultA;
    ERC4626Mock public vaultB;
    ERC4626Mock public vaultC;
    ERC7540Mock public liquidityPool;

    address manager;
    address banker;

    function run() external {
        vm.startBroadcast();
        manager = 0x65C4De6E6B1eb9484FA49eDCC8Ea571A61c60D3e; // or any specific address
        banker = 0x65C4De6E6B1eb9484FA49eDCC8Ea571A61c60D3e; // or any specific address

        usdc = new ERC20Mock("Mock USDC", "USDC");
        vaultA = new ERC4626Mock(address(usdc));
        vaultB = new ERC4626Mock(address(usdc));
        vaultC = new ERC4626Mock(address(usdc));
        liquidityPool = new ERC7540Mock(usdc, "7540 Token", "7540", address(manager));
        bestia = new Bestia(
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
    }
}
