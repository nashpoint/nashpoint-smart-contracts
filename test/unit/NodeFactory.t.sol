// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {Escrow} from "src/Escrow.sol";
import {Node} from "src/Node.sol";
import {Quoter} from "src/Quoter.sol";
import {QueueManager} from "src/QueueManager.sol";
import {ERC4626Rebalancer} from "src/rebalancers/ERC4626Rebalancer.sol";
import {IERC4626Rebalancer} from "src/interfaces/IERC4626Rebalancer.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {INode} from "src/interfaces/INode.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";

contract NodeFactoryTest is BaseTest {
    event CreateNode(
        address indexed node, address indexed asset, string name, string symbol, address owner, bytes32 salt
    );

    function setUp() public override {
        super.setUp();
    }

    function test_deployFullNode() public {
        bytes32 salt = keccak256("test");
        address nodeOwner = makeAddr("nodeOwner");

        vm.expectEmit(false, true, true, true);
        emit EventsLib.CreateNode(address(0), address(erc20), "Test Node", "TEST", address(nodeFactory), salt);

        (node, escrow, quoter, queueManager, erc4626Rebalancer) =
            nodeFactory.deployFullNode(address(erc20), "Test Node", "TEST", nodeOwner, salt);

        assertTrue(address(node) != address(0));
        assertTrue(address(escrow) != address(0));
        assertTrue(address(quoter) != address(0));
        assertTrue(address(queueManager) != address(0));
        assertTrue(address(erc4626Rebalancer) != address(0));
        assertTrue(nodeFactory.isNode(address(node)));

        assertEq(Ownable(address(node)).owner(), nodeOwner);
        assertEq(Ownable(address(escrow)).owner(), nodeOwner);
        assertEq(Ownable(address(quoter)).owner(), nodeOwner);
        assertEq(Ownable(address(queueManager)).owner(), nodeOwner);
        assertEq(Ownable(address(erc4626Rebalancer)).owner(), nodeOwner);

        assertEq(address(node.manager()), address(queueManager));
        assertTrue(node.isRebalancer(address(erc4626Rebalancer)));
    }

    function test_deployFullNode_RevertIf_ZeroAsset() public {
        bytes32 salt = keccak256("zero_asset");

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        nodeFactory.deployFullNode(address(0), "Test Node", "TEST", owner, salt);
    }

    function test_deployFullNode_RevertIf_EmptyName() public {
        bytes32 salt = keccak256("empty_name");

        vm.expectRevert(ErrorsLib.InvalidName.selector);
        nodeFactory.deployFullNode(address(erc20), "", "TEST", owner, salt);
    }

    function test_deployFullNode_RevertIf_EmptySymbol() public {
        bytes32 salt = keccak256("empty_symbol");

        vm.expectRevert(ErrorsLib.InvalidSymbol.selector);
        nodeFactory.deployFullNode(address(erc20), "Test Node", "", owner, salt);
    }

    function test_deployFullNode_RevertIf_ZeroOwner() public {
        bytes32 salt = keccak256("zero_owner");

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        nodeFactory.deployFullNode(address(erc20), "Test Node", "TEST", address(0), salt);
    }

    function test_createEscrow() public {
        bytes32 salt = keccak256("escrow");
        IEscrow escrow_ = nodeFactory.createEscrow(owner, salt);

        assertTrue(address(escrow_) != address(0));
        assertEq(Ownable(address(escrow_)).owner(), owner);
    }

    function test_createNode() public {
        bytes32 salt = keccak256("node");

        vm.expectEmit(false, true, true, true);
        emit EventsLib.CreateNode(address(0), address(erc20), "Test Node", "TEST", owner, salt);

        INode node_ =
            nodeFactory.createNode(address(erc20), "Test Node", "TEST", address(escrow), address(0), owner, salt);

        assertTrue(address(node_) != address(0));
        assertTrue(nodeFactory.isNode(address(node_)));
        assertEq(Ownable(address(node_)).owner(), owner);
    }

    function test_createQuoter() public {
        bytes32 salt = keccak256("quoter");
        IQuoter quoter_ = nodeFactory.createQuoter(address(node), owner, salt);

        assertTrue(address(quoter_) != address(0));
        assertEq(Ownable(address(quoter_)).owner(), owner);
        assertEq(address(quoter_.node()), address(node));
    }

    function test_createQueueManager() public {
        bytes32 salt = keccak256("manager");
        IQueueManager manager_ = nodeFactory.createQueueManager(address(node), address(quoter), owner, salt);

        assertTrue(address(manager_) != address(0));
        assertEq(Ownable(address(manager_)).owner(), owner);
        assertEq(address(manager_.node()), address(node));
        assertEq(address(manager_.quoter()), address(quoter));
    }

    function test_createERC4626Rebalancer() public {
        bytes32 salt = keccak256("rebalancer");
        IERC4626Rebalancer rebalancer_ = nodeFactory.createERC4626Rebalancer(address(node), owner, salt);

        assertTrue(address(rebalancer_) != address(0));
        assertEq(Ownable(address(rebalancer_)).owner(), owner);
        assertEq(address(rebalancer_.node()), address(node));
    }
}
