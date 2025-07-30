// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

abstract contract ERC4626BaseTest is BaseTest {
    uint256 arbitrumFork;
    uint256 blockNumber = 362881136;
    IERC4626 erc4626Vault;

    IERC20Metadata public usdc = IERC20Metadata(usdcArbitrum);

    // overwrite to setup the testing of arbitrary ERC4626 component
    function _setupErc4626Test() internal virtual {}

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL, blockNumber);
        vm.selectFork(arbitrumFork);
        super.setUp();
        _setupErc4626Test();

        // warp forward to ensure not rebalancing
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        // remove mock ERC4626 vault
        node.removeComponent(address(vault), false);
        vm.stopPrank();

        vm.startPrank(owner);
        // whitelist and add aave erc4626Vault with 90% allocation
        router4626.setWhitelistStatus(address(erc4626Vault), true);
        node.addComponent(address(erc4626Vault), 0.9 ether, 0.01 ether, address(router4626));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();
    }

    // we work with right underlying
    function test_usdcAddress() public view {
        string memory name = usdc.name();
        uint256 totalSupply = usdc.totalSupply();
        assertEq(name, "USD Coin");
        assertEq(totalSupply, 6790309512297089);
        assertEq(usdc.decimals(), 6);
    }

    function test_nodeInvestLiquidate() public {
        // user deposits into node
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        uint256 userShares = node.balanceOf(address(user));
        // shares minted to user
        assertEq(node.convertToAssets(userShares), 100e6);
        // usdc is the node
        assertEq(usdc.balanceOf(address(node)), 100e6);
        // node has no position in erc4626Vault yet
        assertEq(erc4626Vault.balanceOf(address(node)), 0);

        // rebalancer invests funds into erc4626Vault via ERC4626 router
        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(erc4626Vault), 0);
        vm.stopPrank();

        uint256 nodeShares = erc4626Vault.balanceOf(address(node));

        // 90% goes to erc4626Vault
        assertApproxEqAbs(erc4626Vault.convertToAssets(nodeShares), 90e6, 1);
        // 10% remains as reserve
        assertEq(usdc.balanceOf(address(node)), 10e6);
        // but totalAssets still equal to what user has deposited
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        // withdraw all funds from erc4626Vault
        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(erc4626Vault), erc4626Vault.balanceOf(address(node)), 0);
        vm.stopPrank();

        // no assets left in erc4626Vault
        assertEq(erc4626Vault.balanceOf(address(node)), 0);
        // we got everything back to node
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }

    function test_erc4626Vault_interest() public {
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(erc4626Vault), 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 16 weeks);

        uint256 userShares = node.balanceOf(address(user));

        // interest has been accrued but it is not reflected in Node accounting yet
        assertEq(node.convertToAssets(userShares), 100e6);
        assertEq(node.totalAssets(), 100e6);

        // do rebalance to update internal accounting
        vm.startPrank(rebalancer);
        node.startRebalance();
        vm.stopPrank();

        uint256 nodeTotalAssets = node.totalAssets();

        // we should see interest accrued
        assertGt(node.convertToAssets(userShares), 100e6);
        assertGt(nodeTotalAssets, 100e6);
        assertApproxEqAbs(nodeTotalAssets, node.convertToAssets(userShares), 1);
    }

    function test_erc4626Vault_deposit_interest_withdraw() public {
        uint256 depositAmount = 100e6;
        uint256 userBalanceInitial = usdc.balanceOf(user);

        vm.startPrank(user);
        usdc.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        vm.stopPrank();
        // second deposit from another user will guarantee we can withdraw everything for user1 from erc4626Vault
        vm.startPrank(user2);
        usdc.approve(address(node), depositAmount);
        node.deposit(depositAmount, user2);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(erc4626Vault), 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 16 weeks);

        // user make a redeem request
        vm.startPrank(user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        // open new rebalancing window
        vm.startPrank(rebalancer);
        node.startRebalance();
        vm.stopPrank();

        // the redeem request if fulfilled
        vm.startPrank(rebalancer);
        uint256 minAssetsOut = node.convertToAssets(shares);
        uint256 assetsRedeemed =
            router4626.fulfillRedeemRequest(address(node), user, address(erc4626Vault), minAssetsOut);
        vm.stopPrank();

        // now user can withdraw funds
        vm.startPrank(user);
        uint256 assetsWithdrawn = node.redeem(shares, user, user);
        vm.stopPrank();

        // user get what was fulfilled
        assertEq(assetsRedeemed, assetsWithdrawn);

        uint256 userBalanceFinal = usdc.balanceOf(user);
        // user got some interest
        assertGt(userBalanceFinal, userBalanceInitial);
        // usdc balance has changed correctly
        assertEq(userBalanceFinal - userBalanceInitial, assetsWithdrawn - depositAmount);
    }

    // fuzz test to check that variable sized deposit leads to predictable accounting using erc4626Vault component
    function testFuzz_erc4626Vault_nodeInvestLiquidate(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000e6);
        vm.startPrank(user);
        usdc.approve(address(node), amount);
        node.deposit(amount, user);
        vm.stopPrank();

        uint256 userShares = node.balanceOf(address(user));

        assertEq(node.convertToAssets(userShares), amount);
        assertEq(usdc.balanceOf(address(node)), amount);
        assertEq(erc4626Vault.balanceOf(address(node)), 0);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(erc4626Vault), 0);
        vm.stopPrank();

        uint256 nodeShares = erc4626Vault.balanceOf(address(node));

        uint256 allocation = 90 * amount / 100;

        assertApproxEqAbs(erc4626Vault.convertToAssets(nodeShares), allocation, 1);
        assertEq(usdc.balanceOf(address(node)), amount - allocation);
        assertApproxEqAbs(node.totalAssets(), amount, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(erc4626Vault), erc4626Vault.balanceOf(address(node)), 0);
        vm.stopPrank();

        assertEq(erc4626Vault.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), amount, 1);
    }
}
