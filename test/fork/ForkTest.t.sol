// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "test/BaseTest.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {console2} from "forge-std/console2.sol";

contract ForkTest is BaseTest {
    uint256 arbitrumFork;
    address constant usdcAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant yUsdcA = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1;
    uint256 constant blockNumber = 277189217;

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL, blockNumber);
        vm.selectFork(arbitrumFork);
        super.setUp();
    }

    function test_canSelectArbitrum() public {
        vm.selectFork(arbitrumFork);
        assertEq(vm.activeFork(), arbitrumFork);
    }

    function test_usdcAddress() public view {
        string memory name = IERC20Metadata(usdcAddress).name();
        uint256 totalSupply = IERC20Metadata(usdcAddress).totalSupply();
        assertEq(name, "USD Coin");
        assertEq(totalSupply, 1808663807522167);
        assertEq(IERC20Metadata(usdcAddress).decimals(), 6);
    }

    function test_yearnUsdcA_Address() public view {
        string memory name = IERC20Metadata(yUsdcA).name();
        address vaultAsset = IERC4626(yUsdcA).asset();

        assertEq(name, "USDC-A yVault");
        assertEq(vaultAsset, usdcAddress);
    }
}
