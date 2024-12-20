// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import {NodeManagerV1} from "src/managers/NodeManagerV1.sol";

import {Node, ComponentAllocation} from "src/Node.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract VaultTests is BaseTest {
    NodeManagerV1 mockManager;
    ERC20Mock internal mockAsset;

    function setUp() public override {
        super.setUp();
        mockAsset = ERC20Mock(address(asset));
        mockManager = new NodeManagerV1(address(1));
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

        (pendingRedeemRequest, claimableRedeemRequest, claimableAssets, sharesAdjusted) = node.getRequestState(user);
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

        (pendingRedeemRequest, claimableRedeemRequest, claimableAssets, sharesAdjusted) = node.getRequestState(user);
        assertEq(pendingRedeemRequest, 0);
        assertEq(claimableRedeemRequest, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, 0);
    }

    function test_VaultTests_investsToVault() public {
        _seedNode(100 ether);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault));
        vm.stopPrank();

        assertEq(vault.balanceOf(address(node)), 90 ether);
        assertEq(asset.balanceOf(address(vault)), 90 ether);
        assertEq(asset.balanceOf(address(node)), 10 ether);
        assertEq(node.balanceOf(address(vault)), 0);
        assertEq(node.totalAssets(), 10 ether + 90 ether);
    }

    function test_VaultTests_getSwingFactor() public {
        uint256 maxDiscount = 2e16;
        uint256 targetReserveRatio = 10e16;

        vm.assertGt(mockManager.getSwingFactor(1e16, maxDiscount, targetReserveRatio), 0);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidInput.selector, -1e16));
        mockManager.getSwingFactor(-1e16, maxDiscount, targetReserveRatio);

        // assert swing factor is zero if reserve target is met
        uint256 swingFactor = mockManager.getSwingFactor(int256(targetReserveRatio), maxDiscount, targetReserveRatio);
        assertEq(swingFactor, 0);

        // assert swing factor is zero if reserve target is exceeded
        swingFactor = mockManager.getSwingFactor(int256(targetReserveRatio) + 1e16, maxDiscount, targetReserveRatio);
        assertEq(swingFactor, 0);

        // assert that swing factor approaches maxDiscount when reserve approaches zero
        int256 minReservePossible = 1;
        swingFactor = mockManager.getSwingFactor(minReservePossible, maxDiscount, targetReserveRatio);
        assertEq(swingFactor, maxDiscount - 1);

        // assert that swing factor is very small when reserve approaches target
        int256 maxReservePossible = int256(targetReserveRatio) - 1;
        swingFactor = mockManager.getSwingFactor(maxReservePossible, maxDiscount, targetReserveRatio);
        assertGt(swingFactor, 0);
        assertLt(swingFactor, 1e15); // 0.1%
    }

    function test_VaultTests_swingPriceDeposit() public {
        _userDeposits(user, 100 ether);

        // set max discount for swing pricing
        uint256 maxDiscount = 2e16;

        vm.prank(owner);
        node.enableSwingPricing(true, address(deployer.manager()), maxDiscount);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault));
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

        // accuracy is 0.1% note this is too big a delta
        // todo test this later to get it to 100% accuracy
        assertApproxEqRel(sharesReceived, nonAdjustedShares, 1e15);

        // rebalances excess reserve to vault so reserve ratio = 100%
        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault));
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
        router4626.invest(address(node), address(vault));
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = _getCurrentReserveRatio();
        assertEq(reserveRatio, node.targetReserveRatio());

        // mint cash so invested assets = 100
        mockAsset.mint(address(vault), 10 ether + 1);

        // user 2 deposits 10e6 to node and burns the rest of their assets
        vm.startPrank(user2);
        asset.approve(address(node), 10 ether);
        node.deposit(10 ether, user2);
        asset.transfer(0x000000000000000000000000000000000000dEaD, asset.balanceOf(user2));
        vm.stopPrank();

        // set max discount for swing pricing
        uint256 maxDiscount = 2e16;

        // enable swing pricing
        vm.prank(owner);
        node.enableSwingPricing(true, address(deployer.manager()), maxDiscount);

        // assert user2 has zero usdc balance
        assertEq(asset.balanceOf(user2), 0);

        // rebalances excess reserve to vault so reserve ratio = 100%
        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault));
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
        _seedNode(1000 ether);

        address[] memory components = node.getComponents();

        vm.prank(owner);
        node.setLiquidationQueue(components);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault));
        vm.stopPrank();

        uint256 vaultShares = vault.balanceOf(address(node));
        console2.log("vaultShares: ", vaultShares);

        uint256 vaultAssets = vault.convertToAssets(vaultShares);
        console2.log("vaultAssets: ", vaultAssets);

        uint256 sharesToRedeem = node.balanceOf(user);

        assertLt(node.convertToAssets(sharesToRedeem), vaultAssets);

        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.fulfillRedeemRequest(address(node), user, address(vault));
        vm.stopPrank();
    }

    function test_fulfilRedeemBatch_fromReserve() public {
        _seedNode(1_000_000 ether);

        address[] memory components = node.getComponents();
        address[] memory users = new address[](2);
        users[0] = address(user);
        users[1] = address(user2);

        vm.prank(owner);
        node.setLiquidationQueue(components);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.startPrank(user2);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user2);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(vault));

        vm.startPrank(user);
        node.approve(address(node), node.balanceOf(user));
        node.requestRedeem(node.balanceOf(user), user, user);
        vm.stopPrank();

        vm.startPrank(user2);
        node.approve(address(node), node.balanceOf(user2));
        node.requestRedeem(node.balanceOf(user2), user2, user2);
        vm.stopPrank();

        console2.log(node.pendingRedeemRequest(0, user));
        console2.log(node.pendingRedeemRequest(0, user2));

        vm.startPrank(rebalancer);
        node.fulfillRedeemBatch(users);

        assertEq(node.balanceOf(user), 0);
        assertEq(node.balanceOf(user2), 0);

        assertEq(node.totalAssets(), 1_000_000 ether);
        assertEq(node.totalSupply(), node.convertToShares(1_000_000 ether));

        assertEq(asset.balanceOf(address(escrow)), 200 ether);
        assertEq(node.claimableRedeemRequest(0, user), 100 ether);
        assertEq(node.claimableRedeemRequest(0, user2), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
