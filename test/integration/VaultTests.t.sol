// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";

import {Node, ComponentAllocation} from "src/Node.sol";

contract Harness is Node {
    constructor(address _asset, address _rebalancer, address owner)
        Node(
            address(1),
            "Test Node",
            "TNODE",
            _asset,
            address(0),
            owner,
            _rebalancer,
            new address[](0),
            new address[](0),
            new ComponentAllocation[](0),
            ComponentAllocation(0)
        )
    {}

    function getSwingFactor(int256 reserveImpact) public view returns (uint256 swingFactor) {
        return _getSwingFactor(reserveImpact);
    }
}

contract VaultTests is BaseTest {
    Harness harness;

    function setUp() public override {
        super.setUp();
        harness = new Harness(address(asset), address(rebalancer), address(owner));
        vm.prank(owner);
        harness.transferOwnership(address(owner));
    }

    function test_VaultTests_depositAndRedeem() public {
        _seedNode(1000 ether);
        console2.log(node.totalAssets());
        uint256 startingBalance = asset.balanceOf(address(user));
        uint256 expectedShares = node.previewDeposit(100 ether);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether); // @note this approval ok
        node.deposit(100 ether, user);
        vm.stopPrank();

        // check user got the right shares
        uint256 userShares = node.balanceOf(address(user));
        assertEq(userShares, expectedShares);

        // check accounts ended up with the correct balances
        assertEq(node.totalAssets(), 100 ether + 1000 ether);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        // check convertToAssets & convertToShares work properly
        assertEq(asset.balanceOf(address(node)) - 1000 ether, node.convertToAssets(userShares));
        assertEq(userShares, node.convertToShares(asset.balanceOf(address(node)) - 1000 ether));

        // start redemption flow
        vm.startPrank(user);
        node.approve(address(node), userShares);
        node.requestRedeem(userShares, user, user); // @note this approval ok
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), userShares);
        assertEq(node.balanceOf(address(user)), 0);
        assertEq(node.totalAssets(), 1000 ether + 100 ether);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        uint256 pendingRedeemRequest = node.pendingRedeemRequest(0, user);
        assertEq(pendingRedeemRequest, node.convertToShares(100 ether));

        vm.prank(address(node));
        asset.approve(address(node), 100 ether); // @bug approval required by node

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableRedeemRequest = node.claimableRedeemRequest(0, user);
        assertEq(claimableRedeemRequest, node.convertToShares(100 ether));

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));
        assertEq(asset.balanceOf(address(escrow)), 100 ether);

        vm.prank(address(escrow));
        asset.approve(address(node), 100 ether); // @bug approval required by escrow

        vm.prank(user);
        node.withdraw(100 ether, user, user);

        assertEq(asset.balanceOf(address(user)), startingBalance);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(node.totalAssets(), 1000 ether);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));
    }

    function test_VaultTests_investsToVault() public {
        _seedNode(100 ether);

        vm.prank(address(node));
        asset.approve(address(vault), 100 ether); // @bug approval required by node

        vm.startPrank(rebalancer);
        router4626.deposit(address(node), address(vault), 90 ether);
        vm.stopPrank();

        assertEq(vault.balanceOf(address(node)), 90 ether);
        assertEq(asset.balanceOf(address(vault)), 90 ether);
        assertEq(asset.balanceOf(address(node)), 10 ether);
        assertEq(node.balanceOf(address(vault)), 0);
        assertEq(node.totalAssets(), 10 ether + 90 ether);
    }

    function test_VaultTests_getSwingFactor() public {
        // assert swing pricing returns zero when not enabled
        vm.assertFalse(harness.swingPricingEnabled());
        vm.assertEq(harness.getSwingFactor(1e16), 0);

        // assert enable swing pricing returns a value
        vm.prank(owner);
        harness.enableSwingPricing(true);
        vm.assertTrue(harness.swingPricingEnabled());
        vm.assertGt(harness.getSwingFactor(1e16), 0);

        // todo add selector
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidInput.selector, -1e16));
        harness.getSwingFactor(-1e16);

        // assert swing factor is zero if reserve target is met
        uint256 swingFactor = harness.getSwingFactor(int256(harness.targetReserveRatio()));
        assertEq(swingFactor, 0);

        // assert swing factor is zero if reserve target is exceeded
        swingFactor = harness.getSwingFactor(int256(harness.targetReserveRatio()) + 1e16);
        assertEq(swingFactor, 0);

        // assert that swing factor approaches maxDiscount when reserve approaches zero
        int256 minReservePossible = 1;
        swingFactor = harness.getSwingFactor(minReservePossible);
        assertEq(swingFactor, harness.maxDiscount() - 1);

        // assert that swing factor is very small when reserve approaches target
        int256 maxReservePossible = int256(harness.targetReserveRatio()) - 1;
        swingFactor = harness.getSwingFactor(maxReservePossible);
        assertGt(swingFactor, 0);
        assertLt(swingFactor, 1e15); // 0.1%
    }

    function test_VaultTests_swingPriceDeposit() public {
        _userDeposits(user, 100 ether);

        vm.prank(owner);
        node.enableSwingPricing(true);

        vm.prank(address(node));
        asset.approve(address(vault), 90 ether); // @bug approval required by node

        vm.startPrank(rebalancer);
        router4626.deposit(address(node), address(vault), 90 ether);
        vm.stopPrank();
        console2.log("node.totalAssets(): ", node.totalAssets() / 1e18);
        console2.log("node.totalSupply(): ", node.totalSupply() / 1e18);
        console2.log("asset.balanceOf(address(node)): ", asset.balanceOf(address(node)) / 1e18);
        console2.log("asset.balanceOf(address(vault)): ", asset.balanceOf(address(vault)) / 1e18);

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = _getCurrentReserveRatio();
        assertEq(reserveRatio, node.targetReserveRatio());

        // mint cash so invested assets = 100
        asset.mint(address(vault), 10 ether + 1);
        assertEq(asset.balanceOf(address(vault)), 100 ether + 1);

        console2.log("asset.balanceOf(address(vault)): ", asset.balanceOf(address(vault)) / 1e18);
        console2.log("node.totalAssets(): ", node.totalAssets() / 1e18);

        // get the shares to be minted from a tx with no swing factor
        // this will break later when you complete 4626 conversion
        uint256 nonAdjustedShares = node.convertToShares(10 ether);

        assertEq(node.balanceOf(address(user2)), 0);

        // user deposits 10 ether to node
        vm.startPrank(user2);
        asset.approve(address(node), 10 ether);
        node.deposit(10 ether, address(user2));
        vm.stopPrank();

        assertEq(asset.balanceOf(address(escrow)), 0);

        // TEST 1: assert that no swing factor is applied when reserve ratio exceeds target

        // get the reserve ratio after the deposit and assert it is greater than target reserve ratio
        uint256 reserveRatioAfterTX = _getCurrentReserveRatio();
        assertGt(reserveRatioAfterTX, node.targetReserveRatio());

        // get the actual shares received and assert they are the same i.e. no swing factor applied
        uint256 sharesReceived = node.balanceOf(address(user2));
        console2.log("sharesReceived: ", sharesReceived);
        console2.log("nonAdjustedShares: ", nonAdjustedShares);
        console2.log("diff: ", sharesReceived - nonAdjustedShares);

        // accuracy is 0.1%
        // todo test this later to get it to 100% accuracy
        assertApproxEqRel(sharesReceived, nonAdjustedShares, 1e15);
    }

    function _getCurrentReserveRatio() public view returns (uint256 reserveRatio) {
        uint256 currentReserveRatio = MathLib.mulDiv(asset.balanceOf(address(node)), 1e18, node.totalAssets());

        return (currentReserveRatio);
    }

    function _userDeposits(address user, uint256 amount) internal {
        vm.startPrank(user);
        asset.approve(address(node), amount);
        node.deposit(amount, user);
        vm.stopPrank();
    }
}
