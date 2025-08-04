// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {MerklRouter} from "src/routers/MerklRouter.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/DeployMerklRouter.s.sol:DeployMerklRouter --rpc-url ${ARBITRUM_RPC_URL} --broadcast --legacy --verify -vvv

contract DeployMerklRouter is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        string memory json = vm.readFile("deployments/arbitrum.json");
        address nodeRegistryAddress = json.readAddress(".NodeRegistry");

        vm.startBroadcast(privateKey);
        address merklRouter = address(new MerklRouter(nodeRegistryAddress));
        vm.stopBroadcast();

        console2.log("MerklRouter deployed at: ");
        console2.log(merklRouter);
    }
}
