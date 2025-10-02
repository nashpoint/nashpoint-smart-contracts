// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";
import {DigiftEventVerifier} from "src/wrappers/digift/DigiftEventVerifier.sol";
import {DigiftWrapperFactory} from "src/wrappers/digift/DigiftWrapperFactory.sol";
import {DigiftWrapper} from "src/wrappers/digift/DigiftWrapper.sol";
import {ISubRedManagement, IDFeedPriceOracle, IManagement, ISecurityToken} from "src/interfaces/external/IDigift.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {INode} from "src/interfaces/INode.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract DigiftWrapperHarness is DigiftWrapper {
    constructor(address subRedManagement_, address registry_, address digiftEventVerifier_)
        DigiftWrapper(subRedManagement_, registry_, digiftEventVerifier_)
    {}

    function getAssetPrice() external view returns (uint256) {
        return _getAssetPrice();
    }
}

contract DigiftForkTest is BaseTest {
    DigiftWrapperHarness digiftWrapper;
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

        address digiftWrapperImpl =
            address(new DigiftWrapperHarness(subRedManagement, address(registry), digiftEventVerifier));

        DigiftWrapperFactory factory = new DigiftWrapperFactory(digiftWrapperImpl, address(this));

        vm.mockCall(usdcPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(dFeedPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(address(asset), abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(6));
        vm.mockCall(address(stToken), abi.encodeWithSelector(IDFeedPriceOracle.decimals.selector), abi.encode(18));
        vm.mockCall(dFeedPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.getPrice.selector), abi.encode(2e10));

        digiftWrapper = DigiftWrapperHarness(
            address(
                factory.deploy(
                    DigiftWrapper.InitArgs(
                        "stToken Wrapper",
                        "wst",
                        address(asset),
                        usdcPriceOracle,
                        address(stToken),
                        address(dFeedPriceOracle),
                        // 0.1%
                        1e15,
                        4 days
                    )
                )
            )
        );

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(digiftWrapper), true);
        node.addRouter(address(router7540));
        node.addComponent(address(digiftWrapper), ALLOCATION, 0.01 ether, address(router7540));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();
    }

    function test_setPriceDeviation() external {
        assertEq(digiftWrapper.priceDeviation(), 1e15);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftWrapper.setPriceDeviation(1);

        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.InvalidPercentage.selector));
        digiftWrapper.setPriceDeviation(1e19);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.PriceDeviationChange(1e15, 1e17);
        digiftWrapper.setPriceDeviation(1e17);

        assertEq(digiftWrapper.priceDeviation(), 1e17);
    }

    function test_setPriceUpdateDeviation() external {
        assertEq(digiftWrapper.priceUpdateDeviation(), 4 days);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftWrapper.setPriceUpdateDeviation(1 days);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.PriceUpdateDeviationChange(4 days, 1 days);
        digiftWrapper.setPriceUpdateDeviation(1 days);

        assertEq(digiftWrapper.priceUpdateDeviation(), 1 days);
    }

    function test_setManager() external {
        assertEq(digiftWrapper.managerWhitelisted(manager), false);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftWrapper.setManager(manager, true);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.ManagerWhitelistChange(manager, true);
        digiftWrapper.setManager(manager, true);

        assertEq(digiftWrapper.managerWhitelisted(manager), true);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.ManagerWhitelistChange(manager, false);
        digiftWrapper.setManager(manager, false);

        assertEq(digiftWrapper.managerWhitelisted(manager), false);
    }

    function test_setNode() external {
        assertEq(digiftWrapper.nodeWhitelisted(address(node)), false);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftWrapper.setNode(address(node), true);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.NodeWhitelistChange(address(node), true);
        digiftWrapper.setNode(address(node), true);

        assertEq(digiftWrapper.nodeWhitelisted(address(node)), true);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.NodeWhitelistChange(address(node), false);
        digiftWrapper.setNode(address(node), false);

        assertEq(digiftWrapper.nodeWhitelisted(address(node)), false);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotNode.selector));
        digiftWrapper.setNode(address(0x1234), true);
    }

    function test_forceUpdateLastPrice() external {
        assertEq(digiftWrapper.lastPrice(), 2e10);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        digiftWrapper.forceUpdateLastPrice();

        vm.mockCall(dFeedPriceOracle, abi.encodeWithSelector(IDFeedPriceOracle.getPrice.selector), abi.encode(3e10));

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.LastPriceUpdate(3e10);
        digiftWrapper.forceUpdateLastPrice();

        assertEq(digiftWrapper.lastPrice(), 3e10);
    }

    function test_updateLastPrice() external {
        vm.prank(owner);
        digiftWrapper.setManager(manager, true);

        uint256 newValidPrice = 2e10 + 1;

        assertEq(digiftWrapper.lastPrice(), 2e10);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotManager.selector, address(this)));
        digiftWrapper.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, newValidPrice, 0, block.timestamp, 0)
        );

        vm.startPrank(manager);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.LastPriceUpdate(newValidPrice);
        digiftWrapper.updateLastPrice();

        assertEq(digiftWrapper.lastPrice(), newValidPrice);

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 0, 0, block.timestamp, 0)
        );
        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.BadPriceOracle.selector, dFeedPriceOracle));
        digiftWrapper.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, newValidPrice, 0, block.timestamp - 5 days, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(DigiftWrapper.StalePriceData.selector, block.timestamp - 5 days, block.timestamp)
        );
        digiftWrapper.updateLastPrice();

        vm.mockCall(
            dFeedPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 30e13, 0, block.timestamp, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(DigiftWrapper.PriceNotInRange.selector, digiftWrapper.lastPrice(), 30e13)
        );
        digiftWrapper.updateLastPrice();
    }

    function test_getAssetPrice() external {
        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 1e8, 0, block.timestamp, 0)
        );
        assertEq(digiftWrapper.getAssetPrice(), 1e8);

        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 0, 0, block.timestamp, 0)
        );
        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.BadPriceOracle.selector, usdcPriceOracle));
        digiftWrapper.getAssetPrice();

        vm.mockCall(
            usdcPriceOracle,
            abi.encodeWithSelector(IDFeedPriceOracle.latestRoundData.selector),
            abi.encode(0, 1e8, 0, block.timestamp - 5 days, 0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(DigiftWrapper.StalePriceData.selector, block.timestamp - 5 days, block.timestamp)
        );
        digiftWrapper.getAssetPrice();
    }

    function test_onlyManager() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotManager.selector, address(this)));
        digiftWrapper.updateLastPrice();

        DigiftEventVerifier.OffchainArgs memory offchainArgs;

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotManager.selector, address(this)));
        digiftWrapper.settleDeposit(new address[](0), offchainArgs);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotManager.selector, address(this)));
        digiftWrapper.settleRedeem(new address[](0), offchainArgs);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotManager.selector, address(this)));
        digiftWrapper.forwardRequestsToDigift();
    }

    function test_onlyWhitelistedNode() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotWhitelistedNode.selector, address(this)));
        digiftWrapper.requestDeposit(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotWhitelistedNode.selector, address(this)));
        digiftWrapper.mint(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotWhitelistedNode.selector, address(this)));
        digiftWrapper.requestRedeem(1, address(this), address(this));

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotWhitelistedNode.selector, address(this)));
        digiftWrapper.withdraw(1, address(this), address(this));
    }
}
