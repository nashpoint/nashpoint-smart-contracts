// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {PROTOCOL_OWNER} from "./Constants.sol";

// source .env && forge script script/DeployProxyAdmin.s.sol:DeployProxyAdmin --rpc-url ${ARBITRUM_RPC_URL} --broadcast --legacy --verify -vvv

contract DeployProxyAdmin is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        ProxyAdmin proxyAdmin = new ProxyAdmin(PROTOCOL_OWNER);
        vm.stopBroadcast();

        console2.log("ProxyAdmin deployed at: ");
        console2.log(address(proxyAdmin));
    }
}
