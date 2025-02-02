// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {BaseRouter} from "src/libraries/BaseRouter.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ComponentAllocation} from "src/interfaces/INode.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

contract ERC4626RouterHarness is ERC4626Router {
    constructor(address _registry) ERC4626Router(_registry) {}

    function getInvestmentSize(address node, address component) public view returns (uint256 depositAssets) {
        return super._getInvestmentSize(node, component);
    }
}

contract ERC4626RouterTest is BaseTest {
    ERC4626RouterHarness public testRouter;
    ERC4626Mock public testComponent;
    ERC4626Mock public testComponent70;

    ComponentAllocation public defaultTestAllocation;

    function setUp() public override {
        super.setUp();
        testRouter = new ERC4626RouterHarness(address(registry));
        testComponent = new ERC4626Mock(address(asset));
        testComponent70 = new ERC4626Mock(address(asset));

        defaultTestAllocation = ComponentAllocation({
            targetWeight: 0.9 ether,
            maxDelta: 0.01 ether,
            router: address(testRouter),
            isComponent: true
        });

        vm.warp(block.timestamp + 1 days);
        vm.prank(owner);
        node.updateComponentAllocation(address(vault), 0 ether, 0.01 ether, address(testRouter));
        vm.warp(block.timestamp - 1 days);
    }

    function test_getInvestmentSize() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        ComponentAllocation memory allocation50 = ComponentAllocation({
            targetWeight: 0.5 ether,
            maxDelta: 0.01 ether,
            router: address(testRouter),
            isComponent: true
        });

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(address(testComponent), allocation50.targetWeight, allocation50.maxDelta, allocation50.router);
        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));

        assertEq(node.getComponentAllocation(address(testComponent)).targetWeight, 0.5 ether);
        assertEq(testComponent.balanceOf(address(node)), 0);
        assertEq(investmentSize, 50 ether);
    }

    function test_invest() public {
        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        assertEq(testComponent.balanceOf(address(node)), investmentSize);
    }

    function test_invest_fail_not_rebalancer() public {
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();

        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();
    }

    function test_invest_fail_not_node() public {
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        router4626.invest(address(0), address(testComponent));
        vm.stopPrank();
    }

    function test_invest_fail_invalid_component() public {
        vm.warp(block.timestamp + 1 days);

        ERC4626Mock dummyComponent = new ERC4626Mock(address(asset));

        vm.startPrank(owner);
        // testComponent is not added to the node but is whitelisted and added to the quoter
        testRouter.setWhitelistStatus(address(testComponent), true);

        // dummyComponent is added to the node so component allocations = 100
        testRouter.setWhitelistStatus(address(dummyComponent), true);
        node.addComponent(
            address(dummyComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        vm.expectRevert(ErrorsLib.InvalidComponent.selector);
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();
    }

    function test_invest_revert_ComponentWithinTargetRange() public {
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        vm.startPrank(user);
        asset.approve(address(node), 1 ether);
        node.deposit(1 ether, address(user));
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.ComponentWithinTargetRange.selector, address(node), address(testComponent))
        );
        router4626.invest(address(node), address(testComponent));
    }

    function test_invest_revert_ReserveBelowTargetRatio() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, address(user));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        vm.startPrank(user);
        node.approve(address(node), 1 ether);
        node.requestRedeem(1 ether, address(user), address(user));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(address(user));

        vm.expectRevert(ErrorsLib.ReserveBelowTargetRatio.selector);

        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));
    }

    function test_invest_depositAmount_reducedToAvailableReserve() public {
        // Seed the node with 1000 ether
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        // Define component allocations
        ComponentAllocation memory allocation20 = ComponentAllocation({
            targetWeight: 0.2 ether,
            maxDelta: 0.01 ether,
            router: address(testRouter),
            isComponent: true
        });
        ComponentAllocation memory allocation70 = ComponentAllocation({
            targetWeight: 0.7 ether,
            maxDelta: 0.01 ether,
            router: address(testRouter),
            isComponent: true
        });

        // Set up the environment as the owner
        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        testRouter.setWhitelistStatus(address(testComponent70), true);
        node.addComponent(address(testComponent), allocation20.targetWeight, allocation20.maxDelta, allocation20.router);
        node.addComponent(
            address(testComponent70), allocation70.targetWeight, allocation70.maxDelta, allocation70.router
        );

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
        node.updateComponentAllocation(address(testComponent), 0.5 ether, 0.01 ether, address(testRouter));
        node.updateComponentAllocation(address(testComponent70), 0.4 ether, 0.01 ether, address(testRouter));
        vm.stopPrank();

        // Calculate the investment size for the component with 50% target weight
        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));

        // Attempt to invest in the component with 50% target weight
        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        // Assert that the balance of the node for the component is less than the calculated investment size
        assertLt(testComponent.balanceOf(address(node)), investmentSize);
        assertEq(testComponent.balanceOf(address(node)), 200 ether);
    }

    function test_invest_depositAmount_revert_ExceedsMaxVaultDeposit() public {
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        // Calculate the investment size for the component with 50% target weight
        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));

        vm.mockCall(
            address(testComponent),
            abi.encodeWithSelector(testComponent.maxDeposit.selector, address(node)),
            abi.encode(investmentSize - 1)
        );

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.ExceedsMaxComponentDeposit.selector,
                address(testComponent),
                investmentSize,
                investmentSize - 1
            )
        );
        router4626.invest(address(node), address(testComponent));
    }

    function test_invest_depositAmount_revert_InsufficientSharesReturned() public {
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));
        uint256 expectedShares = testComponent.previewDeposit(investmentSize);

        vm.mockCall(
            address(testComponent),
            abi.encodeWithSelector(testComponent.previewDeposit.selector, investmentSize),
            abi.encode(expectedShares + 1)
        );

        // reverts because returns shares less than previewDeposit shares
        vm.prank(rebalancer);
        vm.expectRevert();
        router4626.invest(address(node), address(testComponent));
    }

    function test_liquidate() public {
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        uint256 currentReserve = asset.balanceOf(address(node));
        assertEq(currentReserve, 100 ether);

        uint256 expectedAssets = testComponent.convertToAssets(100 ether);

        vm.prank(rebalancer);
        router4626.liquidate(address(node), address(testComponent), 100 ether);

        assertEq(currentReserve + expectedAssets, 200 ether);
    }

    function test_liquidate_revert_notRebalancer() public {
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        router4626.liquidate(address(node), address(testComponent), 100 ether);
        vm.stopPrank();
    }

    function test_liquidate_revert_invalidComponent() public {
        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidComponent.selector);
        router4626.liquidate(address(node), address(testComponent), 100 ether);
    }

    function test_liquidate_revert_notNode() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        router4626.liquidate(address(0), address(testComponent), 100 ether);
    }

    function test_liquidate_revert_zeroShareValue() public {
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidShareValue.selector, address(testComponent), 0));
        router4626.liquidate(address(node), address(testComponent), 0);
    }

    function test_liquidate_revert_InvalidShareValue() public {
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        uint256 shares = testComponent.balanceOf(address(node));
        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.InvalidShareValue.selector, address(testComponent), shares + 1)
        );
        router4626.liquidate(address(node), address(testComponent), shares + 1);
    }

    function test_liquidate_revert_InsufficientAssetsReturned() public {
        _seedNode(1000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        uint256 shares = testComponent.balanceOf(address(node));
        uint256 expectedAssets = testComponent.previewRedeem(shares);

        vm.mockCall(
            address(testComponent),
            abi.encodeWithSelector(testComponent.previewRedeem.selector, shares),
            abi.encode(expectedAssets + 100)
        );

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InsufficientAssetsReturned.selector,
                address(testComponent),
                expectedAssets,
                expectedAssets + 100
            )
        );
        router4626.liquidate(address(node), address(testComponent), shares);
    }

    function test_fulfillRedeemRequest_fullAmount() public {
        address[] memory components = node.getComponents();
        _userDeposits(user, 100 ether);
        deal(address(asset), address(user), 0);
        vm.warp(block.timestamp + 1 days);

        ComponentAllocation memory allocation50 =
            ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0, router: address(testRouter), isComponent: true});

        vm.startPrank(owner);
        node.setLiquidationQueue(components);
        node.updateTargetReserveRatio(0.5 ether);
        node.updateComponentAllocation(
            address(vault), allocation50.targetWeight, allocation50.maxDelta, allocation50.router
        );
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(vault));
        vm.stopPrank();

        vm.startPrank(user);
        node.approve(address(node), 50 ether);
        node.requestRedeem(50 ether, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.fulfillRedeemRequest(address(node), user, address(vault));

        assertEq(node.balanceOf(address(escrow)), 0);
        assertEq(node.balanceOf(user), 50 ether);
        assertEq(node.totalAssets(), 50 ether);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(address(escrow)), 50 ether);
        assertEq(asset.balanceOf(address(node)), 50 ether);

        vm.prank(user);
        node.withdraw(50 ether, user, user);

        assertEq(node.pendingRedeemRequest(0, user), 0);
        assertEq(node.claimableRedeemRequest(0, user), 0);
        assertEq(node.balanceOf(user), 50 ether);
        assertEq(asset.balanceOf(address(node)), 50 ether);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(asset.balanceOf(address(user)), 50 ether);
    }

    function test_fulfillRedeemRequest_partialAmount() public {
        address[] memory components = node.getComponents();
        _userDeposits(user, 100 ether);

        vm.warp(block.timestamp + 1 days);

        deal(address(asset), address(user), 0);
        vm.warp(block.timestamp + 1 days);

        ComponentAllocation memory allocation30 =
            ComponentAllocation({targetWeight: 0.3 ether, maxDelta: 0, router: address(testRouter), isComponent: true});

        vm.startPrank(owner);
        node.setLiquidationQueue(components);
        node.updateTargetReserveRatio(0.7 ether);
        node.updateComponentAllocation(
            address(vault), allocation30.targetWeight, allocation30.maxDelta, allocation30.router
        );
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(vault));
        vm.stopPrank();

        vm.startPrank(user);
        node.approve(address(node), 50 ether);
        node.requestRedeem(50 ether, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        uint256 assetsReturned = router4626.fulfillRedeemRequest(address(node), user, address(vault));
        assertEq(assetsReturned, 30 ether);

        assertEq(node.balanceOf(address(escrow)), 20 ether);
        assertEq(node.balanceOf(user), 50 ether);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(address(escrow)), 30 ether);
        assertEq(node.claimableRedeemRequest(0, user), 30 ether);
        assertEq(node.pendingRedeemRequest(0, user), 20 ether);

        vm.prank(user);
        node.withdraw(30 ether, user, user);

        assertEq(asset.balanceOf(address(user)), 30 ether);
        assertEq(asset.balanceOf(address(escrow)), 0);
        assertEq(node.claimableRedeemRequest(0, user), 0);
        assertEq(node.pendingRedeemRequest(0, user), 20 ether);
    }

    function test_subtractExecutionFee_4626() public {
        address feeRecipient = makeAddr("feeRecipient");

        vm.startPrank(owner);
        registry.setProtocolExecutionFee(0.01 ether);
        registry.setProtocolFeeAddress(feeRecipient);
        vm.stopPrank();

        _seedNode(100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        testRouter.setWhitelistStatus(address(testComponent), true);
        node.addComponent(
            address(testComponent),
            defaultTestAllocation.targetWeight,
            defaultTestAllocation.maxDelta,
            defaultTestAllocation.router
        );

        vm.stopPrank();

        uint256 expectedDeposit =
            100 ether * uint256(node.getComponentAllocation(address(testComponent)).targetWeight) / 1 ether;

        vm.startPrank(rebalancer);
        node.startRebalance();
        uint256 depositAmount = router4626.invest(address(node), address(testComponent));
        vm.stopPrank();

        assertEq(asset.balanceOf(address(feeRecipient)) + depositAmount, expectedDeposit);
        assertEq(depositAmount, expectedDeposit * 0.99 ether / 1 ether);
        assertEq(asset.balanceOf(address(feeRecipient)), expectedDeposit * 0.01 ether / 1 ether);
    }

    function test_isWhitelisted() public {
        vm.startPrank(owner);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        assertEq(router4626.isWhitelisted(address(testComponent)), true);
    }
}
