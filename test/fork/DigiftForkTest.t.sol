// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";
import {DigiftWrapper} from "src/wrappers/DigiftWrapper.sol";
import {ISubRedManagement, IDFeedPriceOracle, IManagement} from "src/interfaces/external/IDigift.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {IERC7540Deposit} from "src/interfaces/IERC7540.sol";

contract DigiftForkTest is BaseTest {
    DigiftWrapper digiftWrapper;
    uint256 DEPOSIT_AMOUNT = 1000e6;
    uint64 ALLOCATION = 0.9 ether;

    ISubRedManagement constant subRedManagement = ISubRedManagement(0x3DAd21A73a63bBd186f57f733d271623467b6c78);
    IDFeedPriceOracle constant dFeedPriceOracle = IDFeedPriceOracle(0x67aE0CAAC7f6995d8B24d415F584e5625cdEe048);
    IERC20 constant stToken = IERC20(0x37EC21365dC39B0b74ea7b6FabFfBcB277568AC4);

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 375510069);
        super.setUp();

        _userDeposits(user, DEPOSIT_AMOUNT);

        // warp forward to ensure not rebalancing
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        // remove mock ERC4626 vault
        node.removeComponent(address(vault), false);
        vm.stopPrank();

        digiftWrapper = new DigiftWrapper(
            address(asset),
            address(stToken),
            address(subRedManagement),
            address(dFeedPriceOracle),
            address(registry),
            "stToken Wrapper",
            "wst"
        );

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(digiftWrapper), true);
        node.addRouter(address(router7540));
        node.addComponent(address(digiftWrapper), ALLOCATION, 0.01 ether, address(router7540));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();

        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isWhiteInvestor.selector, address(digiftWrapper)),
            abi.encode(true)
        );
    }

    function _invest() internal returns (uint256) {
        vm.startPrank(rebalancer);
        uint256 depositAmount = router7540.investInAsyncComponent(address(node), address(digiftWrapper));
        vm.stopPrank();
        return depositAmount;
    }

    function test_investInAsyncComponent_success() external {
        uint256 balance = asset.balanceOf(address(node));

        uint256 toInvest = balance * ALLOCATION / 1e18;

        vm.expectEmit(true, true, true, true, address(subRedManagement));
        emit ISubRedManagement.Subscribe(
            address(subRedManagement), address(stToken), address(asset), address(digiftWrapper), toInvest
        );
        vm.expectEmit(true, true, true, true, address(digiftWrapper));
        emit IERC7540Deposit.DepositRequest(address(node), address(node), 0, address(node), toInvest);
        uint256 depositAmount = _invest();
        assertEq(depositAmount, toInvest, "Invested according to allocation");

        assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), toInvest);

        vm.startPrank(address(node));
        assertEq(router7540.getComponentAssets(address(digiftWrapper), false), toInvest);
        vm.stopPrank();

        assertEq(node.totalAssets(), balance);

        vm.startPrank(rebalancer);
        node.updateTotalAssets();
        vm.stopPrank();

        assertEq(node.totalAssets(), balance);
    }
}
