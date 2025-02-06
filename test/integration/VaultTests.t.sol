// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";

import {Node, ComponentAllocation} from "src/Node.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract QuoterHarness is QuoterV1 {
    constructor(address _node) QuoterV1(_node) {}

    function getSwingFactor(int256 reserveImpact, uint64 maxSwingFactor, uint64 targetReserveRatio)
        public
        pure
        returns (uint256)
    {
        return super._getSwingFactor(reserveImpact, maxSwingFactor, targetReserveRatio);
    }
}

contract VaultTests is BaseTest {
    QuoterV1 mockQuoter;
    ERC20Mock internal mockAsset;
    QuoterHarness mockQuoterHarness;

    function setUp() public override {
        super.setUp();
        mockAsset = ERC20Mock(address(asset));
        mockQuoter = new QuoterV1(address(1));
        mockQuoterHarness = new QuoterHarness(address(1));
    }

    function test_VaultTests_depositAndWithdraw() public {
        _seedNode(1000 ether);
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

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableRedeemRequest = node.claimableRedeemRequest(0, user);
        assertEq(claimableRedeemRequest, node.convertToShares(100 ether));

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));
        assertEq(asset.balanceOf(address(escrow)), 100 ether);

        vm.prank(user);
        node.withdraw(100 ether, user, user);

        assertEq(asset.balanceOf(address(user)), startingBalance);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(node.totalAssets(), 1000 ether);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));

        uint256 claimableAssets;
        uint256 sharesAdjusted;

        (pendingRedeemRequest, claimableRedeemRequest, claimableAssets, sharesAdjusted) = node.requests(user);
        assertEq(pendingRedeemRequest, 0);
        assertEq(claimableRedeemRequest, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, 0);
    }

    function test_VaultTests_mintAndRedeem() public {
        _seedNode(1000 ether);
        uint256 startingBalance = asset.balanceOf(address(user));
        uint256 expectedAssets = node.previewMint(100 ether);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether); // @note this approval ok
        node.mint(100 ether, user);
        vm.stopPrank();

        // check user got the right shares
        uint256 userBalance = node.convertToAssets(node.balanceOf(address(user)));
        assertEq(userBalance, expectedAssets);

        // check accounts ended up with the correct balances
        assertEq(node.totalAssets(), 100 ether + 1000 ether);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        // check convertToShares work properly
        assertEq(node.totalSupply(), node.convertToShares(expectedAssets + 1000 ether));
        assertEq(node.totalAssets(), expectedAssets + 1000 ether);

        // start redemption flow
        vm.startPrank(user);
        node.approve(address(node), type(uint256).max);
        node.requestRedeem(node.balanceOf(user), user, user);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), node.convertToShares(expectedAssets));
        assertEq(node.balanceOf(address(user)), 0);
        assertEq(node.totalAssets(), 1000 ether + 100 ether);
        assertEq(asset.balanceOf(address(user)), startingBalance - 100 ether);

        uint256 pendingRedeemRequest = node.pendingRedeemRequest(0, user);
        assertEq(pendingRedeemRequest, node.convertToShares(100 ether));

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 claimableRedeemRequest = node.claimableRedeemRequest(0, user);
        assertEq(claimableRedeemRequest, expectedAssets);

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));
        assertEq(asset.balanceOf(address(escrow)), 100 ether);

        vm.prank(user);
        node.redeem(100 ether, user, user);

        assertEq(asset.balanceOf(address(user)), startingBalance);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(node.totalAssets(), 1000 ether);
        assertEq(node.totalSupply(), node.convertToShares(1000 ether));

        uint256 claimableAssets;
        uint256 sharesAdjusted;

        (pendingRedeemRequest, claimableRedeemRequest, claimableAssets, sharesAdjusted) = node.requests(user);
        assertEq(pendingRedeemRequest, 0);
        assertEq(claimableRedeemRequest, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, 0);
    }

    function test_VaultTests_investsToVault() public {
        _seedNode(100 ether);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        assertEq(vault.balanceOf(address(node)), 90 ether);
        assertEq(asset.balanceOf(address(vault)), 90 ether);
        assertEq(asset.balanceOf(address(node)), 10 ether);
        assertEq(node.balanceOf(address(vault)), 0);
        assertEq(node.totalAssets(), 10 ether + 90 ether);
    }

    function test_VaultTests_getSwingFactor() public {
        uint64 maxSwingFactor = 2e16;
        uint64 targetReserveRatio = 10e16;

        vm.assertGt(mockQuoterHarness.getSwingFactor(1e16, maxSwingFactor, targetReserveRatio), 0);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidInput.selector, -1e16));
        mockQuoterHarness.getSwingFactor(-1e16, maxSwingFactor, targetReserveRatio);

        // assert swing factor is zero if reserve target is met
        uint256 swingFactor =
            mockQuoterHarness.getSwingFactor(int256(uint256(targetReserveRatio)), maxSwingFactor, targetReserveRatio);
        assertEq(swingFactor, 0);

        // assert swing factor is zero if reserve target is exceeded
        swingFactor = mockQuoterHarness.getSwingFactor(
            int256(uint256(targetReserveRatio)) + 1e16, maxSwingFactor, targetReserveRatio
        );
        assertEq(swingFactor, 0);

        // assert that swing factor approaches maxSwingFactor when reserve approaches zero
        int256 minReservePossible = 1;
        swingFactor = mockQuoterHarness.getSwingFactor(minReservePossible, maxSwingFactor, targetReserveRatio);
        assertEq(swingFactor, maxSwingFactor - 1);

        // assert that swing factor is very small when reserve approaches target
        int256 maxReservePossible = int256(uint256(targetReserveRatio)) - 1;
        swingFactor = mockQuoterHarness.getSwingFactor(maxReservePossible, maxSwingFactor, targetReserveRatio);
        assertGt(swingFactor, 0);
        assertLt(swingFactor, 1e15); // 0.1%
    }

    function test_VaultTests_swingPriceDeposit() public {
        _userDeposits(user, 100 ether);

        // set max discount for swing pricing
        uint64 maxSwingFactor = 2e16;

        vm.prank(owner);
        node.enableSwingPricing(true, maxSwingFactor);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = _getCurrentReserveRatio();
        assertEq(reserveRatio, node.targetReserveRatio());

        // mint cash so invested assets = 100
        mockAsset.mint(address(vault), 10 ether + 1);
        assertEq(asset.balanceOf(address(vault)), 100 ether + 1);

        vm.prank(rebalancer);
        node.updateTotalAssets();

        // get the shares to be minted from a tx with no swing factor
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

        // accuracy is 0.1% note this is too big a delta
        // todo test this later to get it to 100% accuracy
        assertApproxEqRel(sharesReceived, nonAdjustedShares, 1e15, "check here");

        // rebalances excess reserve to vault so reserve ratio = 100%
        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault), 0);
        assertEq(node.targetReserveRatio(), _getCurrentReserveRatio());

        vm.startPrank(user2);
        node.approve(address(node), type(uint256).max);
        node.requestRedeem(node.convertToShares(5 ether), user2, user2);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(address(user2));

        // assert reserve ratio is on target and user 3 has zero shares
        assertLt(_getCurrentReserveRatio(), node.targetReserveRatio());
        assertEq(node.balanceOf(address(user3)), 0);

        nonAdjustedShares = node.convertToShares(2 ether);

        vm.startPrank(user3);
        asset.approve(address(node), 2 ether);
        node.deposit(2 ether, address(user3));
        vm.stopPrank();

        // assert shares received are greater than expected due to swing bonus
        sharesReceived = node.balanceOf(address(user3));
        assertGt(sharesReceived, nonAdjustedShares);
    }

    function testAdjustedWithdraw() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = _getCurrentReserveRatio();
        assertEq(reserveRatio, node.targetReserveRatio());

        // mint cash so invested assets = 100
        mockAsset.mint(address(vault), 10 ether + 1);

        // update total assets to reflect new cash
        vm.prank(owner);
        node.updateTotalAssets();

        // user 2 deposits 10e6 to node and burns the rest of their assets
        vm.startPrank(user2);
        asset.approve(address(node), 10 ether);
        node.deposit(10 ether, user2);
        asset.transfer(0x000000000000000000000000000000000000dEaD, asset.balanceOf(user2));
        vm.stopPrank();

        // set max discount for swing pricing
        uint64 maxSwingFactor = 2e16;

        // enable swing pricing
        vm.prank(owner);
        node.enableSwingPricing(true, maxSwingFactor);

        // assert user2 has zero usdc balance
        assertEq(asset.balanceOf(user2), 0);

        // rebalances excess reserve to vault so reserve ratio = 100%
        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault), 0);
        assertEq(node.targetReserveRatio(), _getCurrentReserveRatio());

        // grab share value of deposit
        uint256 sharesToRedeem = node.convertToShares(10 ether);

        // user 2 withdraws the same amount they deposited
        vm.startPrank(user2);
        node.approve(address(node), type(uint256).max);
        node.requestRedeem(sharesToRedeem, user2, user2);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user2);

        uint256 maxWithdraw = node.maxWithdraw(address(user2));

        // user 2 withdraws max assets
        vm.prank(user2);
        node.withdraw(maxWithdraw, address(user2), address(user2));

        // assert that user2 has burned all shares to & withdrawn all assets
        assertEq(node.balanceOf(user2), 0);
        assertEq(node.maxWithdraw(user2), 0);

        // assert that user2 received less USDC back than they deposited
        assertLt(asset.balanceOf(user2), 10 ether);

        // note: this test does not check if the correct amount was returned
        // only that is was less than originally deposited
        // check for correct swing factor is in that test
    }

    function test_fulfilRedeemRequest_4626Router() public {
        address[] memory components = node.getComponents();

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.setLiquidationQueue(components);
        node.updateTargetReserveRatio(0);
        node.updateComponentAllocation(address(vault), 1 ether, 0, address(router4626));
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        assertEq(asset.balanceOf(address(node)), 0);
        assertEq(asset.balanceOf(address(vault)), 100 ether);
        assertEq(node.balanceOf(user), 100 ether);
        assertEq(node.totalAssets(), 100 ether);
        assertEq(node.balanceOf(address(escrow)), 0);

        vm.startPrank(user);
        node.approve(address(node), 50 ether);
        node.requestRedeem(50 ether, user, user);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), 50 ether);
        assertEq(node.balanceOf(user), 50 ether);
        assertEq(node.totalAssets(), 100 ether);
        assertEq(node.totalSupply(), 100 ether);
        assertEq(asset.balanceOf(address(vault)), 100 ether);

        (uint256 sharesPending,,, uint256 sharesAdjusted) = node.requests(user);

        assertEq(sharesPending, 50 ether);
        assertEq(sharesAdjusted, 50 ether);

        vm.startPrank(rebalancer);
        router4626.fulfillRedeemRequest(address(node), user, address(vault), 0);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.claimableRedeemRequest(0, user), 50 ether);
        assertEq(asset.balanceOf(address(vault)), 50 ether);
        assertEq(asset.balanceOf(address(escrow)), 50 ether);
        assertEq(asset.balanceOf(address(node)), 0);
        assertEq(node.totalAssets(), 50 ether);
        assertEq(node.totalSupply(), 50 ether);

        (sharesPending,,, sharesAdjusted) = node.requests(user);
        assertEq(sharesPending, 0);
        assertEq(sharesAdjusted, 0);

        vm.startPrank(user);
        node.approve(address(node), 50 ether);
        node.requestRedeem(50 ether, user, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.fulfillRedeemRequest(address(node), user, address(vault), 0);
        vm.stopPrank();

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.claimableRedeemRequest(0, user), 100 ether);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(address(escrow)), 100 ether);
        assertEq(asset.balanceOf(address(node)), 0);
        assertEq(node.totalAssets(), 0);
        assertEq(node.totalSupply(), 0);

        (sharesPending,,, sharesAdjusted) = node.requests(user);
        assertEq(sharesPending, 0);
        assertEq(sharesAdjusted, 0);
    }
}
