// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OneInchV6Router} from "src/routers/OneInchV6Router.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";

import {BaseTest} from "test/BaseTest.sol";

import {console} from "forge-std/console.sol";

contract OneInchV6RouterTest is BaseTest {
    OneInchV6Router oneInchRouter;

    // https://arbiscan.io/tx/0x379b2163be1da23a064e7b7f941766384e6195379baf494dd047a934a5f36dee
    // ARB
    address incentive = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address executor = 0xde9e4FE32B049f821c7f3e9802381aa470FFCA73;
    uint256 incentiveAmount = 9998453452942351577;
    uint256 minReturnAmount = 5045087;
    bytes swapCalldata =
        hex"0000000000000000000000000000000000000000000000000000b100004e00a0744c8c09912ce59144191c1204e64559fe8253a0e49e654839041f1b366fe33f9a5a79de5120f2aee2577ebc0000000000000000000000000000000000000000000000000058cdd9e1ea2e2602a000000000000000000000000000000000000000000000000000000000004cfb5fee63c1e581b0f6ca40411360c03d41c5ffc5f179b8403cdcf8912ce59144191c1204e64559fe8253a0e49e6548111111125421ca6dc452d289314280a0f8842a65";
    uint256 actualReturnAmount = 5192380;

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        vm.createSelectFork(ARBITRUM_RPC_URL, 368629098);
        super.setUp();

        oneInchRouter = new OneInchV6Router(address(registry));
        // whitelist oneInchRouter
        vm.startPrank(owner);
        registry.setRegistryType(address(oneInchRouter), RegistryType.ROUTER, true);
        node.addRouter(address(oneInchRouter));
        // set execution fee to 10%
        registry.setProtocolExecutionFee(1e17);
    }

    // function _encodeSwap(uint256 amountIn, uint256 amountOut, address receiver) internal view returns (bytes memory) {
    //     return abi.encodeWithSelector(
    //         OneInchMock.swap.selector, address(incentive), address(asset), amountIn, amountOut, receiver
    //     );
    // }

    // function test_swap_fail_invalid_node() external {
    //     vm.startPrank(rebalancer);
    //     vm.expectRevert(ErrorsLib.InvalidNode.selector);
    //     oneInchRouter.swap(address(incentive), address(incentive), "");
    // }

    // function test_swap_fail_only_rebalancer() external {
    //     vm.startPrank(randomUser);
    //     vm.expectRevert(ErrorsLib.NotRebalancer.selector);
    //     oneInchRouter.swap(address(node), address(incentive), "");
    // }

    // function test_swap_fail_forbidden_to_swap_underlying() external {
    //     vm.startPrank(rebalancer);
    //     vm.expectRevert(OneInchV6Router.ForbiddenToSwap.selector);
    //     oneInchRouter.swap(address(node), address(asset), "");
    // }

    // function test_swap_fail_forbidden_to_swap_component_share() external {
    //     vm.startPrank(rebalancer);
    //     vm.expectRevert(OneInchV6Router.ForbiddenToSwap.selector);
    //     oneInchRouter.swap(address(node), address(vault), "");
    // }

    // function test_swap_fail_no_incentive() external {
    //     vm.startPrank(rebalancer);
    //     vm.expectRevert(OneInchV6Router.ZeroValueSwap.selector);
    //     oneInchRouter.swap(address(node), address(incentive), "");
    // }

    // function test_swap_fail_router_have_not_received_underlying() external {
    //     incentive.mint(address(node), 1000e18);

    //     vm.startPrank(rebalancer);
    //     vm.expectRevert(OneInchV6Router.ZeroValueSwap.selector);
    //     oneInchRouter.swap(address(node), address(incentive), _encodeSwap(1000e18, 1100e18, randomUser));
    // }

    // function test_swap_fail_incomplete_incentive_swap() external {
    //     incentive.mint(address(node), 1000e18);

    //     vm.startPrank(rebalancer);
    //     vm.expectRevert(OneInchV6Router.IncompleteIncentiveSwap.selector);
    //     oneInchRouter.swap(address(node), address(incentive), _encodeSwap(1000e18 - 1, 1100e18, address(oneInchRouter)));
    // }

    // function test_swap_fail_node_balance_remains_unchanged() public {
    //     incentive.mint(address(node), 1000e18);

    //     vm.mockCall(
    //         address(asset),
    //         abi.encodeWithSignature("balanceOf(address)", address(node)),
    //         abi.encode(asset.balanceOf(address(node)))
    //     );

    //     vm.startPrank(rebalancer);
    //     vm.expectRevert(OneInchV6Router.ZeroValueSwap.selector);
    //     oneInchRouter.swap(address(node), address(incentive), _encodeSwap(1000e18, 1100e18, address(oneInchRouter)));

    //     vm.clearMockedCalls();
    // }

    function test_swap_success() external {
        deal(incentive, address(node), incentiveAmount);

        vm.startPrank(owner);
        oneInchRouter.setExecutorWhitelistStatus(executor, true);
        oneInchRouter.setIncentiveWhitelistStatus(incentive, true);
        vm.stopPrank();

        // to have a non zero cacheAssets and prevent underflow on _subtractExecutionFee
        vm.startPrank(user);
        asset.approve(address(node), 10e6);
        node.deposit(10e6, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);

        uint256 fee = actualReturnAmount / 10;

        vm.expectEmit(true, true, true, true);
        emit OneInchV6Router.Compounded(
            address(node), address(incentive), incentiveAmount, actualReturnAmount, actualReturnAmount - fee
        );
        oneInchRouter.swap(address(node), incentive, incentiveAmount, minReturnAmount, executor, swapCalldata);
    }
}
