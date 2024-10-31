// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {BaseRebalancer} from "src/libraries/BaseRebalancer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestRebalancer is BaseRebalancer {
    constructor(address node_, address owner_) BaseRebalancer(node_, owner_) {}
}

contract BaseRebalancerTest is BaseTest {
    TestRebalancer public rebalancer;
    address operator;

    event AddOperator(address indexed operator);
    event RemoveOperator(address indexed operator);

    function setUp() public override {
        super.setUp();

        operator = makeAddr("operator");

        rebalancer = new TestRebalancer(address(node), owner);
    }

    function test_deployment() public {
        TestRebalancer newRebalancer = new TestRebalancer(address(node), owner);

        assertEq(address(newRebalancer.node()), address(node));
        assertEq(Ownable(address(newRebalancer)).owner(), owner);
        assertFalse(newRebalancer.isOperator(operator));
    }

    function test_deployment_RevertIf_ZeroNode() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new TestRebalancer(address(0), owner);
    }

    function test_deployment_RevertIf_ZeroOwner() public {
        vm.expectRevert();
        new TestRebalancer(address(node), address(0));
    }

    function test_addOperator() public {
        vm.expectEmit(true, false, false, false);
        emit EventsLib.AddOperator(operator);

        vm.prank(owner);
        rebalancer.addOperator(operator);

        assertTrue(rebalancer.isOperator(operator));
    }

    function test_addOperator_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        rebalancer.addOperator(operator);
    }

    function test_removeOperator() public {
        vm.prank(owner);
        rebalancer.addOperator(operator);
        assertTrue(rebalancer.isOperator(operator));

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RemoveOperator(operator);

        vm.prank(owner);
        rebalancer.removeOperator(operator);
        assertFalse(rebalancer.isOperator(operator));
    }

    function test_removeOperator_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        rebalancer.removeOperator(operator);
    }

    function test_approve_RevertIf_NotOperatorOrOwner() public {
        address spender = makeAddr("spender");
        uint256 amount = 1000;

        vm.expectRevert(ErrorsLib.NotOperator.selector);
        vm.prank(randomUser);
        rebalancer.approve(address(erc20), spender, amount);
    }
}
