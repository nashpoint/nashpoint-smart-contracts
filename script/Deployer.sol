// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {NodeFactory} from "src/NodeFactory.sol";

import "forge-std/Script.sol";

contract Deployer is Script {
    address public deployer;
    NodeFactory public nodeFactory;

    function deploy(address deployer_) public {
        deployer = deployer_;

        // If no salt is provided, a pseudo-random salt is generated,
        // thus effectively making the deployment non-deterministic
        bytes32 salt = vm.envOr(
            "DEPLOYMENT_SALT", keccak256(abi.encodePacked(string(abi.encodePacked(blockhash(block.number - 1)))))
        );

        nodeFactory = new NodeFactory{salt: salt}();
    }
}
