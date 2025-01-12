// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NodeHarness is Node {
    constructor(
        address registry_,
        string memory name,
        string memory symbol,
        address asset_,
        address owner,
        address[] memory routers,
        address[] memory components_,
        ComponentAllocation[] memory componentAllocations_,
        ComponentAllocation memory reserveAllocation_
    ) Node(registry, name, symbol, asset_, owner, routers, components_, componentAllocations_, reserveAllocation_) {}

    // function getAssetDecimals() public view returns (uint256 decimals) {
    //     return super._getAssetDecimals();
    // }
}

contract DecimalsTests is BaseTest {
    INode public decNode;
    NodeHarness public nodeHarness;
    IEscrow public decEscrow;
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
        maxDeposit = nodeImpl.MAX_DEPOSIT();

        vm.startPrank(owner);
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
            reserveAllocation: _defaultReserveAllocation(),
            salt: SALT
        });

        (decNode, decEscrow) = factory.deployFullNode(params);

        quoter.setErc4626(address(testVault6), true);
        router4626.setWhitelistStatus(address(testVault6), true);

        decEscrow.approveMax(address(testToken6), address(decNode));
        vm.stopPrank();

        vm.label(address(testToken18), "Test Token 18");
        vm.label(address(testVault18), "Test Vault 18");
        vm.label(address(testToken6), "Test Token 6");
        vm.label(address(testVault6), "Test Vault 6");
        vm.label(address(decNode), "Decimal Tests Node");
        vm.label(address(decEscrow), "Decimal Tests Escrow");

        deal(address(testToken6), address(user), type(uint256).max);

        // todo: figure out node harness
        // nodeHarness = new NodeHarness(address(registry),
        //     "TEST_NAME",
        //     "TEST_SYMBOL",
        //     address(testToken6),
        //     address(owner),
        //     _toArray(address(router4626)),
        //     _toArray(address(testVault6)),
        //     _defaultComponentAllocations(1),
        //     _defaultReserveAllocation());
    }

    function test_decimals_setup() public view {
        assertEq(testToken18.decimals(), 18);
        assertEq(testVault18.decimals(), 18);

        assertEq(testToken6.decimals(), 6);
        assertEq(testVault6.decimals(), 6);

        // Node is 6 dec by inheritance
        // Adding 6 dec share token does not affect this
        assertEq(address(testToken6), decNode.asset());
        assertEq(ERC20(decNode.asset()).decimals(), 6);
        assertFalse(decNode.decimals() == 6);
        assertTrue(decNode.decimals() == 18);
    }

    function test_decimals_deposit(uint256 deposit, uint64 allocation) public {
        deposit = bound(deposit, 10, 1e36);
        allocation = uint64(bound(uint256(allocation), 1, 1e18));
        uint8 scalingFactor = uint8(18 - testToken6.decimals());
        console2.log("scalingFactor", scalingFactor);

        console2.log("uint64 max: ", type(uint64).max);

        vm.warp(block.timestamp + 25 hours);

        vm.startPrank(owner);
        decNode.updateComponentAllocation(
            address(testVault6), ComponentAllocation({targetWeight: allocation, maxDelta: 0})
        );
        decNode.updateReserveAllocation(ComponentAllocation({targetWeight: 1e18 - allocation, maxDelta: 0}));
        vm.stopPrank();

        vm.prank(rebalancer);
        decNode.startRebalance();

        vm.startPrank(user);
        testToken6.approve(address(decNode), deposit);
        decNode.deposit(deposit, user);
        vm.stopPrank();

        assertEq(testToken6.balanceOf(address(decNode)) * 10 ** scalingFactor, decNode.balanceOf(address(user)));

        vm.prank(rebalancer);
        router4626.invest(address(decNode), address(testVault6));

        uint256 componentRatio = decNode.getComponentRatio(address(testVault6));

        assertEq(testVault6.balanceOf(address(decNode)), MathLib.mulDiv(deposit, componentRatio, 1e18));
        assertEq(testToken6.balanceOf(address(testVault6)), testVault6.balanceOf(address(decNode)));
    }

    function test_decimals_getAssetDecimals() public {
        // assertEq(Node(address(decNode)).getAssetDecimals(), 6);

        // uint256 convertedNumber = Node(address(decNode)).convertTo1e18(1e6);
        // console2.log(convertedNumber);
        // assertEq(convertedNumber, 1e18);
    }

    function test_fuzz_node_swing_price_deposit_never_exceeds_max_6decimals(
        uint256 maxSwingFactor,
        uint256 targetReserveRatio,
        uint256 seedAmount,
        uint256 depositAmount
    ) public {
        maxSwingFactor = bound(maxSwingFactor, 0.01 ether, 0.99 ether);
        targetReserveRatio = bound(targetReserveRatio, 0.01 ether, 0.99 ether);
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
        decNode.updateReserveAllocation(ComponentAllocation({targetWeight: targetReserveRatio, maxDelta: 0}));
        decNode.updateComponentAllocation(
            address(testVault6), ComponentAllocation({targetWeight: 1 ether - targetReserveRatio, maxDelta: 0})
        );
        vm.stopPrank();

        vm.startPrank(rebalancer);
        decNode.startRebalance();
        uint256 investmentAmount = router4626.invest(address(decNode), address(testVault6));
        vm.stopPrank();

        uint256 currentReserve = seedAmount - investmentAmount;
        uint256 sharesToRedeem = decNode.convertToShares(currentReserve) / 10 + 1;
        console2.log("sharesToRedeem", sharesToRedeem);
        console2.log("decNode.balanceOf(user)", decNode.balanceOf(user));

        assertGt(decNode.balanceOf(user), sharesToRedeem);
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
}
