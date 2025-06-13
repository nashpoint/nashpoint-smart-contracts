// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {INode} from "src/interfaces/INode.sol";
import {console2} from "forge-std/console2.sol";

contract UpdateComponents is Script {
    // Live deployed addresses
    address constant deployedNodeAddress = 0x6ca200319A0D4127a7a473d6891B86f34e312F42;
    address constant deployedRouter4626 = 0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6;
    address constant deployedRouter7540 = 0x6a200b1Bafc7183741809B35E1B0DE9E4f4c0828;

    // Component addresses
    address constant farmUsdcAaveV3Address = 0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c; // aave
    address constant cfgUsdcJTRSY = 0x16C796208c6E2d397Ec49D69D207a9cB7d072f04; // centrifuge
    address constant fUsdcAddress = 0x1A996cb54bb95462040408C06122D45D6Cdb6096; // fluid
    address constant sdUSDCV3Address = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6; // gearbox
    address constant revertUsdcV3VaultAddress = 0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825; // revert

    INode liveNode = INode(deployedNodeAddress);

    function run() external {
        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
        console2.log("Updating component allocations for Node:", deployedNodeAddress);
        console2.log("Using deployer address:", deployer);

        vm.startBroadcast(privateKey);

        // Update component allocations
        liveNode.updateComponentAllocation(farmUsdcAaveV3Address, 0.1000 ether, 0.01 ether, deployedRouter4626);
        console2.log("Updated Harvest (Aave) allocation to 10.00%");

        liveNode.updateComponentAllocation(cfgUsdcJTRSY, 0.2043 ether, 0.01 ether, deployedRouter7540);
        console2.log("Updated Centrifuge allocation to 20.43%");

        liveNode.updateComponentAllocation(fUsdcAddress, 0.2427 ether, 0.01 ether, deployedRouter4626);
        console2.log("Updated Fluid Lending allocation to 24.27%");

        liveNode.updateComponentAllocation(sdUSDCV3Address, 0.0635 ether, 0.01 ether, deployedRouter4626);
        console2.log("Updated Gearbox Protocol allocation to 6.35%");

        liveNode.updateComponentAllocation(revertUsdcV3VaultAddress, 0.3395 ether, 0.01 ether, deployedRouter4626);
        console2.log("Updated Revert v3 Staker allocation to 33.95%");

        // Add rebalancer
        liveNode.addRebalancer(deployer);
        console2.log("Added deployer as rebalancer");

        vm.stopBroadcast();

        console2.log("Component allocation updates completed successfully!");
        console2.log("Total allocation: 100.00% (5% reserve + 95% components)");
    }
}
