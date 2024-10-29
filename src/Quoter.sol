// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable, Ownable2Step} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import {INode} from "./interfaces/INode.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

/// @title Quoter
/// @author ODND Studios
contract Quoter is IQuoter, Ownable2Step {
    /* IMMUTABLES */
    /// @dev Reference to the Node contract this quoter serves
    INode public immutable node;

    constructor(
        address node_,
        address owner_
    ) Ownable(owner_) {
        if (node_ == address(0)) revert ErrorsLib.ZeroAddress();
        node = INode(node_);
    }

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc IQuoter
    function getPrice() external view returns (uint128) {}

    /// @inheritdoc IQuoter
    function getTotalAssets() external view returns (uint256) {}
}
