// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./interfaces/INode.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {Ownable2Step, Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/**
 * @title Quoter
 * @author ODND Studios
 */
contract Quoter is Ownable2Step, IQuoter {

    /* IMMUTABLES */

    INode public immutable node;

    /* STORAGE */

    /* CONSTRUCTOR */

    constructor(address node_, address owner_) Ownable(owner_) {
        node = INode(node_);
    }

    /* EXTERNAL */

    function getTotalAssets() external view returns (uint256) {
    }
}
