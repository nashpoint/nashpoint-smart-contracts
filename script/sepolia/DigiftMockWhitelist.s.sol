// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {stdJson} from "forge-std/StdJson.sol";

import {DigiftWrapper} from "src/wrappers/digift/DigiftWrapper.sol";
import {ERC20MockOwnable} from "test/mocks/ERC20MockOwnable.sol";
import {SubRedManagementMock} from "test/mocks/SubRedManagementMock.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/sepolia/DigiftMockWhitelist.s.sol:DigiftMockWhitelist --rpc-url ${ETH_SEPOLIA_RPC_URL} -vvv --broadcast --legacy --with-gas-price 30000000000

contract DigiftMockWhitelist is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        string memory json = vm.readFile("deployments/sepolia-mock.json");
        DigiftWrapper digiftWrapper = DigiftWrapper(json.readAddress(".digiftWrapper"));
        SubRedManagementMock subRedManagement = SubRedManagementMock(json.readAddress(".subRedManagement"));

        vm.startBroadcast(privateKey);
        subRedManagement.setManager(deployer, true);
        subRedManagement.setWhitelist(address(digiftWrapper), true);
        vm.stopBroadcast();
    }
}
