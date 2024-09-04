// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address manager;
        address banker;
        address usdc;
        address vaultA;
        address vaultB;
        address vaultC;
        address liquidityPool;
    }

    event HelperConfig__CreatedNetworkConfig(
        address manager,
        address banker,
        address usdc,
        address vaultA,
        address vaultB,
        address vaultC,
        address liquidityPool
    );

    constructor() {
        if (block.chainid == 421614) {
            activeNetworkConfig = getArbSepoliaConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getEthMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    // MAINNET CONFIG FOR CFG TESTING
    function getEthMainnetConfig() public returns (NetworkConfig memory ethNetworkConfig) {
        vm.startBroadcast();
        address banker = address(5);
        ERC20Mock usdc = new ERC20Mock("Mock USDC", "USDC");
        ERC4626Mock vaultA = new ERC4626Mock(address(usdc));
        ERC4626Mock vaultB = new ERC4626Mock(address(usdc));
        ERC4626Mock vaultC = new ERC4626Mock(address(usdc));

        vm.stopBroadcast();
        ethNetworkConfig = NetworkConfig({
            manager: 0xE79f06573d6aF1B66166A926483ba00924285d20,
            banker: address(banker),
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            vaultA: address(vaultA),
            vaultB: address(vaultB),
            vaultC: address(vaultC),
            liquidityPool: 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.liquidityPool != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        address banker = address(5);
        address manager = address(6);
        ERC20Mock usdc = new ERC20Mock("Mock USDC", "USDC");
        ERC4626Mock vaultA = new ERC4626Mock(address(usdc));
        ERC4626Mock vaultB = new ERC4626Mock(address(usdc));
        ERC4626Mock vaultC = new ERC4626Mock(address(usdc));
        ERC7540Mock liquidityPool = new ERC7540Mock(usdc, "7540 Token", "7540", address(manager));

        vm.stopBroadcast();
        anvilNetworkConfig = NetworkConfig({
            manager: address(manager),
            banker: address(banker),
            usdc: address(usdc),
            vaultA: address(vaultA),
            vaultB: address(vaultB),
            vaultC: address(vaultC),
            liquidityPool: address(liquidityPool)
        });
        emit HelperConfig__CreatedNetworkConfig(
            address(manager),
            address(banker),
            address(usdc),
            address(vaultA),
            address(vaultB),
            address(vaultC),
            address(liquidityPool)
        );
    }

    function getArbSepoliaConfig() public pure returns (NetworkConfig memory testNetworkConfig) {
        testNetworkConfig = NetworkConfig({
            manager: 0x65C4De6E6B1eb9484FA49eDCC8Ea571A61c60D3e,
            banker: 0x65C4De6E6B1eb9484FA49eDCC8Ea571A61c60D3e,
            usdc: 0x6755DDab5aA15Cef724Bf523676294DD06D712eb,
            vaultA: 0x59AcD8815169Cc1A1C5959D087ECFEe9f282C150,
            vaultB: 0xd795ecc98299EaF5255Df50Ae423F228Ec2Bf826,
            vaultC: 0xde18b205FD9f31F8DC137cC9939D82d17AaD8739,
            liquidityPool: 0x2dC69d1A0d012692B92b5E66A5E1525DA066B728
        });
    }
}
