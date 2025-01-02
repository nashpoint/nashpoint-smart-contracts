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

contract RebalanceFuzzTests is BaseTest {
    uint256 public maxDeposit;

    ERC4626Mock public vaultA;
    ERC4626Mock public vaultB;
    ERC4626Mock public vaultC;
    ERC7540Mock public asyncVaultA;
    ERC7540Mock public asyncVaultB;
    ERC7540Mock public asyncVaultC;
    address[] public components;

    function setUp() public override {
        super.setUp();
        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.MAX_DEPOSIT();

        vaultA = new ERC4626Mock(address(asset));
        vaultB = new ERC4626Mock(address(asset));
        vaultC = new ERC4626Mock(address(asset));
        asyncVaultA = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);
        asyncVaultB = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);
        asyncVaultC = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.removeComponent(address(vault));
        node.updateReserveAllocation(ComponentAllocation({targetWeight: 0 ether, maxDelta: 0 ether}));
        quoter.setErc4626(address(vaultA), true);
        router4626.setWhitelistStatus(address(vaultA), true);
        quoter.setErc4626(address(vaultB), true);
        router4626.setWhitelistStatus(address(vaultB), true);
        quoter.setErc4626(address(vaultC), true);
        router4626.setWhitelistStatus(address(vaultC), true);
        quoter.setErc7540(address(asyncVaultA), true);
        router7540.setWhitelistStatus(address(asyncVaultA), true);
        quoter.setErc7540(address(asyncVaultB), true);
        router7540.setWhitelistStatus(address(asyncVaultB), true);
        quoter.setErc7540(address(asyncVaultC), true);
        router7540.setWhitelistStatus(address(asyncVaultC), true);
        vm.stopPrank();

        components = [
            address(vaultA),
            address(vaultB),
            address(vaultC),
            address(asyncVaultA),
            address(asyncVaultB),
            address(asyncVaultC)
        ];
    }

    //invariant: totalAssets should equal seedAmount
    function test_fuzz_rebalance_basic(uint256 targetReserveRatio, uint256 seedAmount, uint256 randomNum) public {
        targetReserveRatio = bound(targetReserveRatio, 0, 1 ether);
        seedAmount = bound(seedAmount, 1, maxDeposit);

        _seedNode(seedAmount);
        _setRandomComponentRatios(targetReserveRatio, randomNum);
        _tryRebalance();

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.totalAssets(), seedAmount, "Total assets should equal initial deposit");
    }

    function test_fuzz_rebalance_with_deposits(
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 randomNum,
        uint256 runs,
        uint256 depositAmount
    ) public {
        targetReserveRatio = bound(targetReserveRatio, 0, 1 ether);

        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setRandomComponentRatios(targetReserveRatio, randomNum);
        _tryRebalance();

        deal(address(asset), address(user), type(uint256).max);
        uint256 depositAssets = 0;

        runs = bound(runs, 1, 100);
        for (uint256 i = 0; i < runs; i++) {
            vm.warp(block.timestamp + 1 days);
            depositAmount = bound(depositAmount, 1 ether, maxDeposit);
            _userDeposits(user, depositAmount);
            _tryRebalance();
            depositAssets += depositAmount;
        }

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.totalAssets(), seedAmount + depositAssets, "Total assets should equal initial deposit + deposit");
    }

    function test_fuzz_rebalance_with_deposits_no_rebalance(
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 randomNum,
        uint256 runs,
        uint256 depositAmount
    ) public {
        targetReserveRatio = bound(targetReserveRatio, 0, 1 ether);

        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setRandomComponentRatios(targetReserveRatio, randomNum);
        _tryRebalance();

        deal(address(asset), address(user), type(uint256).max);
        uint256 depositAssets = 0;

        runs = bound(runs, 1, 100);
        for (uint256 i = 0; i < runs; i++) {
            depositAmount = bound(depositAmount, 1 ether, maxDeposit);
            _userDeposits(user, depositAmount);
            depositAssets += depositAmount;
        }

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.totalAssets(), seedAmount + depositAssets, "Total assets should equal initial deposit + deposit");
    }

    function _setRandomComponentRatios(uint256 reserveRatio, uint256 randomNum) internal {
        vm.startPrank(owner);
        node.updateReserveAllocation(ComponentAllocation({targetWeight: reserveRatio, maxDelta: 0 ether}));

        uint256 availableAllocation = 1 ether - reserveRatio;
        for (uint256 i = 0; i < components.length; i++) {
            if (i == components.length - 1) {
                if (availableAllocation > 0) {
                    node.addComponent(
                        components[i], ComponentAllocation({targetWeight: availableAllocation, maxDelta: 0})
                    );
                }
            } else {
                uint256 chunk = uint256(keccak256(abi.encodePacked(randomNum, i)));
                chunk = bound(chunk, 0, availableAllocation);
                node.addComponent(components[i], ComponentAllocation({targetWeight: chunk, maxDelta: 0}));
                availableAllocation -= chunk;
            }
        }
        vm.stopPrank();
    }

    function _tryRebalance() internal {
        vm.startPrank(rebalancer);
        node.startRebalance();
        for (uint256 i = 0; i < components.length; i++) {
            try router4626.invest(address(node), address(components[i])) {} catch {}
            try router7540.investInAsyncVault(address(node), address(components[i])) {} catch {}
        }
        vm.stopPrank();
    }
}
