// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {console2} from "forge-std/Test.sol";
import {BaseTest} from "../../BaseTest.sol";

import {BaseRouter} from "src/libraries/BaseRouter.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {IERC7540, IERC7540Deposit} from "src/interfaces/IERC7540.sol";
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
        _seedNode(100 ether);
    }

    function test_investInAsyncVault_revert_ComponentWithinTargetRange() public {}

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
    function test_mintClaimableShares_fail_not_whitelisted() public {}

    function test_mintClaimableShares_fail_not_rebalancer() public {}

    function test_mintClaimableShares_fail_invalid_component() public {}

    function test_mintClaimableShares_revert_not_enough_shares_received() public {}

    /* requestAsyncWithdrawal Tests */
    function test_requestAsyncWithdrawal_fail_not_whitelisted() public {}

    function test_requestAsyncWithdrawal_fail_not_rebalancer() public {}

    function test_requestAsyncWithdrawal_fail_invalid_component() public {}

    function test_requestAsyncWithdrawal_revert_ExceedsAvailableShares() public {}

    /* executeAsyncWithdrawal Tests */
    function test_executeAsyncWithdrawal_fail_not_whitelisted() public {}

    function test_executeAsyncWithdrawal_fail_not_rebalancer() public {}

    function test_executeAsyncWithdrawal_fail_invalid_component() public {}

    function test_executeAsyncWithdrawal_revert_ExceedsAvailableAssets() public {}

    function test_executeAsyncWithdrawal_revert_InsufficientAssetsReturned() public {}

    /* Internal Function Tests */
    function test_getErc7540Assets_with_share_balance() public {}

    function test_getErc7540Assets_with_pending_deposits() public {}

    function test_getErc7540Assets_with_claimable_deposits() public {}

    function test_getErc7540Assets_with_pending_redeems() public {}

    function test_getErc7540Assets_with_claimable_redeems() public {}

    function test_getErc7540Assets_with_all_states() public {}

    /* Edge Cases */
    function test_non_zero_requestId() public {}

    function test_multiple_deposit_withdrawal_requests() public {}

    function test_zero_value_operations() public {}

    function test_different_share_asset_conversion_rates() public {}
}
