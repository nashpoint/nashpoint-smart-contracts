// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {INode} from "src/interfaces/INode.sol";
contract NodeTest is BaseTest {
    INode public node;

    function setUp() public override {
        super.setUp();

        node = nodeFactory.createNode(address(erc20), "Test Node", "TNODE", address(this), keccak256("test"));
    }

    function test_decimals() public {
        assertEq(node.decimals(), 18, "Node decimals should be 18");
    }
}

