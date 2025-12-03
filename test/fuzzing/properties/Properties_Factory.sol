// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";
import {Node} from "../../../src/Node.sol";
import {INodeRegistry} from "../../../src/interfaces/INodeRegistry.sol";
import {IERC7575} from "../../../src/interfaces/IERC7575.sol";

contract Properties_Factory is Properties_ERR {
    // ==============================================================
    // NODE FACTORY INVARIANTS
    // ==============================================================

    function invariant_FACTORY_01(address deployedNode) internal {
        // fl.t(deployedNode != address(0), FACTORY_01);
    }

    function invariant_FACTORY_02(address deployedEscrow) internal {
        // fl.t(deployedEscrow != address(0), FACTORY_02);
    }

    function invariant_FACTORY_03(address deployedNode, address deployedEscrow) internal {
        Node nodeInstance = Node(deployedNode);
        // fl.eq(nodeInstance.escrow(), deployedEscrow, FACTORY_03);
    }

    function invariant_FACTORY_04(address deployedNode, NodeFactoryDeployParams memory params) internal {
        // fl.eq(IERC7575(deployedNode).asset(), params.initArgs.asset, FACTORY_04);
    }

    function invariant_FACTORY_05(address deployedNode, NodeFactoryDeployParams memory params) internal {
        Node nodeInstance = Node(deployedNode);
        // fl.eq(nodeInstance.owner(), params.initArgs.owner, FACTORY_05);
    }

    function invariant_FACTORY_06(address deployedNode) internal {
        Node nodeInstance = Node(deployedNode);
        // fl.t(nodeInstance.totalSupply() == 0, FACTORY_06);
    }

    function invariant_FACTORY_07(address deployedNode) internal {
        // fl.t(INodeRegistry(address(registry)).isNode(deployedNode), FACTORY_07);
    }
}
