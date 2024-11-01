// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode} from "src/interfaces/INode.sol";
import {IERC7540Deposit} from "src/interfaces/IERC7540.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

contract NodeTest is BaseTest {
    address[] public routers_;
    INode newNode;
    address manager_;
    address escrow_;
    address rebalancer_;
    address quoter_;

    function setUp() public override {
        super.setUp();
        manager_ = makeAddr("manager_");
        escrow_ = makeAddr("escrow_");
        rebalancer_ = makeAddr("rebalancer_");
        quoter_ = makeAddr("quoter");

        address[] memory routers = new address[](1);
        routers[0] = address(deployer.erc4626Router());

        newNode =
            nodeFactory.createNode("NewNode", "NN", address(erc20), owner, rebalancer, address(quoter), routers, SALT);
    }

    function test_initialize_reverts() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        node.initialize(address(escrow), address(queueManager));

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        newNode.initialize(address(0), manager_);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        newNode.initialize(escrow_, address(0));
        vm.stopPrank();

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        newNode.initialize(escrow_, manager_);
    }

    function test_initialize_succeeds() public {
        assertFalse(newNode.isInitialized());

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit EventsLib.Initialize(escrow_, manager_);
        newNode.initialize(escrow_, manager_);

        assertTrue(newNode.isInitialized());
        assertEq(newNode.escrow(), escrow_);
        assertEq(address(newNode.manager()), manager_);
    }

    function test_addRouter_reverts() public {
        address router = makeAddr("router");

        vm.startPrank(owner);
        node.addRouter(router);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        node.addRouter(router);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        node.addRouter(address(0));
    }

    function test_addRouter_succeeds() public {
        address router = makeAddr("router");
        assertFalse(node.isRouter(router));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit EventsLib.AddRouter(router);
        node.addRouter(router);

        assertTrue(node.isRouter(router));
    }

    function test_removeRouter() public {
        address router = makeAddr("router");

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        node.removeRouter(router);

        vm.startPrank(owner);
        node.addRouter(router);
        assertTrue(node.isRouter(router));

        vm.expectEmit(true, false, false, true);
        emit EventsLib.RemoveRouter(router);
        node.removeRouter(router);
        vm.stopPrank();

        assertFalse(node.isRouter(router));
    }

    function test_addRebalancer_alreadySet() public {
        vm.startPrank(owner);
        node.setRebalancer(rebalancer_);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        node.setRebalancer(rebalancer_);
        vm.stopPrank();
    }

    function test_addRebalancer_suceeds() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit EventsLib.SetRebalancer(rebalancer_);
        node.setRebalancer(rebalancer_);

        assertEq(node.rebalancer(), rebalancer_);
    }

    function test_setEscrow_reverts() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        node.setEscrow(address(0));

        vm.startPrank(owner);
        node.setEscrow(escrow_);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        node.setEscrow(escrow_);
        vm.stopPrank();
    }

    function test_setQuoter_reverts() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        node.setQuoter(address(0));

        vm.startPrank(owner);
        node.setQuoter(quoter_);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        node.setQuoter(quoter_);
        vm.stopPrank();
    }

    function test_setQuoter_succeeds() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit EventsLib.SetQuoter(quoter_);
        node.setQuoter(quoter_);

        assertEq(address(node.quoter()), quoter_);
    }

    function test_execute() public {
        // Create test data for execute call
        address target = makeAddr("target");
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("test()");
        bytes memory expectedResult = abi.encode(true);

        // Mock the target call
        vm.mockCall(target, data, expectedResult);

        // Should revert if not called by router
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRouter.selector);
        newNode.execute(target, value, data);

        // Should revert if target is zero address
        vm.prank(address(0));
        vm.expectRevert(ErrorsLib.NotRouter.selector);
        newNode.execute(address(0), value, data);

        // Should succeed when called by router
        vm.prank(address(deployer.erc4626Router()));
        vm.expectEmit(true, true, true, true);
        emit EventsLib.Execute(target, value, data, expectedResult);
        bytes memory result = newNode.execute(target, value, data);

        assertEq(result, expectedResult);
    }

    function test_requestDeposit() public {}
}
