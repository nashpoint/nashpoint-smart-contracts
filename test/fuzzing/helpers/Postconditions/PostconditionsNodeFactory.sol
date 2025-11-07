// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {Node} from "../../../../src/Node.sol";
import {INodeRegistry} from "../../../../src/interfaces/INodeRegistry.sol";
import {IERC7575} from "../../../../src/interfaces/IERC7575.sol";

contract PostconditionsNodeFactory is PostconditionsBase {
    function nodeFactoryDeployPostconditions(
        bool success,
        bytes memory returnData,
        address caller,
        NodeFactoryDeployParams memory params
    ) internal {
        caller; // silence warning

        if (success) {
            (address deployedNode, address deployedEscrow) = abi.decode(returnData, (address, address));
            // fl.t(deployedNode != address(0), "NODE_FACTORY_DEPLOYED_ZERO");
            // fl.t(deployedEscrow != address(0), "NODE_FACTORY_ESCROW_ZERO");

            Node nodeInstance = Node(deployedNode);

            // fl.eq(nodeInstance.escrow(), deployedEscrow, "NODE_FACTORY_ESCROW_LINK");
            // fl.eq(IERC7575(deployedNode).asset(), params.initArgs.asset, "NODE_FACTORY_ASSET_MATCH");
            // fl.eq(nodeInstance.owner(), params.initArgs.owner, "NODE_FACTORY_OWNER_MATCH");
            // fl.t(nodeInstance.totalSupply() == 0, "NODE_FACTORY_SUPPLY_ZERO");
            // fl.t(INodeRegistry(address(registry)).isNode(deployedNode), "NODE_FACTORY_REGISTERED");

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
