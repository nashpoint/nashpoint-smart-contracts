// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {console2} from "forge-std/Test.sol";
import {BaseTest} from "../../BaseTest.sol";

import {BaseRouter} from "src/libraries/BaseRouter.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {IERC7540, IERC7540Deposit} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {ComponentAllocation} from "src/interfaces/INode.sol";

import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";

contract ERC7540RouterHarness is ERC7540Router {
    constructor(address _registry) ERC7540Router(_registry) {}

    function getInvestmentSize(address node, address component) public view returns (uint256 depositAssets) {
        return super._getInvestmentSize(node, component);
    }

    function getErc7540Assets(address node, address component) public view returns (uint256) {
        return super._getErc7540Assets(node, component);
    }

    function mint(address node, address component, uint256 amount) public returns (uint256) {
        return super._mint(node, component, amount);
    }
}

contract ERC7540RouterTest is BaseTest {
    ERC7540RouterHarness public testRouter;
    ComponentAllocation public allocation;

    function setUp() public override {
        super.setUp();
        testRouter = new ERC7540RouterHarness(address(registry));

        allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});
    }

    function test_getInvestmentSize_7540() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(liquidityPool));

        assertEq(node.getComponentRatio(address(liquidityPool)), 0.5 ether);
        assertEq(liquidityPool.balanceOf(address(node)), 0);
        assertEq(investmentSize, 50 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        investInAsyncVault Tests
    //////////////////////////////////////////////////////////////*/

    function test_investInAsyncVault() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        assertEq(liquidityPool.pendingDepositRequest(0, address(node)), 50 ether);
    }

    function test_investInAsyncVault_fail_not_whitelisted() public {
        _seedNode(100 ether);
        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotWhitelisted.selector));
        router7540.investInAsyncVault(address(node), address(liquidityPool));
    }

    function test_investInAsyncVault_fail_not_rebalancer() public {
        _seedNode(100 ether);
        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRebalancer.selector));

        vm.prank(user);
        router7540.investInAsyncVault(address(node), address(liquidityPool));
    }

    function test_investInAsyncVault_fail_not_node() public {
        _seedNode(100 ether);
        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidNode.selector));

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(user), address(liquidityPool));
    }

    function test_investInAsyncVault_fail_invalid_component() public {
        _seedNode(100 ether);

        address invalidComponent = makeAddr("invalidComponent");
        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);

        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        router7540.setWhitelistStatus(invalidComponent, true);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidComponent.selector));
        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), invalidComponent);
    }

    function test_investInAsyncVault_revert_ReserveBelowTargetRatio() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, address(user));
        vm.stopPrank();

        allocation = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.startPrank(user);
        node.approve(address(node), 1 ether);
        node.requestRedeem(1 ether, address(user), address(user));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(address(user));

        vm.expectRevert(ErrorsLib.ReserveBelowTargetRatio.selector);

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));
    }

    function test_investInAsyncVault_revert_ComponentWithinTargetRange() public {
        _seedNode(1000 ether);
        allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.startPrank(user);
        asset.approve(address(node), 1 ether);
        node.deposit(1 ether, address(user));
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.ComponentWithinTargetRange.selector, address(node), address(liquidityPool))
        );
        router7540.investInAsyncVault(address(node), address(liquidityPool));
    }

    /// todo: do this one after you fix the valuation problem mentioned above
    function test_investInAsyncVault_depositAmount_equals_availableReserve() public {}

    function test_mintClaimableShares() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();
        assertEq(liquidityPool.claimableDepositRequest(0, address(node)), 50 ether);

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(50 ether));
    }

    function test_requestAsyncWithdrawal() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(50 ether));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
        vm.stopPrank();

        assertEq(liquidityPool.pendingRedeemRequest(0, address(node)), 10 ether);
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(40 ether));
    }

    function test_executeAsyncWithdrawal() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));

        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
        vm.stopPrank();

        assertEq(liquidityPool.pendingRedeemRequest(0, address(node)), 10 ether);

        vm.prank(testPoolManager);
        liquidityPool.processPendingRedemptions();

        assertEq(liquidityPool.claimableRedeemRequest(0, address(node)), 10 ether);
        assertEq(liquidityPool.pendingRedeemRequest(0, address(node)), 0);

        uint256 balanceBefore = asset.balanceOf(address(node));

        vm.prank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);

        uint256 balanceAfter = asset.balanceOf(address(node));
        assertEq(balanceAfter - balanceBefore, 10 ether);
    }

    /* mintClaimableShares Tests */
    function test_mintClaimableShares_fail_not_whitelisted() public {
        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotWhitelisted.selector));
        router7540.mintClaimableShares(address(node), address(liquidityPool));
    }

    function test_mintClaimableShares_fail_not_rebalancer() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRebalancer.selector));
        router7540.mintClaimableShares(address(node), address(liquidityPool));
    }

    function test_mintClaimableShares_fail_invalid_component() public {
        address invalidComponent = makeAddr("invalidComponent");
        vm.startPrank(owner);
        router7540.setWhitelistStatus(invalidComponent, true);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidComponent.selector));
        router7540.mintClaimableShares(address(node), invalidComponent);
    }

    function test_mintClaimableShares_revert_not_enough_shares_received() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        // Setup: First create a deposit request
        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        // Make deposit claimable
        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        // Mock the mint function to return fewer shares than requested
        uint256 claimableShares = liquidityPool.maxMint(address(node));
        vm.mockCall(
            address(liquidityPool),
            abi.encodeWithSelector(IERC7540Deposit.mint.selector, claimableShares, address(node), address(node)),
            abi.encode(claimableShares - 1) // Return 1 less share than expected
        );

        // Attempt to mint should revert
        vm.prank(rebalancer);
        vm.expectRevert("Not enough shares received");
        router7540.mintClaimableShares(address(node), address(liquidityPool));
    }

    /* requestAsyncWithdrawal Tests */
    function test_requestAsyncWithdrawal_fail_not_whitelisted() public {
        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotWhitelisted.selector));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
    }

    function test_requestAsyncWithdrawal_fail_not_rebalancer() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRebalancer.selector));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
    }

    function test_requestAsyncWithdrawal_fail_invalid_component() public {
        address invalidComponent = makeAddr("invalidComponent");
        vm.startPrank(owner);
        router7540.setWhitelistStatus(invalidComponent, true);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidComponent.selector));
        router7540.requestAsyncWithdrawal(address(node), invalidComponent, 10 ether);
    }

    function test_requestAsyncWithdrawal_revert_ExceedsAvailableShares() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        vm.stopPrank();

        address shareToken = IERC7575(address(liquidityPool)).share();
        uint256 currentShares = IERC20(shareToken).balanceOf(address(node));

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.ExceedsAvailableShares.selector, address(node), address(liquidityPool), currentShares + 1
            )
        );
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), currentShares + 1);
    }

    /* executeAsyncWithdrawal Tests */
    function test_executeAsyncWithdrawal_fail_not_whitelisted() public {
        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotWhitelisted.selector));
        router7540.executeAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
    }

    function test_executeAsyncWithdrawal_fail_not_rebalancer() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRebalancer.selector));
        router7540.executeAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
    }

    function test_executeAsyncWithdrawal_fail_invalid_component() public {
        address invalidComponent = makeAddr("invalidComponent");
        vm.startPrank(owner);
        router7540.setWhitelistStatus(invalidComponent, true);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidComponent.selector));
        router7540.executeAsyncWithdrawal(address(node), invalidComponent, 10 ether);
    }

    function test_executeAsyncWithdrawal_revert_ExceedsAvailableAssets() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        uint256 withdrawAmount = 10 ether;

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), withdrawAmount);
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingRedemptions();

        uint256 maxWithdraw = IERC7575(address(liquidityPool)).maxWithdraw(address(node));

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.ExceedsAvailableAssets.selector, address(node), address(liquidityPool), maxWithdraw + 1
            )
        );
        router7540.executeAsyncWithdrawal(address(node), address(liquidityPool), maxWithdraw + 1);
    }

    function test_executeAsyncWithdrawal_revert_InsufficientAssetsReturned() public {
        _seedNode(100 ether);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));

        // Request withdrawal
        uint256 withdrawAmount = 10 ether;
        vm.prank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), withdrawAmount);

        vm.prank(testPoolManager);
        liquidityPool.processPendingRedemptions();

        // Mock the withdrawal to return less than requested
        bytes memory withdrawData =
            abi.encodeWithSelector(IERC7575.withdraw.selector, withdrawAmount, address(node), address(node));
        vm.mockCall(address(liquidityPool), withdrawData, abi.encode(withdrawAmount - 1));

        // Attempt withdrawal should revert with InsufficientAssetsReturned
        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InsufficientAssetsReturned.selector,
                address(liquidityPool),
                withdrawAmount - 1,
                withdrawAmount
            )
        );
        router7540.executeAsyncWithdrawal(address(node), address(liquidityPool), withdrawAmount);
    }
}
