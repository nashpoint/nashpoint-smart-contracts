// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {Node} from "src/Node.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";

contract ERC4626RouterTest is BaseTest {
    function test_deposit() public {
        uint256 depositAmount = 100 ether;
        
        // Fund node with assets
        deal(address(asset), address(node), depositAmount);
        
        // Approve vault to spend node's assets
        vm.prank(address(node));
        asset.approve(address(vault), depositAmount);
        
        // Deposit through router
        vm.prank(rebalancer);
        router.deposit(address(node), address(vault), depositAmount);
        
        // Verify deposit
        assertEq(vault.balanceOf(address(node)), depositAmount);
        assertEq(asset.balanceOf(address(node)), 0);
    }

    function test_mint() public {
        uint256 mintAmount = 100 ether;
        
        // Fund node with enough assets for minting
        deal(address(asset), address(node), mintAmount);
        
        // Approve vault to spend node's assets
        vm.prank(address(node));
        asset.approve(address(vault), mintAmount);
        
        // Mint through router
        vm.prank(rebalancer);
        router.mint(address(node), address(vault), mintAmount);
        
        // Verify mint
        assertEq(vault.balanceOf(address(node)), mintAmount);
    }

    function test_withdraw() public {
        uint256 amount = 100 ether;
        
        // Setup initial deposit
        deal(address(asset), address(node), amount);
        vm.prank(address(node));
        asset.approve(address(vault), amount);
        vm.prank(rebalancer);
        router.deposit(address(node), address(vault), amount);
        
        // Withdraw through router
        vm.prank(rebalancer);
        router.withdraw(address(node), address(vault), amount);
        
        // Verify withdrawal
        assertEq(vault.balanceOf(address(node)), 0);
        assertEq(asset.balanceOf(address(node)), amount);
    }

    function test_redeem() public {
        uint256 amount = 100 ether;
        
        // Setup initial deposit
        deal(address(asset), address(node), amount);
        vm.prank(address(node));
        asset.approve(address(vault), amount);
        vm.prank(rebalancer);
        router.deposit(address(node), address(vault), amount);
        
        // Redeem through router
        vm.prank(rebalancer);
        router.redeem(address(node), address(vault), amount);
        
        // Verify redemption
        assertEq(vault.balanceOf(address(node)), 0);
        assertEq(asset.balanceOf(address(node)), amount);
    }

    function test_revertIf_NotRebalancer() public {
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        vm.prank(randomUser);
        router.deposit(address(node), address(vault), 100 ether);
        
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        vm.prank(randomUser);
        router.mint(address(node), address(vault), 100 ether);
        
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        vm.prank(randomUser);
        router.withdraw(address(node), address(vault), 100 ether);
        
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        vm.prank(randomUser);
        router.redeem(address(node), address(vault), 100 ether);
    }

    function test_revertIf_NotWhitelisted() public {
        address nonWhitelistedVault = address(new ERC4626Mock(address(asset)));
        
        vm.startPrank(rebalancer);
        
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        router.deposit(address(node), nonWhitelistedVault, 100 ether);
        
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        router.mint(address(node), nonWhitelistedVault, 100 ether);
        
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        router.withdraw(address(node), nonWhitelistedVault, 100 ether);
        
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        router.redeem(address(node), nonWhitelistedVault, 100 ether);
        
        vm.stopPrank();
    }
}
