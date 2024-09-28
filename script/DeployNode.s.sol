// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Node} from "../src/Node.sol";

contract DeployNode is Script {
    function run() external returns (Node, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            , // ignore manager
            address banker,
            address usdc,
            ,
            ,
            ,
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        Node node = new Node(
            address(usdc),
            "Node",
            "BEST",
            address(banker),
            //  percentages: 1e18 == 100%
            2e16, // maxDiscount (percentage)
            10e16, // targetReserveRatio (percentage)
            1e16, // maxDelta (percentage)
            3e16, // asyncMaxDelta (percentage)
            address(msg.sender) // using msg.sender as owner for local testing
        );
        vm.stopBroadcast();
        return (node, helperConfig);
    }
}
