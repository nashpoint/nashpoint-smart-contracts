// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OneInchV6Router} from "src/routers/OneInchV6Router.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";

import {BaseTest} from "test/BaseTest.sol";
import {OneInchMock} from "test/mocks/OneInchMock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract OneInchV6RouterTest is BaseTest {
    OneInchV6Router oneInchRouter;
    ERC20Mock incentive;

    function setUp() public override {
        super.setUp();

        oneInchRouter = new OneInchV6Router(address(registry));
        OneInchMock impl = new OneInchMock();
        vm.etch(oneInchRouter.ONE_INCH_V6(), address(impl).code);
        incentive = new ERC20Mock("Super Incentive", "SUP-INC");
        // provide liquidity into mocked one inch contract
        ERC20Mock(address(asset)).mint(oneInchRouter.ONE_INCH_V6(), 1000_000e18);
        // whitelist oneInchRouter
        vm.startPrank(owner);
        registry.setRegistryType(address(oneInchRouter), RegistryType.ROUTER, true);
        node.addRouter(address(oneInchRouter));
        // set execution fee to 10%
        registry.setProtocolExecutionFee(1e17);
    }

    function _encodeSwap(uint256 amountIn, uint256 amountOut, address receiver) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            OneInchMock.swap.selector, address(incentive), address(asset), amountIn, amountOut, receiver
        );
    }

    function test_swap_fail_invalid_node() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        oneInchRouter.swap(address(incentive), address(incentive), "");
    }

    function test_swap_fail_only_rebalancer() external {
        vm.startPrank(randomUser);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        oneInchRouter.swap(address(node), address(incentive), "");
    }

    function test_swap_fail_forbidden_to_swap_underlying() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6Router.ForbiddenToSwap.selector);
        oneInchRouter.swap(address(node), address(asset), "");
    }

    function test_swap_fail_forbidden_to_swap_component_share() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6Router.ForbiddenToSwap.selector);
        oneInchRouter.swap(address(node), address(vault), "");
    }

    function test_swap_fail_no_incentive() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6Router.ZeroValueSwap.selector);
        oneInchRouter.swap(address(node), address(incentive), "");
    }

    function test_swap_fail_router_have_not_received_underlying() external {
        incentive.mint(address(node), 1000e18);

        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6Router.ZeroValueSwap.selector);
        oneInchRouter.swap(address(node), address(incentive), _encodeSwap(1000e18, 1100e18, randomUser));
    }

    function test_swap_fail_incomplete_incentive_swap() external {
        incentive.mint(address(node), 1000e18);

        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6Router.IncompleteIncentiveSwap.selector);
        oneInchRouter.swap(address(node), address(incentive), _encodeSwap(1000e18 - 1, 1100e18, address(oneInchRouter)));
    }

    function test_swap_fail_node_balance_remains_unchanged() public {
        incentive.mint(address(node), 1000e18);

        vm.mockCall(
            address(asset),
            abi.encodeWithSignature("balanceOf(address)", address(node)),
            abi.encode(asset.balanceOf(address(node)))
        );

        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6Router.ZeroValueSwap.selector);
        oneInchRouter.swap(address(node), address(incentive), _encodeSwap(1000e18, 1100e18, address(oneInchRouter)));

        vm.clearMockedCalls();
    }

    function test_swap_success() external {
        uint256 incentiveAmount = 1000e18;
        uint256 compoundedAssetsAmount = 2000e18;

        incentive.mint(address(node), incentiveAmount);

        vm.startPrank(rebalancer);

        uint256 fee = compoundedAssetsAmount / 10;

        vm.expectEmit(true, true, true, true);
        emit OneInchV6Router.Compounded(
            address(node), address(incentive), incentiveAmount, compoundedAssetsAmount - fee, fee
        );
        oneInchRouter.swap(
            address(node),
            address(incentive),
            _encodeSwap(incentiveAmount, compoundedAssetsAmount, address(oneInchRouter))
        );
    }
}
