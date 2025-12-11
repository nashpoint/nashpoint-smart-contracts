// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {IAggregationRouterV6} from "../../src/interfaces/IAggregationRouterV6.sol";

contract AggregationRouterV6Mock is IAggregationRouterV6 {
    SwapDescription public lastDescription;
    address public lastExecutor;
    bytes public lastData;
    uint256 public lastReturnAmount;
    uint256 public lastSpentAmount;

    function swap(address executor, SwapDescription calldata desc, bytes calldata data)
        external
        payable
        override
        returns (uint256 returnAmount, uint256 spentAmount)
    {
        lastExecutor = executor;
        lastDescription = desc;
        lastData = data;

        uint256 expectedReturn = abi.decode(data, (uint256));

        // Decrease incentive balance from node
        address node = desc.dstReceiver;
        uint256 nodeBalance = IERC20(desc.srcToken).balanceOf(node);
        if (nodeBalance >= desc.amount) {
            ERC20Mock(desc.srcToken).setBalance(node, nodeBalance - desc.amount);
        } else {
            ERC20Mock(desc.srcToken).setBalance(node, 0);
        }

        // Mint incentive amount to executor to simulate transfer
        uint256 executorBalance = IERC20(desc.srcToken).balanceOf(desc.srcReceiver);
        ERC20Mock(desc.srcToken).setBalance(desc.srcReceiver, executorBalance + desc.amount);

        // Mint destination assets to node
        ERC20Mock(desc.dstToken).mint(node, expectedReturn);

        returnAmount = expectedReturn;
        spentAmount = desc.amount;
        lastReturnAmount = returnAmount;
        lastSpentAmount = spentAmount;
    }
}
