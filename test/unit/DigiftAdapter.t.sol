// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftAdapterFactory} from "src/adapters/digift/DigiftAdapterFactory.sol";
import {DigiftAdapter} from "src/adapters/digift/DigiftAdapter.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {ISubRedManagement, IManagement, ISecurityToken} from "src/interfaces/external/IDigift.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {IPriceOracle} from "src/interfaces/external/IPriceOracle.sol";
import {INode} from "src/interfaces/INode.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract DigiftAdapterHarness is DigiftAdapter {
    constructor(address registry_, address subRedManagement_, address digiftEventVerifier_)
        DigiftAdapter(registry_, subRedManagement_, digiftEventVerifier_)
    {}

    function getAssetPrice() external view returns (uint256) {
        return _getAssetPrice();
    }
}

contract DigiftForkTest is BaseTest {
    DigiftAdapterFactory digiftFactory;
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
            address(new DigiftAdapterHarness(address(registry), subRedManagement, digiftEventVerifier));

        digiftFactory = new DigiftAdapterFactory(digiftAdapterImpl, address(this));

        vm.mockCall(usdcPriceOracle, abi.encodeWithSelector(IPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(dFeedPriceOracle, abi.encodeWithSelector(IPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(address(asset), abi.encodeWithSelector(IPriceOracle.decimals.selector), abi.encode(6));
        vm.mockCall(address(stToken), abi.encodeWithSelector(IPriceOracle.decimals.selector), abi.encode(18));
        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, 2e10, block.timestamp, block.timestamp, 0)
        );

        digiftAdapter = DigiftAdapterHarness(
            address(
                digiftFactory.deploy(
                    AdapterBase.InitArgs(
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

    function test_initialize_reverts() external {
        vm.expectRevert(AdapterBase.InvalidPercentage.selector);
        digiftFactory.deploy(
            AdapterBase.InitArgs(
                "stToken Adapter",
                "wst",
                address(asset),
                usdcPriceOracle,
                address(stToken),
                address(dFeedPriceOracle),
                1e18 + 1,
                0,
                4 days,
                4 days,
                1000e6,
                10e18
            )
        );

        vm.expectRevert(AdapterBase.InvalidPercentage.selector);
        digiftFactory.deploy(
            AdapterBase.InitArgs(
                "stToken Adapter",
                "wst",
                address(asset),
                usdcPriceOracle,
                address(stToken),
                address(dFeedPriceOracle),
                0,
                1e18 + 1,
                4 days,
                4 days,
                1000e6,
                10e18
            )
        );
    }

    function test_setPriceDeviation() external {
        assertEq(digiftAdapter.priceDeviation(), 1e15);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setPriceDeviation(1);

        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.InvalidPercentage.selector));
        digiftAdapter.setPriceDeviation(1e19);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.PriceDeviationChange(1e15, 1e17);
        digiftAdapter.setPriceDeviation(1e17);

        assertEq(digiftAdapter.priceDeviation(), 1e17);
    }

    function test_setSettlementDeviation() external {
        assertEq(digiftAdapter.settlementDeviation(), 1e16);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setSettlementDeviation(1);

        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.InvalidPercentage.selector));
        digiftAdapter.setSettlementDeviation(1e19);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.SettlementDeviationChange(1e16, 1e17);
        digiftAdapter.setSettlementDeviation(1e17);

        assertEq(digiftAdapter.settlementDeviation(), 1e17);
    }

    function test_setPriceUpdateDeviationFund() external {
        assertEq(digiftAdapter.priceUpdateDeviationFund(), 4 days);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setPriceUpdateDeviationFund(1 days);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.PriceUpdateDeviationChangeFund(4 days, 1 days);
        digiftAdapter.setPriceUpdateDeviationFund(1 days);

        assertEq(digiftAdapter.priceUpdateDeviationFund(), 1 days);
    }

    function test_setPriceUpdateDeviationAsset() external {
        assertEq(digiftAdapter.priceUpdateDeviationAsset(), 4 days);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setPriceUpdateDeviationAsset(1 days);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.PriceUpdateDeviationChangeAsset(4 days, 1 days);
        digiftAdapter.setPriceUpdateDeviationAsset(1 days);

        assertEq(digiftAdapter.priceUpdateDeviationAsset(), 1 days);
    }

    function test_setManager() external {
        assertEq(digiftAdapter.managerWhitelisted(manager), false);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setManager(manager, true);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.ManagerWhitelistChange(manager, true);
        digiftAdapter.setManager(manager, true);

        assertEq(digiftAdapter.managerWhitelisted(manager), true);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.ManagerWhitelistChange(manager, false);
        digiftAdapter.setManager(manager, false);

        assertEq(digiftAdapter.managerWhitelisted(manager), false);
    }

    function test_setNode() external {
        assertEq(digiftAdapter.nodeWhitelisted(address(node)), false);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setNode(address(node), true);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.NodeWhitelistChange(address(node), true);
        digiftAdapter.setNode(address(node), true);

        assertEq(digiftAdapter.nodeWhitelisted(address(node)), true);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.NodeWhitelistChange(address(node), false);
        digiftAdapter.setNode(address(node), false);

        assertEq(digiftAdapter.nodeWhitelisted(address(node)), false);

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotNode.selector));
        digiftAdapter.setNode(address(0x1234), true);
    }

    function test_setMinDepositAmount() external {
        assertEq(digiftAdapter.minDepositAmount(), 1000e6);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.setMinDepositAmount(2000e6);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.MinDepositAmountChange(1000e6, 2000e6);
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
        emit AdapterBase.MinRedeemAmountChange(10e18, 20e18);
        digiftAdapter.setMinRedeemAmount(20e18);

        assertEq(digiftAdapter.minRedeemAmount(), 20e18);

        vm.stopPrank();
    }

    function test_forceUpdateLastPrice() external {
        assertEq(digiftAdapter.lastFundPrice(), 2e10);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftAdapter.forceUpdateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, 3e10, block.timestamp, block.timestamp, 0)
        );

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.LastPriceUpdate(3e10);
        digiftAdapter.forceUpdateLastPrice();

        assertEq(digiftAdapter.lastFundPrice(), 3e10);
    }

    function test_updateLastPrice() external {
        vm.prank(owner);
        digiftAdapter.setManager(manager, true);

        uint256 newValidPrice = 2e10 + 1;

        assertEq(digiftAdapter.lastFundPrice(), 2e10);

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotManager.selector, address(this)));
        digiftAdapter.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, newValidPrice, 0, block.timestamp, 0)
        );

        vm.startPrank(manager);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.LastPriceUpdate(newValidPrice);
        digiftAdapter.updateLastPrice();

        assertEq(digiftAdapter.lastFundPrice(), newValidPrice);

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, 0, 0, block.timestamp, 0)
        );
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.BadPriceOracle.selector, dFeedPriceOracle));
        digiftAdapter.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, newValidPrice, 0, block.timestamp - 5 days, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(AdapterBase.StalePriceData.selector, block.timestamp - 5 days, block.timestamp)
        );
        digiftAdapter.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, 30e13, 0, block.timestamp, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(AdapterBase.PriceNotInRange.selector, digiftAdapter.lastFundPrice(), 30e13)
        );
        digiftAdapter.updateLastPrice();
    }

    function test_getAssetPrice() external {
        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, 1e8, 0, block.timestamp, 0)
        );
        assertEq(digiftAdapter.getAssetPrice(), 1e8);

        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, 0, 0, block.timestamp, 0)
        );
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.BadPriceOracle.selector, usdcPriceOracle));
        digiftAdapter.getAssetPrice();

        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, 1e8, 0, block.timestamp - 5 days, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(AdapterBase.StalePriceData.selector, block.timestamp - 5 days, block.timestamp)
        );
        digiftAdapter.getAssetPrice();
    }

    function test_onlyManager() external {
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotManager.selector, address(this)));
        digiftAdapter.updateLastPrice();

        DigiftEventVerifier.OffchainArgs memory offchainArgs;

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotManager.selector, address(this)));
        digiftAdapter.settleDeposit(new address[](0), offchainArgs);

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotManager.selector, address(this)));
        digiftAdapter.settleRedeem(new address[](0), offchainArgs);

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotManager.selector, address(this)));
        digiftAdapter.forwardRequests();
    }

    function test_onlyWhitelistedNode() external {
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.requestDeposit(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.mint(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.requestRedeem(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotWhitelistedNode.selector, address(this)));
        digiftAdapter.withdraw(1, address(this), address(this));
    }
}
