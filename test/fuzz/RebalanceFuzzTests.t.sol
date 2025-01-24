// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract RebalanceFuzzTests is BaseTest {
    uint256 public constant WAD = 1e18;
    uint256 public maxDeposit;

    ERC4626Mock public vaultA;
    ERC4626Mock public vaultB;
    ERC4626Mock public vaultC;
    ERC7540Mock public asyncVaultA;
    ERC7540Mock public asyncVaultB;
    ERC7540Mock public asyncVaultC;
    address[] public components;
    address[] public synchronousComponents;
    address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
    address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

    function setUp() public override {
        super.setUp();
        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.maxDepositSize();

        vaultA = new ERC4626Mock(address(asset));
        vaultB = new ERC4626Mock(address(asset));
        vaultC = new ERC4626Mock(address(asset));
        asyncVaultA = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);
        asyncVaultB = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);
        asyncVaultC = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);

        vm.label(address(vaultA), "VaultA");
        vm.label(address(vaultB), "VaultB");
        vm.label(address(vaultC), "VaultC");
        vm.label(address(asyncVaultA), "AsyncVaultA");
        vm.label(address(asyncVaultB), "AsyncVaultB");
        vm.label(address(asyncVaultC), "AsyncVaultC");

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

        synchronousComponents = [address(vaultA), address(vaultB), address(vaultC)];
    }

    function test_fuzz_rebalance_basic(uint64 targetReserveRatio, uint256 seedAmount, uint64 randUint) public {
        targetReserveRatio = uint64(bound(uint256(targetReserveRatio), 0, 1 ether));
        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint, components);
        _tryRebalance();

        vm.prank(rebalancer);
        node.updateTotalAssets();
    }

    function test_fuzz_rebalance_with_deposits(
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint64 randUint,
        uint8 runs,
        uint256 depositAmount
    ) public {
        targetReserveRatio = uint64(bound(uint256(targetReserveRatio), 0, 1 ether));

        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint, components);
        _tryRebalance();

        deal(address(asset), address(user), type(uint256).max);
        uint256 depositAssets = 0;

        runs = uint8(bound(uint256(runs), 1, 100));
        for (uint256 i = 0; i < runs; i++) {
            vm.warp(block.timestamp + 1 days);
            uint256 depositThisRun = uint256(keccak256(abi.encodePacked(randUint, i, depositAmount)));
            depositThisRun = bound(depositThisRun, 1 ether, maxDeposit);
            _userDeposits(user, depositThisRun);
            _tryRebalance();
            depositAssets += depositThisRun;
        }

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.totalAssets(), seedAmount + depositAssets, "Total assets should equal initial deposit + deposit");
    }

    function test_fuzz_rebalance_with_deposits_no_rebalance(
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint64 randUint,
        uint8 runs,
        uint256 depositAmount
    ) public {
        targetReserveRatio = uint64(bound(uint256(targetReserveRatio), 0, 1 ether));

        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint, components);
        _tryRebalance();

        deal(address(asset), address(user), type(uint256).max);
        uint256 depositAssets = 0;

        runs = uint8(bound(uint256(runs), 1, 100));
        for (uint256 i = 0; i < runs; i++) {
            uint256 depositThisRun = uint256(keccak256(abi.encodePacked(randUint, i, depositAmount)));
            depositThisRun = bound(depositThisRun, 1 ether, maxDeposit);
            _userDeposits(user, depositThisRun);
            depositAssets += depositThisRun;
        }

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.totalAssets(), seedAmount + depositAssets, "Total assets should equal initial deposit + deposit");
    }

    function test_fuzz_rebalance_with_withdrawals(
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint64 randUint,
        uint8 runs,
        uint256 withdrawAmount
    ) public {
        targetReserveRatio = uint64(bound(uint256(targetReserveRatio), 0.1 ether, 1 ether));
        seedAmount = 1e36;

        deal(address(asset), address(user), type(uint256).max);
        _userDeposits(user, seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint, components);
        _tryRebalance();

        uint256 withdrawAssets = 0;

        runs = uint8(bound(uint256(runs), 1, 100));
        for (uint256 i = 0; i < runs; i++) {
            uint256 withdrawThisRun = uint256(keccak256(abi.encodePacked(randUint, i, withdrawAmount)));
            withdrawThisRun = bound(withdrawThisRun, 1 ether, 1e30);
            _userRedeemsAndClaims(user, withdrawThisRun, address(node));
            withdrawAssets += withdrawThisRun;
        }

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(
            node.totalAssets(),
            seedAmount - withdrawAssets,
            "Total assets should equal initial deposit - withdraw amount"
        );
    }

    // note: all fees are in the range of 0 to 0.1 ether to avoid not having enough reserve to pay fees
    // fee calculations are tested in the full range elsewhere

    function test_fuzz_rebalance_with_fees(
        uint64 annualManagementFee,
        uint64 protocolManagementFee,
        uint64 protocolExecutionFee,
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint256 randUint,
        uint256 runs,
        uint256 depositAmount
    ) public {
        uint256 minFee = 100;
        targetReserveRatio = uint64(bound(uint256(targetReserveRatio), 0.1 ether, 1 ether));
        seedAmount = bound(seedAmount, 1 ether, maxDeposit);
        annualManagementFee = uint64(bound(annualManagementFee, 0, 0.1 ether));
        protocolManagementFee = uint64(bound(protocolManagementFee, minFee, 0.1 ether));
        protocolExecutionFee = uint64(bound(protocolExecutionFee, minFee, 0.1 ether));

        _setFees(annualManagementFee, protocolManagementFee, protocolExecutionFee);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint, components);
        _tryRebalance();

        deal(address(asset), address(user), type(uint256).max);
        uint256 depositAssets = 0;

        runs = bound(runs, 1, 100);
        for (uint256 i = 0; i < runs; i++) {
            vm.warp(block.timestamp + 1 days);

            vm.prank(rebalancer);
            node.payManagementFees();
            _tryRebalance();

            uint256 depositThisRun = uint256(keccak256(abi.encodePacked(randUint, i, depositAmount)));
            depositThisRun = bound(depositThisRun, 1, maxDeposit);
            _userDeposits(user, depositThisRun);
            depositAssets += depositThisRun;
        }

        uint256 totalDeposits = seedAmount + depositAssets;
        uint256 finalBalances =
            asset.balanceOf(ownerFeesRecipient) + asset.balanceOf(protocolFeesRecipient) + node.totalAssets();

        assertEq(totalDeposits, finalBalances, "Total deposits should equal final balances");
        if (annualManagementFee > minFee) {
            assertGt(asset.balanceOf(ownerFeesRecipient), 0, "Owner fees recipient should have some balance");
            if (protocolManagementFee > minFee) {
                assertGt(asset.balanceOf(protocolFeesRecipient), 0, "Protocol fees recipient should have some balance");
            }
        }
    }

    function test_fuzz_rebalance_with_interest_earned_on_components(
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint256 randUint,
        uint8 runs,
        uint256 maxInterest
    ) public {
        targetReserveRatio = uint64(bound(uint256(targetReserveRatio), 0.01 ether, 0.1 ether));
        seedAmount = bound(seedAmount, 1 ether, 1e36);
        randUint = bound(randUint, 0, 1 ether);
        runs = uint8(bound(uint256(runs), 10, 100));
        maxInterest = bound(maxInterest, 0.1 ether, 1e36);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint, components);
        _tryRebalance();
        _mock7540_processPendingDeposits();
        _mintClaimableShares();

        vm.prank(rebalancer);
        node.updateTotalAssets();

        uint256 interestEarned = 0;
        for (uint256 i = 0; i < runs; i++) {
            _earnComponentInterest(maxInterest, randUint);
            interestEarned += maxInterest;
        }

        vm.prank(rebalancer);
        node.updateTotalAssets();

        assertApproxEqRel(
            node.totalAssets(),
            seedAmount + interestEarned,
            1e12,
            "Total assets should equal initial deposit + interest"
        );
    }

    function test_fuzz_fulfilRedeemRequest(uint256 seedAmount, uint64 randUint) public {
        components = [address(vaultA)];
        seedAmount = bound(seedAmount, 1 ether, 1e36);
        randUint = uint64(bound(uint256(randUint), 0, 1 ether));

        vm.warp(block.timestamp + 1 days);
        deal(address(asset), address(user), seedAmount);

        vm.startPrank(owner);
        node.addComponent(address(vaultA), ComponentAllocation({targetWeight: 1 ether, maxDelta: 0}));
        node.setLiquidationQueue(components);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance(); // note: this is done to update cache or deposits will fail

        _userDeposits(user, seedAmount);
        _tryRebalance();

        vm.prank(rebalancer);
        node.updateTotalAssets();

        while (node.balanceOf(user) > 0) {
            uint256 sharesToRedeem = uint256(keccak256(abi.encodePacked(randUint++, seedAmount)));
            sharesToRedeem = bound(sharesToRedeem, 1, seedAmount);
            if (sharesToRedeem > node.balanceOf(user)) {
                sharesToRedeem = node.balanceOf(user);
            }

            _userRequestsRedeem(user, sharesToRedeem);

            vm.startPrank(rebalancer);
            router4626.fulfillRedeemRequest(address(node), user, address(vaultA));
            vm.stopPrank();
        }
        if (node.totalAssets() < 10) {
            _verifyNodeFullyRedeemed_absolute(10);
        } else {
            _verifyNodeFullyRedeemed_relative(1e12);
        }
    }

    function test_fuzz_rebalance_liquidation_queue(uint256 seedAmount, uint64 targetReserveRatio, uint64 randUint)
        public
    {
        seedAmount = bound(seedAmount, 1 ether, 1e36); // todo: check if range is appropriate
        targetReserveRatio = uint64(bound(uint256(targetReserveRatio), 0.01 ether, 0.99 ether));
        randUint = uint64(bound(uint256(randUint), 0, 1 ether));

        _setInitialComponentRatios(targetReserveRatio, randUint, synchronousComponents);
        deal(address(asset), address(user), seedAmount);
        _userDeposits(user, seedAmount);
        _tryRebalance();

        vm.startPrank(owner);
        node.setLiquidationQueue(synchronousComponents);
        vm.stopPrank();

        // redeem the entire reserve
        uint256 sharesToRedeem = node.convertToShares(asset.balanceOf(address(node)));
        _userRedeemsAndClaims(user, sharesToRedeem, address(node));
        assertEq(asset.balanceOf(address(node)), 0, "Node should have no assets");

        while (node.balanceOf(user) > 0) {
            sharesToRedeem = uint256(keccak256(abi.encodePacked(randUint++, seedAmount)));
            sharesToRedeem = bound(sharesToRedeem, 1, seedAmount);
            if (sharesToRedeem > node.balanceOf(user)) {
                sharesToRedeem = node.balanceOf(user);
            }
            _userRequestsRedeem(user, sharesToRedeem);

            vm.startPrank(rebalancer);
            for (uint256 i = 0; i < synchronousComponents.length; i++) {
                try router4626.fulfillRedeemRequest(address(node), user, synchronousComponents[i]) {} catch {}
            }
            vm.stopPrank();

            uint256 claimableAssets = node.maxWithdraw(user);
            if (claimableAssets > 0) {
                vm.prank(user);
                node.withdraw(claimableAssets, user, user);
            } else {
                break;
            }
        }
        if (node.totalAssets() < 10) {
            _verifyNodeFullyRedeemed_absolute(10);
        } else {
            _verifyNodeFullyRedeemed_relative(1e12);
        }
    }

    // todo: test changing component ratios and rebalancing towards the new ratios

    // HELPER FUNCTIONS

    function _setInitialComponentRatios(uint64 reserveRatio, uint256 randUint, address[] memory newComponents)
        internal
    {
        vm.startPrank(owner);
        node.updateReserveAllocation(ComponentAllocation({targetWeight: reserveRatio, maxDelta: 0 ether}));
        components = newComponents;

        uint64 availableAllocation = 1 ether - reserveRatio;
        for (uint256 i = 0; i < components.length; i++) {
            if (i == components.length - 1) {
                if (availableAllocation > 0) {
                    node.addComponent(
                        components[i], ComponentAllocation({targetWeight: availableAllocation, maxDelta: 0})
                    );
                }
            } else {
                uint256 hashVal = uint256(keccak256(abi.encodePacked(randUint, i)));
                uint256 bounded = bound(hashVal, 0, availableAllocation);
                uint64 chunk = uint64(bounded);

                // uint64 chunk = uint64(keccak256(abi.encodePacked(randUint, i)));
                // chunk = bound(chunk, 0, availableAllocation);
                node.addComponent(components[i], ComponentAllocation({targetWeight: chunk, maxDelta: 0}));
                availableAllocation -= chunk;
            }
        }
        vm.stopPrank();
    }

    function _tryRebalance() internal {
        vm.startPrank(rebalancer);
        try node.startRebalance() {} catch {}
        for (uint256 i = 0; i < components.length; i++) {
            try router4626.invest(address(node), address(components[i])) {} catch {}
            try router7540.investInAsyncComponent(address(node), address(components[i])) {} catch {}
        }
        vm.stopPrank();
    }

    function _setFees(uint64 annualManagementFee, uint64 protocolManagementFee, uint64 protocolExecutionFee) internal {
        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(annualManagementFee);
        registry.setProtocolManagementFee(protocolManagementFee);
        registry.setProtocolExecutionFee(protocolExecutionFee);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();
    }

    function _earnComponentInterest(uint256 totalInterest, uint256 randUint) public {
        uint256 availableInterest = totalInterest;
        for (uint256 i = 0; i < components.length; i++) {
            if (i == components.length - 1) {
                if (availableInterest > 0) {
                    uint256 existingBalance = asset.balanceOf(address(components[i]));
                    deal(address(asset), address(components[i]), existingBalance + availableInterest);
                }
            } else {
                uint256 chunk = uint256(keccak256(abi.encodePacked(randUint++, i)));
                chunk = bound(chunk, 0, availableInterest);
                uint256 existingBalance = asset.balanceOf(address(components[i]));
                deal(address(asset), address(components[i]), existingBalance + chunk);

                availableInterest -= chunk;
            }
        }
    }

    function _mock7540_processPendingDeposits() internal {
        for (uint256 i = 0; i < components.length; i++) {
            address component = components[i];
            vm.startPrank(address(testPoolManager));
            try ERC7540Mock(component).processPendingDeposits() {} catch {}
            vm.stopPrank();
        }
    }

    function _mintClaimableShares() internal {
        vm.startPrank(rebalancer);
        for (uint256 i = 0; i < components.length; i++) {
            try router7540.mintClaimableShares(address(node), address(components[i])) {} catch {}
        }
        vm.stopPrank();
    }

    function _verifyNodeFullyRedeemed_absolute(uint256 tolerance) internal view {
        assertApproxEqAbs(node.balanceOf(user), 0, tolerance, "User should have no balance");
        assertApproxEqAbs(node.totalAssets(), 0, tolerance, "Node should have no assets");
        assertApproxEqAbs(node.totalSupply(), 0, tolerance, "Node should have no supply");
        assertApproxEqAbs(asset.balanceOf(address(node)), 0, tolerance, "Node should have no assets");

        assertApproxEqAbs(asset.balanceOf(address(vaultA)), 0, tolerance, "VaultA should have no assets");
        assertApproxEqAbs(asset.balanceOf(address(vaultB)), 0, tolerance, "VaultB should have no assets");
        assertApproxEqAbs(asset.balanceOf(address(vaultC)), 0, tolerance, "VaultC should have no assets");
    }

    function _verifyNodeFullyRedeemed_relative(uint256 tolerance) internal view {
        assertApproxEqRel(node.balanceOf(user), 0, tolerance, "User should have no balance");
        assertApproxEqRel(node.totalAssets(), 0, tolerance, "Node should have no assets");
        assertApproxEqRel(node.totalSupply(), 0, tolerance, "Node should have no supply");
        assertApproxEqRel(asset.balanceOf(address(node)), 0, tolerance, "Node should have no assets");

        assertApproxEqRel(asset.balanceOf(address(vaultA)), 0, tolerance, "VaultA should have no assets");
        assertApproxEqRel(asset.balanceOf(address(vaultB)), 0, tolerance, "VaultB should have no assets");
        assertApproxEqRel(asset.balanceOf(address(vaultC)), 0, tolerance, "VaultC should have no assets");
    }
}
