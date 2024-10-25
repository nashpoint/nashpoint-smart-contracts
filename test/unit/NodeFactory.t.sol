// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {INode} from "src/interfaces/INode.sol";
import {INodeFactory} from "src/interfaces/INodeFactory.sol";
import {Node} from "src/Node.sol";
import {Escrow} from "src/Escrow.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract NodeFactoryTest is BaseTest {
    event CreateNode(
        address indexed node,
        address indexed asset,
        string name,
        string symbol,
        address escrow,
        address owner,
        bytes32 salt
    );

    function setUp() public override {
        super.setUp();
    }

    function test_isNode() public {
        INode node = nodeFactory.createNode(address(erc20), "Test Node", "TNODE", deployer, keccak256(abi.encodePacked("salt", block.timestamp)));

        assertTrue(nodeFactory.isNode(address(node)));
        assertFalse(nodeFactory.isNode(address(0x1234)));
    }

    function test_createNodeWithZeroAddressAsset() public {
        vm.expectRevert();
        nodeFactory.createNode(address(0), "Zero Asset Node", "ZERO", address(this), keccak256("zero"));
    }

    function test_createNodeWithEmptyName() public {
        vm.expectRevert();
        nodeFactory.createNode(address(erc20), "", "EMPTY", address(this), keccak256("empty"));
    }

    function test_createNodeWithEmptySymbol() public {
        vm.expectRevert();
        nodeFactory.createNode(address(erc20), "Empty Symbol Node", "", address(this), keccak256("empty_symbol"));
    }

    function test_createNodeWithZeroAddressOwner() public {
        vm.expectRevert();
        nodeFactory.createNode(address(erc20), "Zero Owner Node", "ZERO", address(0), keccak256("zero_owner"));
    }

    function test_nodeOwnership() public {
        INode node = nodeFactory.createNode(address(erc20), "Owned Node", "OWNED", deployer, keccak256("owned"));
        assertEq(Node(address(node)).owner(), deployer, "Node owner should be set correctly");
    }
}
