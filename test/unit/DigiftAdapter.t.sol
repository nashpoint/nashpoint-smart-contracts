// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftAdapterFactory} from "src/adapters/digift/DigiftAdapterFactory.sol";
import {DigiftAdapter} from "src/adapters/digift/DigiftAdapter.sol";
import {ISubRedManagement, IDFeedPriceOracle, IManagement, ISecurityToken} from "src/interfaces/external/IDigift.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {INode} from "src/interfaces/INode.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract DigiftAdapterHarness is DigiftAdapter {
    constructor(address subRedManagement_, address registry_, address digiftEventVerifier_)
        DigiftAdapter(subRedManagement_, registry_, digiftEventVerifier_)
    {}

    function getAssetPrice() external view returns (uint256) {
        return _getAssetPrice();
    }
}

contract DigiftForkTest is BaseTest {
    DigiftAdapterHarness digiftAdapter;
    address digiftEventVerifier = makeAddr("digiftEventVerifier");

    uint256 DEPOSIT_AMOUNT = 1000e6;
    uint64 ALLOCATION = 0.9 ether;
    uint256 INVEST_AMOUNT = DEPOSIT_AMOUNT * ALLOCATION / 1e18;

    address manager = makeAddr("manager");

    address usdcPriceOracle = makeAddr("usdcPriceOracle");

    address subRedManagement = makeAddr("subRedManagement");
    address dFeedPriceOracle = makeAddr("dFeedPriceOracle");
    address stToken = makeAddr("stToken");

    function setUp() public override {
        super.setUp();

        _userDeposits(user, DEPOSIT_AMOUNT);

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(owner);
        // remove mock ERC4626 vault
        node.removeComponent(address(vault), false);
        vm.stopPrank();

        address digiftAdapterImpl =
            address(new DigiftAdapterHarness(subRedManagement, address(registry), digiftEventVerifier));

        DigiftAdapterFactory factory = new DigiftAdapterFactory(digiftAdapterImpl, address(this));

        vm.mockCall(usdcPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(dFeedPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(address(asset), abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(6));
        vm.mockCall(address(stToken), abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(18));
        vm.mockCall(dFeedPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.getPrice.selector), abi.encode(2e10));

        digiftAdapter = DigiftAdapterHarness(
            address(
                factory.deploy(
                    DigiftAdapter.InitArgs(
                        "stToken Adapter",
                        "wst",
                        address(asset),
                        usdcPriceOracle,
                        address(stToken),
                        address(dFeedPriceOracle),
                        // 0.1%
                        1e15,
                        // 1%
                        1e16,
                        4 days,
                        4 days,
                        1000e6,
                        10e18
                    )
                )
            )
        );

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(digiftAdapter), true);
        node.addRouter(address(router7540));
        node.addComponent(address(digiftAdapter), ALLOCATION, 0.01 ether, address(router7540));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();
    }

    function test_setPriceDeviation() external {
        assertEq(digiftAdapter.priceDeviation(), 1e15);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setPriceDeviation(1);

        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.InvalidPercentage.selector));
        digiftAdapter.setPriceDeviation(1e19);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.PriceDeviationChange(1e15, 1e17);
        digiftAdapter.setPriceDeviation(1e17);

        assertEq(digiftAdapter.priceDeviation(), 1e17);
    }

    function test_setSettlementDeviation() external {
        assertEq(digiftAdapter.settlementDeviation(), 1e16);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setSettlementDeviation(1);

        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.InvalidPercentage.selector));
        digiftAdapter.setSettlementDeviation(1e19);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.SettlementDeviationChange(1e16, 1e17);
        digiftAdapter.setSettlementDeviation(1e17);

        assertEq(digiftAdapter.settlementDeviation(), 1e17);
    }

    function test_setPriceUpdateDeviationDigift() external {
        assertEq(digiftAdapter.priceUpdateDeviationDigift(), 4 days);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setPriceUpdateDeviationDigift(1 days);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.PriceUpdateDeviationChangeDigift(4 days, 1 days);
        digiftAdapter.setPriceUpdateDeviationDigift(1 days);

        assertEq(digiftAdapter.priceUpdateDeviationDigift(), 1 days);
    }

    function test_setPriceUpdateDeviationAsset() external {
        assertEq(digiftAdapter.priceUpdateDeviationAsset(), 4 days);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setPriceUpdateDeviationAsset(1 days);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.PriceUpdateDeviationChangeAsset(4 days, 1 days);
        digiftAdapter.setPriceUpdateDeviationAsset(1 days);

        assertEq(digiftAdapter.priceUpdateDeviationAsset(), 1 days);
    }

    function test_setManager() external {
        assertEq(digiftAdapter.managerWhitelisted(manager), false);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setManager(manager, true);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.ManagerWhitelistChange(manager, true);
        digiftAdapter.setManager(manager, true);

        assertEq(digiftAdapter.managerWhitelisted(manager), true);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.ManagerWhitelistChange(manager, false);
        digiftAdapter.setManager(manager, false);

        assertEq(digiftAdapter.managerWhitelisted(manager), false);
    }

    function test_setNode() external {
        assertEq(digiftAdapter.nodeWhitelisted(address(node)), false);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setNode(address(node), true);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.NodeWhitelistChange(address(node), true);
        digiftAdapter.setNode(address(node), true);

        assertEq(digiftAdapter.nodeWhitelisted(address(node)), true);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.NodeWhitelistChange(address(node), false);
        digiftAdapter.setNode(address(node), false);

        assertEq(digiftAdapter.nodeWhitelisted(address(node)), false);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotNode.selector));
        digiftAdapter.setNode(address(0x1234), true);
    }

    function test_setMinDepositAmount() external {
        assertEq(digiftAdapter.minDepositAmount(), 1000e6);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setMinDepositAmount(2000e6);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.MinDepositAmountChange(1000e6, 2000e6);
        digiftAdapter.setMinDepositAmount(2000e6);

        assertEq(digiftAdapter.minDepositAmount(), 2000e6);

        vm.stopPrank();
    }

    function test_setMinRedeemAmount() external {
        assertEq(digiftAdapter.minRedeemAmount(), 10e18);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setMinRedeemAmount(20e18);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.MinRedeemAmountChange(10e18, 20e18);
        digiftAdapter.setMinRedeemAmount(20e18);

        assertEq(digiftAdapter.minRedeemAmount(), 20e18);

        vm.stopPrank();
    }

    function test_forceUpdateLastPrice() external {
        assertEq(digiftAdapter.lastDigiftPrice(), 2e10);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.forceUpdateLastPrice();

        vm.mockCall(dFeedPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.getPrice.selector), abi.encode(3e10));

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.LastPriceUpdate(3e10);
        digiftAdapter.forceUpdateLastPrice();

        assertEq(digiftAdapter.lastDigiftPrice(), 3e10);
    }

    function test_updateLastPrice() external {
        vm.prank(owner);
        digiftAdapter.setManager(manager, true);

        uint256 newValidPrice = 2e10 + 1;

        assertEq(digiftAdapter.lastDigiftPrice(), 2e10);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotManager.selector, address(this)));
        digiftAdapter.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, newValidPrice, 0, block.timestamp, 0)
        );

        vm.startPrank(manager);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.LastPriceUpdate(newValidPrice);
        digiftAdapter.updateLastPrice();

        assertEq(digiftAdapter.lastDigiftPrice(), newValidPrice);

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 0, 0, block.timestamp, 0)
        );
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.BadPriceOracle.selector, dFeedPriceOracle));
        digiftAdapter.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, newValidPrice, 0, block.timestamp - 5 days, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(DigiftAdapter.StalePriceData.selector, block.timestamp - 5 days, block.timestamp)
        );
        digiftAdapter.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 30e13, 0, block.timestamp, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(DigiftAdapter.PriceNotInRange.selector, digiftAdapter.lastDigiftPrice(), 30e13)
        );
        digiftAdapter.updateLastPrice();
    }

    function test_getAssetPrice() external {
        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 1e8, 0, block.timestamp, 0)
        );
        assertEq(digiftAdapter.getAssetPrice(), 1e8);

        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 0, 0, block.timestamp, 0)
        );
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.BadPriceOracle.selector, usdcPriceOracle));
        digiftAdapter.getAssetPrice();

        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 1e8, 0, block.timestamp - 5 days, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(DigiftAdapter.StalePriceData.selector, block.timestamp - 5 days, block.timestamp)
        );
        digiftAdapter.getAssetPrice();
    }

    function test_onlyManager() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotManager.selector, address(this)));
        digiftAdapter.updateLastPrice();

        DigiftEventVerifier.OffchainArgs memory offchainArgs;

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotManager.selector, address(this)));
        digiftAdapter.settleDeposit(new address[](0), offchainArgs);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotManager.selector, address(this)));
        digiftAdapter.settleRedeem(new address[](0), offchainArgs);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotManager.selector, address(this)));
        digiftAdapter.forwardRequestsToDigift();
    }

    function test_onlyWhitelistedNode() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.requestDeposit(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.mint(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.requestRedeem(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.withdraw(1, address(this), address(this));
    }
}
