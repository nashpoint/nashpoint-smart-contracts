// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./interfaces/INode.sol";
import {Ownable2Step, Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {IQueueManager} from "./interfaces/IQueueManager.sol";

/**
 * @title QueueManager
 * @author ODND Studios
 */
contract QueueManager is Ownable2Step, IQueueManager {

    /* IMMUTABLES */

    INode public immutable node;

    /* STORAGE */

    IQuoter public quoter;

    /* CONSTRUCTOR */

    constructor(address node_, address quoter_, address owner_) Ownable(owner_) {
        node = INode(node_);
        quoter = IQuoter(quoter_);
    }

    /* EXTERNAL */

    // function requestDeposit

    // function requestRedeem

    // function fulfillDepositRequest

    // function fulfillRedeemRequest

}
