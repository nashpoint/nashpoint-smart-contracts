// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {ERC4626Rebalancer} from "src/rebalancers/ERC4626Rebalancer.sol";
import {IERC4626Rebalancer} from "src/interfaces/IERC4626Rebalancer.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {MockNode} from "test/mocks/MockNode.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

contract ERC4626RebalancerTest is BaseTest {
    ERC4626Rebalancer public testRebalancer;
    address operator;
    address mockVault;
    MockNode public mockNode;

    function setUp() public override {
        super.setUp();
        
        operator = makeAddr("operator");
        mockVault = makeAddr("mockVault");
        
        mockNode = new MockNode();
        
        testRebalancer = new ERC4626Rebalancer(
            address(mockNode),
            owner
        );

        vm.prank(owner);
        testRebalancer.addOperator(operator);

        mockNode.setRebalancer(address(testRebalancer), true);
    }

    function test_deployment() public {
        ERC4626Rebalancer newRebalancer = new ERC4626Rebalancer(
            address(node),
            owner
        );

        assertEq(address(newRebalancer.node()), address(node));
        assertEq(newRebalancer.owner(), owner);
    }

    function test_deployment_RevertIf_ZeroNode() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new ERC4626Rebalancer(
            address(0),
            owner
        );
    }

    function test_deposit() public {
        address assets = makeAddr("assets");
        bytes memory depositData = abi.encodeWithSelector(
            IERC4626.deposit.selector,
            assets,
            address(mockNode)
        );

        vm.expectEmit(true, true, true, true);
        emit EventsLib.Execute(mockVault, 0, depositData, "");
        
        vm.prank(operator);
        testRebalancer.deposit(mockVault, assets);
    }

    function test_deposit_RevertIf_NotOperator() public {
        address assets = makeAddr("assets");
        
        vm.expectRevert(ErrorsLib.NotOperator.selector);
        vm.prank(randomUser);
        testRebalancer.deposit(mockVault, assets);
    }

    function test_mint() public {
        address shares = makeAddr("shares");
        bytes memory mintData = abi.encodeWithSelector(
            IERC4626.mint.selector,
            shares,
            address(node)
        );

        vm.prank(operator);
        testRebalancer.mint(mockVault, shares);
    }

    function test_mint_RevertIf_NotOperator() public {
        address shares = makeAddr("shares");
        
        vm.expectRevert(ErrorsLib.NotOperator.selector);
        vm.prank(randomUser);
        testRebalancer.mint(mockVault, shares);
    }

    function test_withdraw() public {
        address assets = makeAddr("assets");
        bytes memory withdrawData = abi.encodeWithSelector(
            IERC4626.withdraw.selector,
            assets,
            address(node),
            address(node)
        );

        vm.prank(operator);
        testRebalancer.withdraw(mockVault, assets);
    }

    function test_withdraw_RevertIf_NotOperator() public {
        address assets = makeAddr("assets");
        
        vm.expectRevert(ErrorsLib.NotOperator.selector);
        vm.prank(randomUser);
        testRebalancer.withdraw(mockVault, assets);
    }

    function test_redeem() public {
        address shares = makeAddr("shares");
        bytes memory redeemData = abi.encodeWithSelector(
            IERC4626.redeem.selector,
            shares,
            address(node),
            address(node)
        );

        vm.prank(operator);
        testRebalancer.redeem(mockVault, shares);
    }

    function test_redeem_RevertIf_NotOperator() public {
        address shares = makeAddr("shares");
        
        vm.expectRevert(ErrorsLib.NotOperator.selector);
        vm.prank(randomUser);
        testRebalancer.redeem(mockVault, shares);
    }

    function test_operatorCanCallAllFunctions() public {
        address assets = makeAddr("assets");
        address shares = makeAddr("shares");

        vm.startPrank(operator);
        
        testRebalancer.deposit(mockVault, assets);
        testRebalancer.mint(mockVault, shares);
        testRebalancer.withdraw(mockVault, assets);
        testRebalancer.redeem(mockVault, shares);
        
        vm.stopPrank();
    }

    function test_ownerCanCallAllFunctions() public {
        address assets = makeAddr("assets");
        address shares = makeAddr("shares");

        vm.startPrank(owner);
        
        testRebalancer.deposit(mockVault, assets);
        testRebalancer.mint(mockVault, shares);
        testRebalancer.withdraw(mockVault, assets);
        testRebalancer.redeem(mockVault, shares);
        
        vm.stopPrank();
    }
} 