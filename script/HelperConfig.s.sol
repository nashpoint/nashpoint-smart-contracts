// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    struct NetworkConfig {
        address liquidityPool;
    }

    event HelperConfig__CreatedMockLiquidityPool(address liquidityPool);

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            liquidityPool: 0x2dC69d1A0d012692B92b5E66A5E1525DA066B728 // ETH / USD
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.liquidityPool != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        // ERC7540Mock mockLiquidityPool = new ERC7540Mock(
        //     DECIMALS,
        //     INITIAL_PRICE
        // );
        vm.stopBroadcast();
        // emit HelperConfig__CreatedMockLiquidityPool(address(mockLiquidityPool));

        // anvilNetworkConfig = NetworkConfig({liquidityPool: address(mockLiquidityPool)});
    }
}
