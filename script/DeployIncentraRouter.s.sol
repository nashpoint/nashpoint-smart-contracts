// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IncentraRouter} from "src/routers/IncentraRouter.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/DeployIncentraRouter.s.sol:DeployIncentraRouter --rpc-url ${ARBITRUM_RPC_URL} --broadcast --legacy --verify -vvv

contract DeployIncentraRouter is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        string memory json = vm.readFile("deployments/arbitrum.json");
        address nodeRegistryAddress = json.readAddress(".NodeRegistry");

        vm.startBroadcast(privateKey);
        address incetraRouter =
            address(new IncentraRouter(nodeRegistryAddress, 0x273d0d19eaC2861FCF6B21893AD6d71b018E25aB));
        vm.stopBroadcast();

        console2.log("IncentraRouter deployed at: ");
        console2.log(incetraRouter);
    }
}
