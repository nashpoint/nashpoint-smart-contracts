// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {stdJson} from "forge-std/StdJson.sol";

import {DigiftWrapper} from "src/wrappers/digift/DigiftWrapper.sol";
import {ERC20MockOwnable} from "test/mocks/ERC20MockOwnable.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/sepolia/DigiftSubscribeTesting.s.sol:DigiftSubscribeTesting --rpc-url ${ETH_SEPOLIA_RPC_URL} -vvv --broadcast --legacy --with-gas-price 25000000000

contract DigiftSubscribeTesting is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        string memory json = vm.readFile("deployments/sepolia-testing.json");
        DigiftWrapper digiftWrapper = DigiftWrapper(json.readAddress(".digiftWrapper"));
        ERC20MockOwnable usdc = ERC20MockOwnable(json.readAddress(".usdc"));

        vm.startBroadcast(privateKey);
        usdc.approve(address(digiftWrapper), 1000e6);
        digiftWrapper.requestDeposit(1000e6, deployer, deployer);
        digiftWrapper.forwardRequestsToDigift();
        vm.stopBroadcast();
    }
}
