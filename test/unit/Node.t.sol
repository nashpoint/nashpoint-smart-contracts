// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode} from "src/interfaces/INode.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NodeTest is BaseTest {
    address mockManager;
    address mockRebalancer;
    address[] mockRebalancers;

    function setUp() public override {
        super.setUp();
        
        mockManager = makeAddr("mockManager");
        mockRebalancer = makeAddr("mockRebalancer");
        
        mockRebalancers = new address[](3);
        for(uint i = 0; i < 3; i++) {
            mockRebalancers[i] = makeAddr(string.concat("rebalancer_", vm.toString(i)));
        }
    }

    function test_deployment() public {
        Node newNode = new Node(
            address(erc20),
            "Test Node",
            "NODE",
            address(escrow),
            address(0),
            new address[](0),
            owner
        );

        assertEq(address(newNode.asset()), address(erc20));
        assertEq(newNode.name(), "Test Node");
        assertEq(newNode.symbol(), "NODE");
        assertEq(address(newNode.escrow()), address(escrow));
        assertEq(address(newNode.manager()), address(0));
        assertEq(Ownable(address(newNode)).owner(), owner);
        assertEq(newNode.getComponents().length, 0);
    }

    function test_deployment_RevertIf_ZeroAsset() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(0),
            "Test Node",
            "NODE",
            address(escrow),
            address(0),
            new address[](0),
            owner
        );
    }

    function test_deployment_RevertIf_ZeroEscrow() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Node(
            address(erc20),
            "Test Node",
            "NODE",
            address(0),
            address(0),
            new address[](0),
            owner
        );
    }

    function test_setManager() public {
        vm.prank(owner);
        node.setManager(mockManager);
        assertEq(address(node.manager()), mockManager);
    }

    function test_setManager_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        node.setManager(mockManager);
    }

    function test_setManager_RevertIf_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        vm.prank(owner);
        node.setManager(address(0));
    }

    function test_addRebalancer() public {
        vm.startPrank(owner);
        node.addRebalancer(mockRebalancer);
        assertTrue(node.isRebalancer(mockRebalancer));
        vm.stopPrank();
    }

    function test_addRebalancer_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        node.addRebalancer(mockRebalancer);
    }

    function test_addRebalancer_RevertIf_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        vm.prank(owner);
        node.addRebalancer(address(0));
    }

    function test_addRebalancer_RevertIf_AlreadyAdded() public {
        vm.startPrank(owner);
        node.addRebalancer(mockRebalancer);
        
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        node.addRebalancer(mockRebalancer);
        vm.stopPrank();
    }

    function test_removeRebalancer() public {
        vm.startPrank(owner);
        node.addRebalancer(mockRebalancer);
        assertTrue(node.isRebalancer(mockRebalancer));

        node.removeRebalancer(mockRebalancer);
        assertFalse(node.isRebalancer(mockRebalancer));
        
        vm.stopPrank();
    }

    function test_removeRebalancer_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        node.removeRebalancer(mockRebalancer);
    }

    function test_removeRebalancer_RevertIf_NotSet() public {
        vm.expectRevert(ErrorsLib.NotSet.selector);
        vm.prank(owner);
        node.removeRebalancer(mockRebalancer);
    }

    function test_multipleRebalancers() public {
        vm.startPrank(owner);
        
        for(uint i = 0; i < mockRebalancers.length; i++) {
            node.addRebalancer(mockRebalancers[i]);
            assertTrue(node.isRebalancer(mockRebalancers[i]));
        }
        
        for(uint i = 0; i < mockRebalancers.length; i++) {
            node.removeRebalancer(mockRebalancers[i]);
            assertFalse(node.isRebalancer(mockRebalancers[i]));
        }
        
        vm.stopPrank();
    }

    function test_requestDeposit() public {
        uint256 amount = 100e18;

        vm.expectRevert();
        vm.startPrank(user);
        node.requestDeposit(amount, user, user);

        erc20.approve(address(node), amount);
        node.requestDeposit(amount, user, user);

        uint256 pendingDeposits = node.pendingDepositRequest(0, address(user));
        assertEq(amount, pendingDeposits);
    }

    function test_setOperator() public {
        vm.prank(user);
        node.setOperator(address(mockOperator), true);

        assertTrue(node.isOperator(user, mockOperator));
        assertFalse(node.isOperator(user, randomUser));
        assertFalse(node.isOperator(mockOperator, user));
    }

}
