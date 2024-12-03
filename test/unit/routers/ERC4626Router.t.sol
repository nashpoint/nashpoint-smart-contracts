// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
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

    function setUp() public override {
        super.setUp();
        testRouter = new ERC4626RouterHarness(address(registry));
        testComponent = new ERC4626Mock(address(asset));
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
        // Setup initial conditions
        _seedNode(1000 ether);
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether, // 50%
            maxDelta: 0.01 ether // 1%
        });

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

    function test_invest_depositAmount_equals_availableReserve() public {}

    function test_invest_depositAmount_revert_ExceedsMaxVaultDeposit() public {}

    function test_invest_depositAmount_revert_InsufficientSharesReturned() public {}
}
