// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsNodeFactory.sol";
import "./helpers/postconditions/PostconditionsNodeFactory.sol";

import {NodeFactory} from "../../src/NodeFactory.sol";

contract FuzzNodeFactory is PreconditionsNodeFactory, PostconditionsNodeFactory {
    function fuzz_nodeFactory_deploy(uint256 seed) public setCurrentActor(seed) {
        NodeFactoryDeployParams memory params = nodeFactoryDeployPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(factory),
            abi.encodeWithSelector(NodeFactory.deployFullNode.selector, params.initArgs, params.payload, params.salt),
            currentActor
        );

        nodeFactoryDeployPostconditions(success, returnData, currentActor, params);
    }
}
