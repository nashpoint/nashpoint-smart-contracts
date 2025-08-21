// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {FluidRewardsRouter} from "src/routers/FluidRewardsRouter.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/DeployFluidRewardsRouter.s.sol:DeployFluidRewardsRouter --rpc-url ${ARBITRUM_RPC_URL} --broadcast --legacy --verify -vvv

contract DeployFluidRewardsRouter is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        string memory json = vm.readFile("deployments/arbitrum.json");
        address nodeRegistryAddress = json.readAddress(".NodeRegistry");

        vm.startBroadcast(privateKey);
        address fluidRewardsRouter =
            address(new FluidRewardsRouter(nodeRegistryAddress, 0x94312a608246Cecfce6811Db84B3Ef4B2619054E));
        vm.stopBroadcast();

        console2.log("FluidRewardsRouter deployed at: ");
        console2.log(fluidRewardsRouter);
    }
}
