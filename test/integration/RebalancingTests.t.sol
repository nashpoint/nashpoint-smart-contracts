// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.26;

// import {BaseTest} from "../BaseTest.sol";
// import {console2} from "forge-std/Test.sol";
// import {Node} from "src/Node.sol";
// import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
// import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
// import {EventsLib} from "src/libraries/EventsLib.sol";
// import {NodeRegistry} from "src/NodeRegistry.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
// import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

// contract RebalancingTests is BaseTest {
//     ERC4626Mock public vaultA;
//     ERC4626Mock public vaultB;
//     ERC4626Mock public vaultC;
//     ERC7540Mock public asyncVault;

//     function setUp() public override {
//         super.setUp();

//         vaultA = new ERC4626Mock(address(asset));
//         vaultB = new ERC4626Mock(address(asset));
//         vaultC = new ERC4626Mock(address(asset));
//         asyncVault = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);
//         vm.warp(block.timestamp + 1 days);

//         vm.startPrank(owner);

//         node.removeComponent(address(vault));
//         node.updateReserveAllocation(ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0 ether}));

//         quoter.setErc4626(address(vaultA), true);
//         router4626.setWhitelistStatus(address(vaultA), true);
//         node.addComponent(address(vaultA), ComponentAllocation({targetWeight: 0.18 ether, maxDelta: 0.01 ether}));

//         quoter.setErc4626(address(vaultB), true);
//         router4626.setWhitelistStatus(address(vaultB), true);
//         node.addComponent(address(vaultB), ComponentAllocation({targetWeight: 0.2 ether, maxDelta: 0.01 ether}));

//         quoter.setErc4626(address(vaultC), true);
//         router4626.setWhitelistStatus(address(vaultC), true);
//         node.addComponent(address(vaultC), ComponentAllocation({targetWeight: 0.22 ether, maxDelta: 0.01 ether}));

//         quoter.setErc7540(address(asyncVault), true);
//         router7540.setWhitelistStatus(address(asyncVault), true);
//         node.addComponent(address(asyncVault), ComponentAllocation({targetWeight: 0.3 ether, maxDelta: 0.03 ether}));

//         vm.stopPrank();
//     }

//     function testRebalance() public {
//         uint256 seedAmount = 100 ether;

//         _seedNode(seedAmount);

//         vm.startPrank(rebalancer);
//         node.startRebalance();
//         router4626.invest(address(node), address(vaultA));
//         router4626.invest(address(node), address(vaultB));
//         router4626.invest(address(node), address(vaultC));
//         router7540.investInAsyncVault(address(node), address(asyncVault));
//         vm.stopPrank();

//         uint256 totalAssets = node.totalAssets();
//         uint256 vaultAHoldings = vaultA.balanceOf(address(node));
//         uint256 vaultBHoldings = vaultB.balanceOf(address(node));
//         uint256 vaultCHoldings = vaultC.balanceOf(address(node));
//         uint256 asyncVaultHoldings = asyncVault.pendingDepositRequest(0, address(node));

//         // assert that the protocol was rebalanced to the correct ratios
//         assertEq(totalAssets, seedAmount, "Total assets should equal initial deposit");
//         assertEq(vaultAHoldings, 18 ether, "Vault A should hold 18% of total");
//         assertEq(vaultBHoldings, 20 ether, "Vault B should hold 20% of total");
//         assertEq(vaultCHoldings, 22 ether, "Vault C should hold 22% of total");
//         assertEq(asyncVaultHoldings, 30 ether, "Async assets should be 30% of total");

//         // FIRST DEPOSIT: rebalancer cannot rebalance into asyncVault as lower threshold not breached
//         _userDeposits(address(user), 10 ether);

//         vm.startPrank(rebalancer);
//         router4626.invest(address(node), address(vaultA));
//         router4626.invest(address(node), address(vaultB));
//         router4626.invest(address(node), address(vaultC));

//         vm.expectRevert();
//         router7540.investInAsyncVault(address(node), address(asyncVault));
//         vm.stopPrank();

//         totalAssets = node.totalAssets();
//         vaultAHoldings = vaultA.balanceOf(address(node));
//         vaultBHoldings = vaultB.balanceOf(address(node));
//         vaultCHoldings = vaultC.balanceOf(address(node));
//         asyncVaultHoldings = asyncVault.pendingDepositRequest(0, address(node));

//         // assert the liquid assets are all in the correct proportions
//         assertEq(vaultAHoldings * 1 ether / totalAssets, 0.18 ether, "Vault A ratio incorrect");
//         assertEq(vaultBHoldings * 1 ether / totalAssets, 0.2 ether, "Vault B ratio incorrect");
//         assertEq(vaultCHoldings * 1 ether / totalAssets, 0.22 ether, "Vault C ratio incorrect");

//         // assert that cash reserve has not been reduced below target by rebalance
//         uint256 currentReserve = asset.balanceOf(address(node));
//         uint256 targetCash = (node.totalAssets() * node.targetReserveRatio()) / 1e18;
//         assertGt(currentReserve, targetCash, "Current reserve below target");

//         // SECOND DEPOSIT: rebalancer cannot rebalance small deposit into sync vaults as lower thresholds not breached
//         _userDeposits(user, 1 ether);

//         vm.startPrank(rebalancer);
//         vm.expectRevert();
//         router4626.invest(address(node), address(vaultA));
//         vm.expectRevert();
//         router4626.invest(address(node), address(vaultB));
//         vm.expectRevert();
//         router4626.invest(address(node), address(vaultC));
//         vm.expectRevert();
//         router7540.investInAsyncVault(address(node), address(asyncVault));
//         vm.stopPrank();

//         // THIRD DEPOSIT: rebalancer can rebalance deposit into sync & async vaults as lower thresholds breached
//         _userDeposits(user, 9 ether);

//         vm.startPrank(rebalancer);
//         router4626.invest(address(node), address(vaultA));
//         router4626.invest(address(node), address(vaultB));
//         router4626.invest(address(node), address(vaultC));
//         router7540.investInAsyncVault(address(node), address(asyncVault));
//         vm.stopPrank();

//         totalAssets = node.totalAssets();
//         vaultAHoldings = vaultA.balanceOf(address(node));
//         vaultBHoldings = vaultB.balanceOf(address(node));
//         vaultCHoldings = vaultC.balanceOf(address(node));
//         asyncVaultHoldings = asyncVault.pendingDepositRequest(0, address(node));

//         // assert that asyncAssets on liquidityPool == target ratio
//         assertEq(asyncVaultHoldings * 1e18 / totalAssets, 30e16, "Async assets ratio incorrect");

//         // assert the liquid assets are all in the correct proportions
//         assertEq(vaultAHoldings * 1e18 / totalAssets, 18e16, "Vault A ratio incorrect after rebalance");
//         assertEq(vaultBHoldings * 1e18 / totalAssets, 20e16, "Vault B ratio incorrect after rebalance");
//         assertEq(vaultCHoldings * 1e18 / totalAssets, 22e16, "Vault C ratio incorrect after rebalance");

//         // assert that totalAssets = initial value + 3 deposits
//         assertEq(totalAssets, seedAmount + 20 ether, "Total assets incorrect after deposits");
//     }
// }
