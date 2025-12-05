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
            _after();

            (address deployedNode, address deployedEscrow) = abi.decode(returnData, (address, address));

            Node nodeInstance = Node(deployedNode);

            invariant_FACTORY_01(deployedNode);
            invariant_FACTORY_02(deployedEscrow);
            invariant_FACTORY_03(deployedNode, deployedEscrow);
            invariant_FACTORY_04(deployedNode, params);
            invariant_FACTORY_05(deployedNode, params);
            invariant_FACTORY_06(deployedNode);
            invariant_FACTORY_07(deployedNode);

            onSuccessInvariantsGeneral(returnData);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
