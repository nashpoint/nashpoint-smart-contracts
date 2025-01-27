// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {console2} from "forge-std/Test.sol";
import {BaseTest} from "../../BaseTest.sol";

import {BaseRouter} from "src/libraries/BaseRouter.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {ComponentAllocation} from "src/interfaces/INode.sol";

import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

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
    ERC4626Mock public testComponent70;
    ComponentAllocation public allocation;

    function setUp() public override {
        super.setUp();
        testRouter = new ERC7540RouterHarness(address(registry));
        testComponent70 = new ERC4626Mock(address(asset));

        allocation = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether, isComponent: true});

        vm.warp(block.timestamp + 1 days);
        vm.prank(owner);
        node.updateComponentAllocation(
            address(vault), ComponentAllocation({targetWeight: 0 ether, maxDelta: 0.01 ether, isComponent: true})
        );

        // jump back in time to keep the cache valid
        vm.warp(block.timestamp - 1 days);
    }

    function test_getInvestmentSize_7540() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(liquidityPool));

        assertEq(node.getComponentAllocation(address(liquidityPool)).targetWeight, 0.9 ether);
        assertEq(liquidityPool.balanceOf(address(node)), 0);
        assertEq(investmentSize, 90 ether);
    }

    function test_getInvestmentSize_7540_atTargetRatio() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        allocation = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether, isComponent: true});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(liquidityPool));
        assertEq(investmentSize, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        investInAsyncVault Tests
    //////////////////////////////////////////////////////////////*/

    function test_investInAsyncVault() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        assertEq(liquidityPool.pendingDepositRequest(0, address(node)), 90 ether);
    }

    function test_investInAsyncVault_fail_not_whitelisted() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotWhitelisted.selector));
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();
    }

    function test_investInAsyncVault_fail_not_rebalancer() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRebalancer.selector));
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
    }

    function test_investInAsyncVault_fail_not_node() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidNode.selector));
        router7540.investInAsyncComponent(address(user), address(liquidityPool));
        vm.stopPrank();
    }

    function test_investInAsyncVault_fail_invalid_component() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        address invalidComponent = makeAddr("invalidComponent");
        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);

        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        router7540.setWhitelistStatus(invalidComponent, true);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidComponent.selector));
        vm.prank(rebalancer);
        router7540.investInAsyncComponent(address(node), invalidComponent);
    }

    function test_investInAsyncVault_revert_ReserveBelowTargetRatio() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, address(user));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        allocation = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether, isComponent: true});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.startPrank(user);
        node.approve(address(node), 1 ether);
        node.requestRedeem(1 ether, address(user), address(user));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(address(user));

        vm.expectRevert(ErrorsLib.ReserveBelowTargetRatio.selector);

        vm.prank(rebalancer);
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
    }

    function test_investInAsyncVault_revert_ComponentWithinTargetRange() public {
        _seedNode(10000 ether);

        vm.warp(block.timestamp + 1 days);

        allocation = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether, isComponent: true});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.startPrank(user);
        asset.approve(address(node), 1 ether);
        node.deposit(1 ether, address(user));
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.ComponentWithinTargetRange.selector, address(node), address(liquidityPool))
        );
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
    }

    function test_investInAsyncComponent_depositAmount_reducedToAvailableReserve() public {
        // Seed the node with 1000 ether
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        // Define component allocations
        allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether, isComponent: true});
        ComponentAllocation memory allocation20 =
            ComponentAllocation({targetWeight: 0.2 ether, maxDelta: 0.01 ether, isComponent: true});
        ComponentAllocation memory allocation70 =
            ComponentAllocation({targetWeight: 0.7 ether, maxDelta: 0.01 ether, isComponent: true});

        // Set up the environment as the owner
        vm.startPrank(owner);
        quoter.setErc4626(address(liquidityPool), true);
        quoter.setErc4626(address(testComponent70), true);
        node.addComponent(address(liquidityPool), allocation20);
        node.addComponent(address(testComponent70), allocation70);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        router4626.setWhitelistStatus(address(testComponent70), true);
        vm.stopPrank();

        // Invest in the component with 70% target weight
        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent70));
        vm.stopPrank();

        // Assert that the balance of the node is 700 ether for the component and 300 ether in reserve
        assertEq(testComponent70.balanceOf(address(node)), 700 ether);
        assertEq(asset.balanceOf(address(node)), 300 ether);

        vm.warp(block.timestamp + 1 days);

        // set both original component to 50% target weight
        vm.startPrank(owner);
        node.updateComponentAllocation(
            address(liquidityPool),
            ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether, isComponent: true})
        );
        node.updateComponentAllocation(
            address(testComponent70),
            ComponentAllocation({targetWeight: 0.4 ether, maxDelta: 0.01 ether, isComponent: true})
        );
        vm.stopPrank();

        // Calculate the investment size for the component with 50% target weight
        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(liquidityPool));

        // Attempt to invest in the component with 50% target weight
        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));

        // Assert that the balance of the node for the component is less than the calculated investment size
        assertLt(liquidityPool.balanceOf(address(node)), investmentSize);
        assertEq(liquidityPool.balanceOf(address(node)), 200 ether);
    }

    function test_investInAsyncComponent_fail_deposit_request_reverts() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        // Mock the requestDeposit call to revert
        vm.mockCall(
            address(liquidityPool),
            abi.encodeWithSelector(IERC7540Deposit.requestDeposit.selector),
            abi.encodePacked(bytes4(0)) // revert with no reason
        );

        vm.prank(rebalancer);
        vm.expectRevert();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
    }

    function test_investInAsyncComponent_fail_zero_request_id() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        // Mock requestDeposit to return non-zero request ID
        vm.mockCall(
            address(liquidityPool),
            abi.encodeWithSelector(IERC7540Deposit.requestDeposit.selector),
            abi.encode(1) // Return non-zero request ID
        );

        vm.startPrank(rebalancer);
        node.startRebalance();
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.IncorrectRequestId.selector, 1));
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();
    }

    function test_mintClaimableShares() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();
        assertEq(liquidityPool.claimableDepositRequest(0, address(node)), 90 ether);

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(90 ether));
    }

    function test_requestAsyncWithdrawal() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(90 ether));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
        vm.stopPrank();

        assertEq(liquidityPool.pendingRedeemRequest(0, address(node)), 10 ether);
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(80 ether));
    }

    function test_executeAsyncWithdrawal() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

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

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        // Setup: First create a deposit request
        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

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
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InsufficientSharesReturned.selector,
                address(liquidityPool),
                claimableShares - 1,
                claimableShares
            )
        );
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

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

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

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

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

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

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

    function test_requestAsyncWithdrawal_fail_nonzero_request_id() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        // First invest and mint shares
        vm.startPrank(rebalancer);
        node.startRebalance();
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));

        // Mock requestRedeem to return non-zero request ID
        vm.mockCall(
            address(liquidityPool),
            abi.encodeWithSelector(IERC7540Redeem.requestRedeem.selector),
            abi.encode(1) // Return non-zero request ID
        );

        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.IncorrectRequestId.selector, 1));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
    }

    function test_subtractExecutionFee_7540() public {
        address feeRecipient = makeAddr("feeRecipient");

        vm.startPrank(owner);
        registry.setProtocolExecutionFee(0.01 ether);
        registry.setProtocolFeeAddress(feeRecipient);
        vm.stopPrank();

        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        uint256 expectedDeposit =
            100 ether * uint256(node.getComponentAllocation(address(liquidityPool)).targetWeight) / 1 ether;

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 depositAmount = router7540.investInAsyncComponent(address(node), address(liquidityPool));
        vm.stopPrank();

        assertEq(asset.balanceOf(address(feeRecipient)) + depositAmount, expectedDeposit);
        assertEq(depositAmount, expectedDeposit * 0.99 ether / 1 ether);
        assertEq(asset.balanceOf(address(feeRecipient)), expectedDeposit * 0.01 ether / 1 ether);
        assertEq(liquidityPool.pendingDepositRequest(0, address(node)), depositAmount);
    }
}
