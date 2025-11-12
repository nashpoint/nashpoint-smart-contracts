// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation, NodeInitArgs} from "src/interfaces/INode.sol";
import {INodeFactory} from "src/interfaces/INodeFactory.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract DecimalsTests is BaseTest {
    INode public decNode;
    address public decEscrow;
    ERC20Mock public testToken6;
    ERC20Mock public testToken18;
    ERC4626Mock public testVault6;
    ERC4626Mock public testVault18;
    uint256 public maxDeposit;

    function setUp() public override {
        super.setUp();
        testToken18 = new ERC20Mock("Test Token 18", "TEST 18");
        testVault18 = new ERC4626Mock(address(testToken18));

        testToken6 = new ERC20Mock("Test Token 6", "TEST 6");
        testToken6.setDecimals(6);
        testVault6 = new ERC4626Mock(address(testToken6));

        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.maxDepositSize();

        vm.startPrank(owner);
        router4626.setWhitelistStatus(address(testVault6), true);

        bytes[] memory payload = new bytes[](4);
        payload[0] = abi.encodeWithSelector(INode.addRouter.selector, address(router4626));
        payload[1] = abi.encodeWithSelector(INode.addRebalancer.selector, rebalancer);
        ComponentAllocation memory allocation = _defaultComponentAllocations(1)[0];
        payload[2] = abi.encodeWithSelector(
            INode.addComponent.selector,
            address(testVault6),
            allocation.targetWeight,
            allocation.maxDelta,
            allocation.router
        );
        payload[3] = abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, 0.1 ether);

        (decNode,) = factory.deployFullNode(
            NodeInitArgs("Decimal Node", "DNODE", address(testToken6), owner), payload, keccak256("new salt")
        );
        decNode.setMaxDepositSize(1e36);
        vm.stopPrank();

        vm.label(address(testToken18), "Test Token 18");
        vm.label(address(testVault18), "Test Vault 18");
        vm.label(address(testToken6), "Test Token 6");
        vm.label(address(testVault6), "Test Vault 6");
        vm.label(address(decNode), "Decimal Tests Node");
        vm.label(address(decEscrow), "Decimal Tests Escrow");

        deal(address(testToken6), address(user), type(uint256).max);
    }

    function test_decimals_setup() public view {
        assertEq(testToken18.decimals(), 18);
        assertEq(testVault18.decimals(), 18);

        assertEq(testToken6.decimals(), 6);

        // Node with 6 decimals asset
        assertEq(address(testToken6), decNode.asset());
        assertEq(decNode.decimals(), testToken6.decimals());

        // Node with 18 decimals asset
        assertEq(node.decimals(), 18);
        assertEq(node.decimals(), ERC20(address(asset)).decimals());
    }

    function test_decimals_deposit(uint256 deposit, uint64 allocation) public {
        deposit = bound(deposit, 10, 1e36);
        allocation = uint64(bound(uint256(allocation), 1, 1e18));

        vm.warp(block.timestamp + 25 hours);

        vm.startPrank(owner);
        decNode.updateComponentAllocation(address(testVault6), allocation, 0, address(router4626));
        decNode.updateTargetReserveRatio(1e18 - allocation);
        vm.stopPrank();

        vm.prank(rebalancer);
        decNode.startRebalance();

        vm.startPrank(user);
        testToken6.approve(address(decNode), deposit);
        decNode.deposit(deposit, user);
        vm.stopPrank();

        assertEq(testToken6.balanceOf(address(decNode)), decNode.balanceOf(address(user)));

        vm.prank(rebalancer);
        router4626.invest(address(decNode), address(testVault6), 0);

        ComponentAllocation memory componentAllocation = decNode.getComponentAllocation(address(testVault6));

        assertEq(testVault6.balanceOf(address(decNode)), Math.mulDiv(deposit, componentAllocation.targetWeight, 1e18));
        assertEq(testToken6.balanceOf(address(testVault6)), testVault6.balanceOf(address(decNode)));

        assertEq(decNode.balanceOf(address(user)), deposit);
    }
}
