// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OneInchV6RouterV1} from "src/routers/OneInchV6RouterV1.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {IAggregationRouterV6} from "src/interfaces/IAggregationRouterV6.sol";

import {BaseTest} from "test/BaseTest.sol";

import {console} from "forge-std/console.sol";

contract OneInchV6RouterV1Test is BaseTest {
    OneInchV6RouterV1 oneInchRouter;

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

        oneInchRouter = new OneInchV6RouterV1(address(registry));
        // whitelist oneInchRouter
        vm.startPrank(owner);
        registry.setRegistryType(address(oneInchRouter), RegistryType.ROUTER, true);
        node.addRouter(address(oneInchRouter));
        // set execution fee to 10%
        registry.setProtocolExecutionFee(1e17);
    }

    function test_set_incentive_whitelist_status_fail() external {
        vm.startPrank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        oneInchRouter.setIncentiveWhitelistStatus(incentive, true);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        oneInchRouter.setIncentiveWhitelistStatus(address(0), true);
        vm.stopPrank();
    }

    function test_set_incentive_whitelist_status_success() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit OneInchV6RouterV1.IncentiveWhitelisted(incentive, true);
        oneInchRouter.setIncentiveWhitelistStatus(incentive, true);
    }

    function test_set_executor_whitelist_status_fail() external {
        vm.startPrank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        oneInchRouter.setExecutorWhitelistStatus(executor, true);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        oneInchRouter.setExecutorWhitelistStatus(address(0), true);
        vm.stopPrank();
    }

    function test_set_executor_whitelist_status_success() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit OneInchV6RouterV1.ExecutorWhitelisted(executor, true);
        oneInchRouter.setExecutorWhitelistStatus(executor, true);
    }

    function test_swap_fail_invalid_node() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        oneInchRouter.swap(
            address(incentive), address(incentive), incentiveAmount, minReturnAmount, executor, swapCalldata
        );
    }

    function test_swap_fail_only_rebalancer() external {
        vm.startPrank(randomUser);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        oneInchRouter.swap(address(node), address(incentive), incentiveAmount, minReturnAmount, executor, swapCalldata);
    }

    function test_swap_fail_forbidden_to_swap_underlying() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6RouterV1.IncentiveIsAsset.selector);
        oneInchRouter.swap(address(node), address(asset), incentiveAmount, minReturnAmount, executor, swapCalldata);
    }

    function test_swap_fail_forbidden_to_swap_component_share() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6RouterV1.IncentiveIsComponent.selector);
        oneInchRouter.swap(address(node), address(vault), incentiveAmount, minReturnAmount, executor, swapCalldata);
    }

    function test_swap_fail_incentive_not_whitelisted() external {
        deal(incentive, address(node), incentiveAmount);

        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6RouterV1.IncentiveNotWhitelisted.selector);
        oneInchRouter.swap(address(node), address(incentive), incentiveAmount, minReturnAmount, executor, swapCalldata);
    }

    function test_swap_fail_executor_not_whitelisted() external {
        deal(incentive, address(node), incentiveAmount);

        vm.startPrank(owner);
        oneInchRouter.setIncentiveWhitelistStatus(incentive, true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6RouterV1.ExecutorNotWhitelisted.selector);
        oneInchRouter.swap(address(node), address(incentive), incentiveAmount, minReturnAmount, executor, swapCalldata);
    }

    function test_swap_fail_incentive_not_sufficient_amount() external {
        deal(incentive, address(node), incentiveAmount);

        vm.startPrank(owner);
        oneInchRouter.setIncentiveWhitelistStatus(incentive, true);
        oneInchRouter.setExecutorWhitelistStatus(executor, true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        vm.expectRevert(OneInchV6RouterV1.IncentiveInsufficientAmount.selector);
        oneInchRouter.swap(
            address(node), address(incentive), incentiveAmount + 1, minReturnAmount, executor, swapCalldata
        );
    }

    function test_swap_fail_incentive_incomplete_swap() external {
        deal(incentive, address(node), incentiveAmount);

        vm.startPrank(owner);
        oneInchRouter.setIncentiveWhitelistStatus(incentive, true);
        oneInchRouter.setExecutorWhitelistStatus(executor, true);
        vm.stopPrank();

        // to have a non zero cacheAssets and prevent underflow on _subtractExecutionFee
        vm.startPrank(user);
        asset.approve(address(node), 10e6);
        node.deposit(10e6, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);

        uint256 fee = actualReturnAmount / 10;

        vm.mockCall(
            oneInchRouter.ONE_INCH_AGGREGATION_ROUTER_V6(),
            abi.encodeWithSelector(IAggregationRouterV6.swap.selector),
            abi.encode(1000e6, 500e6)
        );
        vm.expectRevert(OneInchV6RouterV1.IncentiveIncompleteSwap.selector);
        oneInchRouter.swap(address(node), incentive, incentiveAmount, minReturnAmount, executor, swapCalldata);
    }

    function test_swap_success() external {
        deal(incentive, address(node), incentiveAmount);

        vm.startPrank(owner);
        oneInchRouter.setIncentiveWhitelistStatus(incentive, true);
        oneInchRouter.setExecutorWhitelistStatus(executor, true);
        vm.stopPrank();

        // to have a non zero cacheAssets and prevent underflow on _subtractExecutionFee
        vm.startPrank(user);
        asset.approve(address(node), 10e6);
        node.deposit(10e6, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);

        uint256 fee = actualReturnAmount / 10;

        vm.expectEmit(true, true, true, true);
        emit OneInchV6RouterV1.Compounded(
            address(node), address(incentive), incentiveAmount, actualReturnAmount, actualReturnAmount - fee
        );
        oneInchRouter.swap(address(node), incentive, incentiveAmount, minReturnAmount, executor, swapCalldata);
    }
}
