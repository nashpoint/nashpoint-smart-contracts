// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import "forge-std/Script.sol";

contract Deployer is Script {
    NodeRegistry public registry;
    NodeFactory public factory;
    QuoterV1 public quoter;
    ERC4626Router public erc4626router;
    ERC7540Router public erc7540router;

    function deploy(address owner) public {
        bytes32 salt = vm.envOr("DEPLOYMENT_SALT", keccak256(abi.encodePacked(blockhash(block.number - 1))));

        // Deploy core contracts
        registry = new NodeRegistry{salt: salt}(owner);
        factory = new NodeFactory{salt: salt}(address(registry));
        quoter = new QuoterV1{salt: salt}(address(registry));
        erc4626router = new ERC4626Router{salt: salt}(address(registry));
        erc7540router = new ERC7540Router{salt: salt}(address(registry));
    }
}
