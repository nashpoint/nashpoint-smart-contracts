// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {OneInchV6RouterV1} from "src/routers/OneInchV6RouterV1.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/DeployOneInchV6RouterV1.s.sol:DeployOneInchV6RouterV1 --rpc-url ${ARBITRUM_RPC_URL} --broadcast --legacy --verify -vvv

contract DeployOneInchV6RouterV1 is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        string memory json = vm.readFile("deployments/arbitrum.json");
        address nodeRegistryAddress = json.readAddress(".NodeRegistry");

        vm.startBroadcast(privateKey);
        address router = address(new OneInchV6RouterV1(nodeRegistryAddress));
        vm.stopBroadcast();

        console2.log("OneInchV6RouterV1 deployed at: ");
        console2.log(router);
    }
}
