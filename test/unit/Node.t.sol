// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode} from "src/interfaces/INode.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

contract NodeTest is BaseTest {
    address[] public routers_;
    INode newNode;
    address manager_;
    address escrow_;

    function setUp() public override {
        super.setUp();
        manager_ = makeAddr("manager_");
        escrow_ = makeAddr("escrow_");
        address[] memory routers = new address[](1);
        routers[0] = address(deployer.erc4626Router());

        newNode =
            nodeFactory.createNode("NewNode", "NN", address(erc20), owner, rebalancer, address(quoter), routers, SALT);
    }

    function test_initialize_alreadyInitialized() public {
        assertTrue(node.isInitialized());

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        node.initialize(address(escrow), address(queueManager));
    }

    function test_initialize_zeroAddress() public {
        assertFalse(newNode.isInitialized());

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        newNode.initialize(address(0), manager_);

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        newNode.initialize(escrow_, address(0));
    }

    function test_initialize_notOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        newNode.initialize(escrow_, manager_);
    }

    function test_initialize_success() public {
        assertFalse(newNode.isInitialized());

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit EventsLib.Initialize(escrow_, manager_);
        newNode.initialize(escrow_, manager_);

        assertTrue(newNode.isInitialized());
        assertEq(newNode.escrow(), escrow_);
        assertEq(address(newNode.manager()), manager_);
    }
}
