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

    function setUp() public override {
        super.setUp();
        testRouter = new ERC4626RouterHarness(address(registry));
        testComponent = new ERC4626Mock(address(asset));
        testComponent70 = new ERC4626Mock(address(asset));
    }

    function test_getInvestmentSize() public {
        _seedNode(100 ether);
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));

        assertEq(node.getComponentRatio(address(testComponent)), 0.5 ether);
        assertEq(testComponent.balanceOf(address(node)), 0);
        assertEq(investmentSize, 50 ether);
    }

    function test_invest() public {
        _seedNode(100 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));

        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));

        assertEq(testComponent.balanceOf(address(node)), investmentSize);
    }

    function test_invest_fail_not_whitelisted() public {
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        _seedNode(100 ether);
        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        router4626.invest(address(node), address(testComponent));
    }

    function test_invest_fail_not_rebalancer() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        router4626.invest(address(node), address(testComponent));
    }

    function test_invest_fail_not_node() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        router4626.invest(address(0), address(testComponent));
    }

    function test_invest_fail_invalid_component() public {
        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidComponent.selector);
        router4626.invest(address(node), address(testComponent));
    }

    function test_invest_revert_ComponentWithinTargetRange() public {
        _seedNode(1000 ether);
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));

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

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));

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

        // todo: do this with more realistic allocation values later that all sum to 100%

        // Define component allocations
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});
        ComponentAllocation memory allocation70 = ComponentAllocation({targetWeight: 0.7 ether, maxDelta: 0.01 ether});

        // Set up the environment as the owner
        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        quoter.setErc4626(address(testComponent70), true);
        node.addComponent(address(testComponent), allocation);
        node.addComponent(address(testComponent70), allocation70);
        router4626.setWhitelistStatus(address(testComponent), true);
        router4626.setWhitelistStatus(address(testComponent70), true);
        vm.stopPrank();

        // Invest in the component with 70% target weight
        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent70));

        // Assert that the balance of the node is 700 ether for the component and 300 ether in reserve
        assertEq(testComponent70.balanceOf(address(node)), 700 ether);
        assertEq(asset.balanceOf(address(node)), 300 ether);

        // Calculate the investment size for the component with 50% target weight
        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(testComponent));

        // Attempt to invest in the component with 50% target weight
        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));

        // Assert that the balance of the node for the component is less than the calculated investment size
        assertLt(testComponent.balanceOf(address(node)), investmentSize);
        assertEq(testComponent.balanceOf(address(node)), 200 ether);
    }

    function test_invest_depositAmount_revert_ExceedsMaxVaultDeposit() public {
        _seedNode(1000 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
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
                ErrorsLib.ExceedsMaxVaultDeposit.selector, address(testComponent), investmentSize, investmentSize - 1
            )
        );
        router4626.invest(address(node), address(testComponent));
    }

    function test_invest_depositAmount_revert_InsufficientSharesReturned() public {
        _seedNode(1000 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
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

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));

        uint256 currentReserve = asset.balanceOf(address(node));
        assertEq(currentReserve, 500 ether);

        uint256 expectedAssets = testComponent.convertToAssets(100 ether);

        vm.prank(rebalancer);
        router4626.liquidate(address(node), address(testComponent), 100 ether);

        assertEq(currentReserve + expectedAssets, 600 ether);
    }

    function test_liquidate_revert_notRebalancer() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        router4626.liquidate(address(node), address(testComponent), 100 ether);
    }

    function test_liquidate_revert_notWhitelisted() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        router4626.liquidate(address(node), address(testComponent), 100 ether);
    }

    function test_liquidate_revert_invalidComponent() public {
        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        router4626.setWhitelistStatus(address(testComponent), true);
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

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidShareValue.selector, address(testComponent), 0));
        router4626.liquidate(address(node), address(testComponent), 0);
    }

    function test_liquidate_revert_InvalidShareValue() public {
        _seedNode(1000 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));

        uint256 shares = testComponent.balanceOf(address(node));
        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.InvalidShareValue.selector, address(testComponent), shares + 1)
        );
        router4626.liquidate(address(node), address(testComponent), shares + 1);
    }

    function test_liquidate_revert_InsufficientAssetsReturned() public {
        _seedNode(1000 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        router4626.setWhitelistStatus(address(testComponent), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.invest(address(node), address(testComponent));

        uint256 shares = testComponent.balanceOf(address(node));
        uint256 expectedAssets = testComponent.previewRedeem(shares);

        vm.mockCall(
            address(testComponent),
            abi.encodeWithSelector(testComponent.previewRedeem.selector, shares),
            abi.encode(expectedAssets + 1)
        );

        vm.prank(rebalancer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InsufficientAssetsReturned.selector,
                address(testComponent),
                expectedAssets,
                expectedAssets + 1
            )
        );
        router4626.liquidate(address(node), address(testComponent), shares);
    }
}
