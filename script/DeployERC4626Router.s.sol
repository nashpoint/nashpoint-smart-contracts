// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ERC4626Router} from "src/routers/ERC4626Router.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/DeployERC4626Router.s.sol:DeployERC4626Router --rpc-url ${ARBITRUM_RPC_URL} --broadcast --legacy --verify -vvv

// Deploy an updated ERC4626Router where maxRedeem check in _liquidate is removed
contract DeployERC4626Router is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        string memory json = vm.readFile("deployments/arbitrum.json");
        address nodeRegistryAddress = json.readAddress(".NodeRegistry");

        vm.startBroadcast(privateKey);
        address erc4626Router = address(new ERC4626Router(nodeRegistryAddress));
        vm.stopBroadcast();

        console2.log("ERC4626Router deployed at: ");
        console2.log(erc4626Router);
    }
}
