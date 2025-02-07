// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {INodeFactory, DeployParams} from "src/interfaces/INodeFactory.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";
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
        DeployParams memory params = DeployParams({
            name: "Decimal Node ",
            symbol: "DNODE",
            asset: address(testToken6),
            owner: owner,
            rebalancer: address(rebalancer),
            quoter: address(quoter),
            routers: _toArrayTwo(address(router4626), address(router7540)),
            components: _toArray(address(testVault6)),
            componentAllocations: _defaultComponentAllocations(1),
            targetReserveRatio: 0.1 ether,
            salt: SALT
        });

        (decNode, decEscrow) = factory.deployFullNode(params);
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

        assertEq(
            testVault6.balanceOf(address(decNode)), MathLib.mulDiv(deposit, componentAllocation.targetWeight, 1e18)
        );
        assertEq(testToken6.balanceOf(address(testVault6)), testVault6.balanceOf(address(decNode)));

        assertEq(decNode.balanceOf(address(user)), deposit);
    }

    function test_fuzz_node_swing_price_deposit_never_exceeds_max_6decimals(
        uint64 maxSwingFactor,
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint256 depositAmount
    ) public {
        maxSwingFactor = uint64(bound(maxSwingFactor, 0.01 ether, 0.99 ether));
        targetReserveRatio = uint64(bound(targetReserveRatio, 0.01 ether, 0.99 ether));
        seedAmount = bound(seedAmount, 1 ether, maxDeposit);
        depositAmount = bound(depositAmount, 1 ether, maxDeposit);

        deal(address(testToken6), address(user), type(uint256).max);

        vm.startPrank(user);
        testToken6.approve(address(decNode), seedAmount);
        decNode.deposit(seedAmount, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        decNode.enableSwingPricing(true, maxSwingFactor);
        decNode.updateTargetReserveRatio(targetReserveRatio);
        decNode.updateComponentAllocation(address(testVault6), 1 ether - targetReserveRatio, 0, address(router4626));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        decNode.startRebalance();
        uint256 investmentAmount = router4626.invest(address(decNode), address(testVault6), 0);
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        uint256 sharesToRedeem = decNode.convertToShares(currentReserve) / 10 + 1;

        vm.startPrank(user);
        decNode.approve(address(decNode), sharesToRedeem);
        decNode.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        decNode.fulfillRedeemFromReserve(user);
        vm.stopPrank();

        uint256 claimableAssets = decNode.maxWithdraw(user);

        vm.prank(user);
        decNode.withdraw(claimableAssets, user, user);

        // invariant 2: shares created always greater than convertToShares when reserve below target
        uint256 nonAdjustedShares = decNode.convertToShares(depositAmount);
        uint256 expectedShares = decNode.previewDeposit(depositAmount);
        assertGt(expectedShares, nonAdjustedShares);

        // invariant 3: deposit bonus never exceeds the value of the max swing factor
        uint256 depositBonus = expectedShares - nonAdjustedShares;
        uint256 maxBonus = depositAmount * maxSwingFactor / 1e18;
        assertLt(depositBonus, maxBonus);
    }

    function test_fuzz_node_swing_price_redeem_never_exceeds_max_6decimals(
        uint64 maxSwingFactor,
        uint64 targetReserveRatio,
        uint256 seedAmount,
        uint256 withdrawalAmount
    ) public {
        maxSwingFactor = uint64(bound(maxSwingFactor, 0.01 ether, 0.99 ether));
        targetReserveRatio = uint64(bound(targetReserveRatio, 0.01 ether, 0.99 ether));
        seedAmount = bound(seedAmount, 100 ether, 1e36);

        deal(address(testToken6), address(user), seedAmount);
        vm.startPrank(user);
        testToken6.approve(address(decNode), seedAmount);
        decNode.deposit(seedAmount, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        decNode.enableSwingPricing(true, maxSwingFactor);
        decNode.updateTargetReserveRatio(targetReserveRatio);
        decNode.updateComponentAllocation(address(testVault6), 1 ether - targetReserveRatio, 0, address(router4626));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        decNode.startRebalance();
        uint256 investmentAmount = router4626.invest(address(decNode), address(testVault6), 0);
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        withdrawalAmount = bound(withdrawalAmount, 1 ether, currentReserve);

        // invariant 4: returned assets are always less than withdrawal amount
        uint256 sharesToRedeem = decNode.convertToShares(withdrawalAmount);
        uint256 returnedAssets = _userRedeemsAndClaims(user, sharesToRedeem, address(decNode));
        assertLt(returnedAssets, withdrawalAmount);

        // invariant 5: withdrawal penalty never exceeds the value of the max swing factor
        uint256 tolerance = 10;
        uint256 withdrawalPenalty = withdrawalAmount - returnedAssets - tolerance;
        uint256 maxPenalty = withdrawalAmount * maxSwingFactor / 1e18;
        assertLt(withdrawalPenalty, maxPenalty);
    }
}
