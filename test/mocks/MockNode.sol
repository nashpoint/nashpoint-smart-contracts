// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

contract MockNode {
    mapping(address => bool) public isRebalancer;

    constructor() {}

    function setRebalancer(address rebalancer, bool value) external {
        isRebalancer[rebalancer] = value;
    }

    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory) {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.NotRebalancer();
        if (target == address(0)) revert ErrorsLib.ZeroAddress();

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Node: execute failed");

        emit EventsLib.Execute(target, value, data, result);
        return result;
    }
}
