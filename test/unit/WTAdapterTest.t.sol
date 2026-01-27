// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";
import {WTAdapter} from "src/adapters/wt/WTAdapter.sol";
import {WTAdapterFactory} from "src/adapters/wt/WTAdapterFactory.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {IPriceOracle} from "src/interfaces/external/IPriceOracle.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract WTAdapterTest is BaseTest {
    WTAdapterFactory wtFactory;
    WTAdapter wtAdapter;
    TransferEventVerifier eventVerifier;
    ERC20Mock fundToken;

    address receiver = makeAddr("wtReceiver");
    address sender = makeAddr("wtSender");
    address manager = makeAddr("manager");

    address assetPriceOracle = makeAddr("assetPriceOracle");
    address fundPriceOracle = makeAddr("fundPriceOracle");

    uint256 constant DEPOSIT_AMOUNT = 1000e6;
    uint64 constant ALLOCATION = 0.9 ether;
    uint256 investAmount;

    function setUp() public override {
        super.setUp();

        _userDeposits(user, DEPOSIT_AMOUNT);

        vm.warp(block.timestamp + 25 hours);

        // use USDC-like asset decimals for easier parity with fork tests
        ERC20Mock(address(asset)).setDecimals(6);

        fundToken = new ERC20Mock("WT Fund", "WTF");

        eventVerifier = new TransferEventVerifier(address(registry));
        WTAdapter wtImpl = new WTAdapter(address(registry), address(eventVerifier));
        wtFactory = new WTAdapterFactory(address(wtImpl), address(this));

        // price oracle mocks
        vm.mockCall(assetPriceOracle, abi.encodeWithSelector(IPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(fundPriceOracle, abi.encodeWithSelector(IPriceOracle.decimals.selector), abi.encode(8));
        vm.mockCall(
            assetPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, int256(1e8), 0, block.timestamp, 0)
        );
        vm.mockCall(
            fundPriceOracle,
            abi.encodeWithSelector(IPriceOracle.latestRoundData.selector),
            abi.encode(0, int256(2e10), 0, block.timestamp, 0)
        );

        wtAdapter = WTAdapter(
            address(
                wtFactory.deploy(
                    AdapterBase.InitArgs(
                        "WT Adapter",
                        "wt",
                        address(asset),
                        assetPriceOracle,
                        address(fundToken),
                        fundPriceOracle,
                        1e15,
                        1e16,
                        10 days,
                        10 days,
                        100e6,
                        1e18,
                        abi.encode(receiver, sender)
                    )
                )
            )
        );

        investAmount = DEPOSIT_AMOUNT * ALLOCATION / 1e18;

        vm.startPrank(owner);
        node.removeComponent(address(vault), false);
        router7540.setWhitelistStatus(address(wtAdapter), true);
        node.addRouter(address(router7540));
        node.addComponent(address(wtAdapter), ALLOCATION, 0.01 ether, address(router7540));
        wtAdapter.setManager(manager, true);
        wtAdapter.setNode(address(node), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();
    }

    function _invest() internal returns (uint256) {
        vm.startPrank(rebalancer);
        uint256 deposited = router7540.investInAsyncComponent(address(node), address(wtAdapter));
        vm.stopPrank();
        return deposited;
    }

    function _forward() internal {
        vm.startPrank(manager);
        wtAdapter.forwardRequests();
        vm.stopPrank();
    }

    function _settleDeposit(uint256 sharesToMint) internal {
        EventVerifierBase.OffchainArgs memory fargs;
        TransferEventVerifier.OnchainArgs memory nargs =
            TransferEventVerifier.OnchainArgs(address(fundToken), address(0));
        vm.mockCall(
            address(eventVerifier),
            abi.encodeWithSelector(TransferEventVerifier.verifyEvent.selector, fargs, nargs),
            abi.encode(sharesToMint)
        );

        vm.startPrank(manager);
        address[] memory nodes = new address[](1);
        nodes[0] = address(node);
        wtAdapter.settleDeposit(nodes, fargs);
        vm.stopPrank();

        // simulate fund tokens minted to adapter after successful settlement
        fundToken.mint(address(wtAdapter), sharesToMint);
    }

    function _mint() internal {
        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(wtAdapter));
        vm.stopPrank();
    }

    function _liquidate(uint256 shares) internal {
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), address(wtAdapter), shares);
        vm.stopPrank();
    }

    function _settleRedeem(uint256 assetsToReturn) internal {
        EventVerifierBase.OffchainArgs memory fargs;
        TransferEventVerifier.OnchainArgs memory nargs = TransferEventVerifier.OnchainArgs(address(asset), sender);
        vm.mockCall(
            address(eventVerifier),
            abi.encodeWithSelector(TransferEventVerifier.verifyEvent.selector, fargs, nargs),
            abi.encode(assetsToReturn)
        );

        vm.startPrank(manager);
        address[] memory nodes = new address[](1);
        nodes[0] = address(node);
        wtAdapter.settleRedeem(nodes, fargs);
        vm.stopPrank();

        // simulate WT sending assets back to adapter after redemption
        ERC20Mock(address(asset)).mint(address(wtAdapter), assetsToReturn);
    }

    function _withdraw(uint256 assets) internal {
        vm.startPrank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(wtAdapter), assets);
        vm.stopPrank();
    }

    function test_setReceiverAddress_onlyRegistryOwner() external {
        address newReceiver = makeAddr("newReceiver");

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        wtAdapter.setReceiverAddress(newReceiver);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.ZeroAddress.selector));
        vm.prank(owner);
        wtAdapter.setReceiverAddress(address(0));

        vm.expectEmit(true, true, true, true, address(wtAdapter));
        emit WTAdapter.ReceiverAddressChange(receiver, newReceiver);
        vm.prank(owner);
        wtAdapter.setReceiverAddress(newReceiver);

        assertEq(wtAdapter.receiverAddress(), newReceiver);
    }

    function test_setSenderAddress_onlyRegistryOwner() external {
        address newSender = makeAddr("newSender");

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotRegistryOwner.selector));
        wtAdapter.setSenderAddress(newSender);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.ZeroAddress.selector));
        vm.prank(owner);
        wtAdapter.setSenderAddress(address(0));

        vm.expectEmit(true, true, true, true, address(wtAdapter));
        emit WTAdapter.SenderAddressChange(sender, newSender);
        vm.prank(owner);
        wtAdapter.setSenderAddress(newSender);

        assertEq(wtAdapter.senderAddress(), newSender);
    }

    function test_deposit_settle_and_mint() external {
        uint256 nodeBalanceBefore = asset.balanceOf(address(node));

        vm.expectEmit(true, true, true, true, address(wtAdapter));
        emit IERC7540Deposit.DepositRequest(address(node), address(node), 0, address(node), investAmount);
        uint256 depositAmount = _invest();
        assertEq(depositAmount, investAmount, "invest amount matches allocation");

        assertEq(wtAdapter.pendingDepositRequest(0, address(node)), depositAmount);
        assertEq(wtAdapter.accumulatedDeposit(), depositAmount);
        assertEq(asset.balanceOf(address(wtAdapter)), depositAmount);

        vm.expectEmit(true, true, true, true, address(wtAdapter));
        emit AdapterBase.FundDeposited(depositAmount);
        _forward();

        assertEq(wtAdapter.globalPendingDepositRequest(), depositAmount);
        assertEq(asset.balanceOf(receiver), depositAmount, "receiver gets funds");

        uint256 sharesToMint = wtAdapter.convertToShares(depositAmount);

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.DepositSettled(address(node), sharesToMint, 0);
        _settleDeposit(sharesToMint);

        assertEq(wtAdapter.claimableDepositRequest(0, address(node)), depositAmount);
        assertEq(wtAdapter.maxMint(address(node)), sharesToMint);

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Deposit(address(node), address(node), depositAmount, sharesToMint);
        _mint();

        assertEq(wtAdapter.balanceOf(address(node)), sharesToMint);
        assertEq(wtAdapter.claimableDepositRequest(0, address(node)), 0);
        assertEq(wtAdapter.maxMint(address(node)), 0);
        assertEq(asset.balanceOf(address(node)) + depositAmount, nodeBalanceBefore, "node spent deposit assets");
    }

    function test_redeem_and_withdraw_flow() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = wtAdapter.convertToShares(depositAmount);

        _forward();
        _settleDeposit(sharesToMint);
        _mint();

        uint256 toRedeem = sharesToMint / 2;
        uint256 assetsToReturn = wtAdapter.convertToAssets(toRedeem);
        uint256 nodeAssetsBeforeWithdraw = asset.balanceOf(address(node));

        vm.expectEmit(true, true, true, true, address(wtAdapter));
        emit IERC7540Redeem.RedeemRequest(address(node), address(node), 0, address(node), toRedeem);
        _liquidate(toRedeem);

        assertEq(wtAdapter.pendingRedeemRequest(0, address(node)), toRedeem);
        assertEq(wtAdapter.accumulatedRedemption(), toRedeem);

        vm.expectEmit(true, true, true, true, address(wtAdapter));
        emit AdapterBase.FundRedeemed(toRedeem);
        _forward();

        assertEq(wtAdapter.globalPendingRedeemRequest(), toRedeem);
        assertEq(fundToken.balanceOf(receiver), toRedeem, "fund tokens sent for redemption");

        vm.expectEmit(true, true, true, true);
        emit AdapterBase.RedeemSettled(address(node), 0, assetsToReturn);
        _settleRedeem(assetsToReturn);

        assertEq(wtAdapter.claimableRedeemRequest(0, address(node)), toRedeem);
        assertEq(wtAdapter.maxWithdraw(address(node)), assetsToReturn);

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Withdraw(address(node), address(node), address(node), assetsToReturn, toRedeem);
        _withdraw(assetsToReturn);

        assertEq(wtAdapter.claimableRedeemRequest(0, address(node)), 0);
        assertEq(wtAdapter.maxWithdraw(address(node)), 0);
        assertEq(wtAdapter.balanceOf(address(node)), sharesToMint - toRedeem);
        assertEq(
            asset.balanceOf(address(node)), nodeAssetsBeforeWithdraw + assetsToReturn, "node received redeemed assets"
        );
    }
}
