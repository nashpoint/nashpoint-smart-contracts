// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract RebalancingTests is BaseTest {
    ERC4626Mock public vaultA;
    ERC4626Mock public vaultB;
    ERC4626Mock public vaultC;
    ERC7540Mock public asyncVault;

    function setUp() public override {
        super.setUp();

        vaultA = new ERC4626Mock(address(asset));
        vaultB = new ERC4626Mock(address(asset));
        vaultC = new ERC4626Mock(address(asset));
        asyncVault = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);

        node.removeComponent(address(vault));
        node.updateReserveAllocation(ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0 ether}));

        quoter.setErc4626(address(vaultA), true);
        router4626.setWhitelistStatus(address(vaultA), true);
        node.addComponent(address(vaultA), ComponentAllocation({targetWeight: 0.18 ether, maxDelta: 0.01 ether}));

        quoter.setErc4626(address(vaultB), true);
        router4626.setWhitelistStatus(address(vaultB), true);
        node.addComponent(address(vaultB), ComponentAllocation({targetWeight: 0.2 ether, maxDelta: 0.01 ether}));

        quoter.setErc4626(address(vaultC), true);
        router4626.setWhitelistStatus(address(vaultC), true);
        node.addComponent(address(vaultC), ComponentAllocation({targetWeight: 0.22 ether, maxDelta: 0.01 ether}));

        quoter.setErc7540(address(asyncVault), true);
        router7540.setWhitelistStatus(address(asyncVault), true);
        node.addComponent(address(asyncVault), ComponentAllocation({targetWeight: 0.3 ether, maxDelta: 0.03 ether}));

        vm.stopPrank();
    }

    function testRebalance() public {
        uint256 seedAmount = 1 ether;

        _seedNode(seedAmount);

        vm.startPrank(rebalancer);
        node.startRebalance();

        router4626.invest(address(node), address(vaultA));
        router4626.invest(address(node), address(vaultB));
        router4626.invest(address(node), address(vaultC));
        router7540.investInAsyncVault(address(node), address(asyncVault));
        vm.stopPrank();

        uint256 totalAssets = node.totalAssets();
        uint256 vaultAHoldings = vaultA.balanceOf(address(node));
        uint256 vaultBHoldings = vaultB.balanceOf(address(node));
        uint256 vaultCHoldings = vaultC.balanceOf(address(node));
        uint256 asyncVaultHoldings = asyncVault.pendingDepositRequest(0, address(node));

        // assert that the protocol was rebalanced to the correct ratios
        assertEq(totalAssets, seedAmount, "Total assets should equal initial deposit");
        assertEq(vaultAHoldings, 0.18 ether, "Vault A should hold 18% of total");
        assertEq(vaultBHoldings, 0.2 ether, "Vault B should hold 20% of total");
        assertEq(vaultCHoldings, 0.22 ether, "Vault C should hold 22% of total");
        assertEq(asyncVaultHoldings, 0.3 ether, "Async assets should be 30% of total");
    }
}
