// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import "forge-std/Script.sol";

contract Deployer is Script {
    address public deployer;

    NodeRegistry public nodeRegistry;
    NodeFactory public nodeFactory;
    QuoterV1 public quoter;
    ERC4626Router public erc4626Router;

    function deploy(address deployer_) public {
        deployer = deployer_;

        // If no salt is provided, a pseudo-random salt is generated,
        // thus effectively making the deployment non-deterministic
        bytes32 salt = vm.envOr(
            "DEPLOYMENT_SALT", keccak256(abi.encodePacked(string(abi.encodePacked(blockhash(block.number - 1)))))
        );

        nodeRegistry = new NodeRegistry{salt: salt}(deployer);

        nodeFactory = new NodeFactory{salt: salt}(address(nodeRegistry));
        quoter = new QuoterV1{salt: salt}(address(nodeRegistry));
        erc4626Router = new ERC4626Router{salt: salt}(address(nodeRegistry));
    }
}
