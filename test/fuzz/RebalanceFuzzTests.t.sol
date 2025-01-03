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
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
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

    address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
    address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

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
    }

    function test_fuzz_rebalance_basic(uint256 targetReserveRatio, uint256 seedAmount, uint256 randUint) public {
        targetReserveRatio = bound(targetReserveRatio, 0, 1 ether);
        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint);
        _tryRebalance();

        vm.prank(rebalancer);
        node.updateTotalAssets();
    }

    function test_fuzz_rebalance_with_deposits(
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 randUint,
        uint256 runs,
        uint256 depositAmount
    ) public {
        targetReserveRatio = bound(targetReserveRatio, 0, 1 ether);

        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint);
        _tryRebalance();

        deal(address(asset), address(user), type(uint256).max);
        uint256 depositAssets = 0;

        runs = bound(runs, 1, 100);
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
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 randUint,
        uint256 runs,
        uint256 depositAmount
    ) public {
        targetReserveRatio = bound(targetReserveRatio, 0, 1 ether);

        seedAmount = bound(seedAmount, 1 ether, maxDeposit);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint);
        _tryRebalance();

        deal(address(asset), address(user), type(uint256).max);
        uint256 depositAssets = 0;

        runs = bound(runs, 1, 100);
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

    // todo: with withdrawals
    function test_fuzz_rebalance_with_withdrawals(
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 randUint,
        uint256 runs,
        uint256 withdrawAmount
    ) public {
        targetReserveRatio = bound(targetReserveRatio, 0.1 ether, 1 ether);
        seedAmount = 1e36;

        deal(address(asset), address(user), type(uint256).max);
        _userDeposits(user, seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint);
        _tryRebalance();

        uint256 withdrawAssets = 0;

        runs = bound(runs, 1, 100);
        for (uint256 i = 0; i < runs; i++) {
            uint256 withdrawThisRun = uint256(keccak256(abi.encodePacked(randUint, i, withdrawAmount)));
            withdrawThisRun = bound(withdrawThisRun, 1 ether, 1e30);
            _userRedeemsAndClaims(user, withdrawThisRun);
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
        uint256 annualManagementFee,
        uint256 protocolManagementFee,
        uint256 protocolExecutionFee,
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 randUint,
        uint256 runs,
        uint256 depositAmount
    ) public {
        targetReserveRatio = bound(targetReserveRatio, 0.1 ether, 1 ether);
        seedAmount = bound(seedAmount, 1 ether, maxDeposit);
        annualManagementFee = bound(annualManagementFee, 0, 0.1 ether);
        protocolManagementFee = bound(protocolManagementFee, 100, 0.1 ether); // todo: figure out why zero is not working
        protocolExecutionFee = bound(protocolExecutionFee, 100, 0.1 ether); // todo: figure out why zero is not working

        _setFees(annualManagementFee, protocolManagementFee, protocolExecutionFee);

        _seedNode(seedAmount);
        _setInitialComponentRatios(targetReserveRatio, randUint);
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
        if (annualManagementFee > 0) {
            assertGt(asset.balanceOf(ownerFeesRecipient), 0, "Owner fees recipient should have some balance");
            if (protocolManagementFee > 0) {
                assertGt(asset.balanceOf(protocolFeesRecipient), 0, "Protocol fees recipient should have some balance");
            }
        }
    }

    // todo: with interest
    function test_fuzz_rebalance_with_interest()
        // uint256 targetReserveRatio,
        // uint256 seedAmount,
        // uint256 randUint,
        // uint256 runs,
        // uint256 maxInterest
        public
    {
        // targetReserveRatio = bound(targetReserveRatio, 0.01 ether, 0.1 ether);
        // seedAmount = bound(seedAmount, 1 ether, 100 ether);
        // randUint = bound(randUint, 1 ether, 100 ether);
        // runs = bound(runs, 1, 10);
        // maxInterest = bound(maxInterest, 0.1 ether, 1 ether);
        uint256 seedAmount = 100 ether;
        uint256 targetReserveRatio = 0.1 ether;
        uint256 randUint = 1 ether;
        uint256 runs = 1;
        uint256 maxInterest = 0.1 ether;

        _preSeedComponents(100 ether);

        _seedNode(seedAmount);
        console2.log("node.totalAssets()", node.totalAssets());
        _setInitialComponentRatios(targetReserveRatio, randUint);
        _print_component_ratios();
        _tryRebalance();
        console2.log("node.totalAssets() after rebalance", node.totalAssets());
        _mock7540_processPendingDeposits(vaultSeeder);
        console2.log("node.totalAssets() after processPendingDeposits", node.totalAssets());
        vm.prank(rebalancer);
        node.updateTotalAssets();
        console2.log("node.totalAssets() after updateTotalAssets", node.totalAssets());

        console2.log("asset.balanceOf(address(node))", asset.balanceOf(address(node)));
        console2.log("asset.balanceOf(address(vaultA))", asset.balanceOf(address(vaultA)));
        console2.log("asset.balanceOf(address(vaultB))", asset.balanceOf(address(vaultB)));
        console2.log("asset.balanceOf(address(vaultC))", asset.balanceOf(address(vaultC)));
        console2.log("asset.balanceOf(address(asyncVaultA))", asset.balanceOf(address(asyncVaultA)));
        console2.log("asset.balanceOf(address(asyncVaultB))", asset.balanceOf(address(asyncVaultB)));
        console2.log("asset.balanceOf(address(asyncVaultC))", asset.balanceOf(address(asyncVaultC)));

        uint256 interestEarned = 0;
        for (uint256 i = 0; i < runs; i++) {
            _earnComponentInterest(maxInterest, randUint);
            interestEarned += maxInterest;
        }
        console2.log("interestEarned", interestEarned);

        vm.prank(rebalancer);
        node.updateTotalAssets();
        console2.log("node.totalAssets() after updateTotalAssets", node.totalAssets());

        console2.log("asset.balanceOf(address(node))", asset.balanceOf(address(node)));
        console2.log("asset.balanceOf(address(vaultA))", asset.balanceOf(address(vaultA)));
        console2.log("asset.balanceOf(address(vaultB))", asset.balanceOf(address(vaultB)));
        console2.log("asset.balanceOf(address(vaultC))", asset.balanceOf(address(vaultC)));
        console2.log("asset.balanceOf(address(asyncVaultA))", asset.balanceOf(address(asyncVaultA)));
        console2.log("asset.balanceOf(address(asyncVaultB))", asset.balanceOf(address(asyncVaultB)));
        console2.log("asset.balanceOf(address(asyncVaultC))", asset.balanceOf(address(asyncVaultC)));

        assertEq(
            node.totalAssets(), seedAmount + interestEarned, "Total assets should equal initial deposit + interest"
        );
    }

    function test_mock_7540_direct_deposit() public {
        vm.startPrank(user);
        asset.approve(address(asyncVaultA), 1 ether);
        asyncVaultA.requestDeposit(1 ether, user, user);
        vm.stopPrank();

        _mock7540_processPendingDeposits(user);

        assertEq(asyncVaultA.totalAssets(), 1 ether, "Total assets should equal initial deposit");

        uint256 existingBalance = asset.balanceOf(address(asyncVaultA));
        deal(address(asset), address(asyncVaultA), existingBalance + 1 ether);
        assertEq(asyncVaultA.totalAssets(), 2 ether, "Total assets should equal initial deposit");
    }

    function test_mock_ERC4626_direct_deposit() public {
        vm.startPrank(user);
        asset.approve(address(vaultA), 1 ether);
        vaultA.deposit(1 ether, user);
        vm.stopPrank();

        assertEq(vaultA.totalAssets(), 1 ether, "Total assets should equal initial deposit");

        uint256 existingBalance = asset.balanceOf(address(vaultA));
        deal(address(asset), address(vaultA), existingBalance + 1 ether);
        assertEq(vaultA.totalAssets(), 2 ether, "Total assets should equal initial deposit");
    }

    // todo: change component ratios

    // todo: liquidations queue

    function _setInitialComponentRatios(uint256 reserveRatio, uint256 randUint) internal {
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
                uint256 chunk = uint256(keccak256(abi.encodePacked(randUint, i)));
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

    function _setFees(uint256 annualManagementFee, uint256 protocolManagementFee, uint256 protocolExecutionFee)
        internal
    {
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

    function test_preSeedComponents() public {
        uint256 seedAmount = 1 ether;
        _preSeedComponents(seedAmount);

        assertEq(vaultA.totalAssets(), seedAmount, "Total assets should equal initial deposit");
        assertEq(vaultB.totalAssets(), seedAmount, "Total assets should equal initial deposit");
        assertEq(vaultC.totalAssets(), seedAmount, "Total assets should equal initial deposit");
        assertEq(asyncVaultA.totalSupply(), seedAmount, "Total supply should equal initial deposit");
        assertEq(asyncVaultB.totalSupply(), seedAmount, "Total supply should equal initial deposit");
        assertEq(asyncVaultC.totalSupply(), seedAmount, "Total supply should equal initial deposit");
    }

    function _preSeedComponents(uint256 seedAmount) public {
        deal(address(asset), address(vaultSeeder), type(uint256).max);

        _seedERC4626(address(vaultA), seedAmount);
        _seedERC4626(address(vaultB), seedAmount);
        _seedERC4626(address(vaultC), seedAmount);
        _seedERC7540(address(asyncVaultA), seedAmount);
        _seedERC7540(address(asyncVaultB), seedAmount);
        _seedERC7540(address(asyncVaultC), seedAmount);

        _mock7540_processPendingDeposits(vaultSeeder);
    }

    function _mock7540_processPendingDeposits(address user_) internal {
        for (uint256 i = 0; i < components.length; i++) {
            address component = components[i];
            vm.startPrank(address(testPoolManager));
            try ERC7540Mock(component).processPendingDeposits() {} catch {}
            vm.stopPrank();

            vm.startPrank(user_);
            try ERC7540Mock(component).maxMint(user_) returns (uint256 shares) {
                try ERC7540Mock(component).mint(shares, user_, user_) {} catch {}
            } catch {}
            vm.stopPrank();
        }
    }

    function _print_component_ratios() internal view {
        uint256 total = 0;
        console2.log("Component ratios:");
        console2.log("targetReserveRatio", node.targetReserveRatio());
        for (uint256 i = 0; i < components.length; i++) {
            console2.log("Component", components[i], "ratio:", node.getComponentRatio(components[i]));
            total += node.getComponentRatio(components[i]);
        }
        console2.log("total", total + node.targetReserveRatio());
    }
}
