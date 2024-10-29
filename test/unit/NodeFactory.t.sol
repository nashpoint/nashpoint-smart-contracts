// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {Escrow} from "src/Escrow.sol";
import {Node} from "src/Node.sol";
import {INode} from "src/interfaces/INode.sol";
import {INodeFactory} from "src/interfaces/INodeFactory.sol";

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

    address public randomNode;
    address public randomQuoter;

    function setUp() public override {
        super.setUp();
        randomNode = makeAddr("node");
        randomQuoter = makeAddr("quoter");
    }

    /* TEST FACTORY CREATION */
    function test_createERC4626Rebalancer() public {
        bytes32 salt = keccak256("rebalancer");
        address rebalancer = address(nodeFactory.createERC4626Rebalancer(randomNode, deployer, salt));
        assertTrue(rebalancer != address(0));
    }

    function test_createEscrow() public {
        bytes32 salt = keccak256("escrow");
        address escrow = address(nodeFactory.createEscrow(deployer, salt));
        assertTrue(escrow != address(0));
    }

    function test_createQueueManager() public {
        bytes32 salt = keccak256("manager");
        address manager = address(nodeFactory.createQueueManager(randomNode, randomQuoter, deployer, salt));
        assertTrue(manager != address(0));
    }

    function test_createQuoter() public {
        bytes32 salt = keccak256("quoter");
        address quoter = address(nodeFactory.createQuoter(randomNode, deployer, salt));
        assertTrue(quoter != address(0));
    }
}
