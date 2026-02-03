// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {BaseTest} from "test/BaseTest.sol";
import {WTAdapter} from "src/adapters/wt/WTAdapter.sol";
import {WTAdapterFactory} from "src/adapters/wt/WTAdapterFactory.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {IPriceOracle} from "src/interfaces/external/IPriceOracle.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract WTAdapterTest is BaseTest {
    struct DivScenario {
        address[3] ns;
        uint256 shares1;
        uint256 shares3;
        uint256 redeem3;
        uint256 divShares;
        EventVerifierBase.OffchainArgs fargsDiv;
        uint256[3] weights;
        uint256 totalWeight;
    }

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

    function _settleDepositFor(address[] memory nodes, uint256 sharesToMint) internal {
        EventVerifierBase.OffchainArgs memory fargs;
        TransferEventVerifier.OnchainArgs memory nargs =
            TransferEventVerifier.OnchainArgs(address(fundToken), address(0));
        vm.mockCall(
            address(eventVerifier),
            abi.encodeWithSelector(TransferEventVerifier.verifyEvent.selector, fargs, nargs),
            abi.encode(sharesToMint)
        );

        vm.startPrank(manager);
        wtAdapter.settleDeposit(nodes, fargs);
        vm.stopPrank();

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

    function _settleRedeemFor(address[] memory nodes, uint256 assetsToReturn) internal {
        EventVerifierBase.OffchainArgs memory fargs;
        TransferEventVerifier.OnchainArgs memory nargs = TransferEventVerifier.OnchainArgs(address(asset), sender);
        vm.mockCall(
            address(eventVerifier),
            abi.encodeWithSelector(TransferEventVerifier.verifyEvent.selector, fargs, nargs),
            abi.encode(assetsToReturn)
        );

        vm.startPrank(manager);
        wtAdapter.settleRedeem(nodes, fargs);
        vm.stopPrank();

        ERC20Mock(address(asset)).mint(address(wtAdapter), assetsToReturn);
    }

    function _mockDividend(uint256 divShares) internal returns (EventVerifierBase.OffchainArgs memory fargs) {
        fargs = EventVerifierBase.OffchainArgs(0, bytes(""), bytes(""), 0, new bytes[](0), bytes(""));
        TransferEventVerifier.OnchainArgs memory nargs =
            TransferEventVerifier.OnchainArgs(address(fundToken), address(0));
        vm.mockCall(
            address(eventVerifier),
            abi.encodeWithSelector(TransferEventVerifier.verifyEvent.selector, fargs, nargs),
            abi.encode(divShares)
        );
    }

    function _withdraw(uint256 assets) internal {
        vm.startPrank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(wtAdapter), assets);
        vm.stopPrank();
    }

    function _addNode(address newNode) internal {
        vm.mockCall(address(registry), abi.encodeWithSelector(INodeRegistry.isNode.selector, newNode), abi.encode(true));
        vm.prank(address(factory));
        registry.addNode(newNode);
        vm.prank(owner);
        wtAdapter.setNode(newNode, true);
    }

    function _ensureWhitelisted(address nodeAddr) internal {
        vm.mockCall(
            address(registry), abi.encodeWithSelector(INodeRegistry.isNode.selector, nodeAddr), abi.encode(true)
        );
        vm.startPrank(owner);
        wtAdapter.setNode(nodeAddr, true);
        vm.stopPrank();
    }

    function _requestDepositDirect(address nodeAddr, uint256 assets) internal {
        deal(address(asset), nodeAddr, assets);
        vm.startPrank(nodeAddr);
        asset.approve(address(wtAdapter), assets);
        wtAdapter.requestDeposit(assets, nodeAddr, nodeAddr);
        vm.stopPrank();
    }

    function _requestRedeemDirect(address nodeAddr, uint256 shares) internal {
        vm.startPrank(nodeAddr);
        wtAdapter.approve(address(wtAdapter), shares);
        wtAdapter.requestRedeem(shares, nodeAddr, nodeAddr);
        vm.stopPrank();
    }

    function _weight(address nodeAddr) internal view returns (uint256) {
        return wtAdapter.balanceOf(nodeAddr) + wtAdapter.pendingRedeemRequest(0, nodeAddr)
            + wtAdapter.claimableRedeemRequest(0, nodeAddr) + wtAdapter.maxMint(nodeAddr);
    }

    function _proRataMint(uint256[] memory weights, uint256 amount) internal pure returns (uint256[] memory out) {
        uint256 len = weights.length;
        out = new uint256[](len);
        uint256 minted;
        uint256 total;
        for (uint256 i; i < len; i++) {
            total += weights[i];
        }
        for (uint256 i; i < len; i++) {
            uint256 shareOut = amount * weights[i] / total;
            if (i == len - 1 && minted + shareOut < amount) {
                shareOut += amount - minted - shareOut;
            }
            out[i] = shareOut;
            minted += shareOut;
        }
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

    function test_dividend_single_node_after_settled_cycle() external {
        // setup: node deposits, forwarded, settled and minted
        uint256 depositAmount = _invest();
        uint256 sharesToMint = wtAdapter.convertToShares(depositAmount);
        _forward();
        _settleDeposit(sharesToMint);
        _mint();

        uint256 divShares = 1_000e18;
        EventVerifierBase.OffchainArgs memory fargs = _mockDividend(divShares);
        fundToken.mint(address(wtAdapter), divShares); // simulate WT minting fund shares

        uint256 balBefore = wtAdapter.balanceOf(address(node));
        uint256 supplyBefore = wtAdapter.totalSupply();

        vm.startPrank(manager);
        address[] memory nodesArr = _toArray(address(node));
        wtAdapter.settleDividend(nodesArr, fargs);
        vm.stopPrank();

        assertEq(wtAdapter.balanceOf(address(node)), balBefore + divShares);
        assertEq(wtAdapter.totalSupply(), supplyBefore + divShares);
    }

    function test_dividend_three_nodes_mixed_states_after_settlements() external {
        address[3] memory ns = [user, user2, user3];
        for (uint256 i; i < ns.length; i++) {
            _addNode(ns[i]);
        }

        uint256[3] memory deps = [uint256(100e6), uint256(200e6), uint256(150e6)];
        for (uint256 i; i < ns.length; i++) {
            _requestDepositDirect(ns[i], deps[i]);
        }

        vm.prank(manager);
        wtAdapter.forwardRequests();

        uint256 totalDep = deps[0] + deps[1] + deps[2];
        uint256 totalShares = wtAdapter.convertToShares(totalDep);
        address[] memory nodesAll = new address[](3);
        nodesAll[0] = ns[0];
        nodesAll[1] = ns[1];
        nodesAll[2] = ns[2];
        _settleDepositFor(nodesAll, totalShares);

        uint256 shares1 = wtAdapter.maxMint(ns[0]);
        vm.prank(ns[0]);
        wtAdapter.mint(shares1, ns[0], ns[0]);

        uint256 shares3 = wtAdapter.maxMint(ns[2]);
        vm.prank(ns[2]);
        wtAdapter.mint(shares3, ns[2], ns[2]);

        vm.prank(owner);
        wtAdapter.setMinRedeemAmount(1);

        uint256 redeem3 = shares3 / 2;
        _requestRedeemDirect(ns[2], redeem3);
        vm.prank(manager);
        wtAdapter.forwardRequests();
        _settleRedeemFor(_toArray(ns[2]), wtAdapter.convertToAssets(redeem3));

        uint256 divShares = 900e18;
        EventVerifierBase.OffchainArgs memory fargsDiv = _mockDividend(divShares);
        fundToken.mint(address(wtAdapter), divShares);

        uint256[] memory weights = new uint256[](3);
        weights[0] = _weight(ns[0]);
        weights[1] = _weight(ns[1]);
        weights[2] = _weight(ns[2]);
        uint256[] memory expected = _proRataMint(weights, divShares);

        uint256[] memory beforeBals = new uint256[](3);
        beforeBals[0] = wtAdapter.balanceOf(ns[0]);
        beforeBals[1] = wtAdapter.balanceOf(ns[1]);
        beforeBals[2] = wtAdapter.balanceOf(ns[2]);

        vm.prank(manager);
        wtAdapter.settleDividend(nodesAll, fargsDiv);

        uint256[] memory afterBals = new uint256[](3);
        afterBals[0] = wtAdapter.balanceOf(ns[0]);
        afterBals[1] = wtAdapter.balanceOf(ns[1]);
        afterBals[2] = wtAdapter.balanceOf(ns[2]);

        assertApproxEqAbs(afterBals[0] - beforeBals[0], expected[0], 1e18);
        assertApproxEqAbs(afterBals[1] - beforeBals[1], expected[1], 1e18);
        assertApproxEqAbs(afterBals[2] - beforeBals[2], expected[2], 1e18);
        assertEq(
            (afterBals[0] - beforeBals[0]) + (afterBals[1] - beforeBals[1]) + (afterBals[2] - beforeBals[2]), divShares
        );
    }

    function test_dividend_ignores_pending_deposit_before_forward() external {
        address n1 = user;
        address n2 = user2;
        _addNode(n1);
        _addNode(n2);
        vm.startPrank(owner);
        wtAdapter.setNode(n1, true);
        wtAdapter.setNode(n2, true);
        vm.stopPrank();
        // ensure explicit whitelist
        vm.startPrank(owner);
        wtAdapter.setNode(n1, true);
        wtAdapter.setNode(n2, true);
        vm.stopPrank();

        // Node1 completed deposit and minted
        _requestDepositDirect(n1, 100e6);
        vm.prank(manager);
        wtAdapter.forwardRequests();
        uint256 sharesAll = wtAdapter.convertToShares(100e6);
        address[] memory arr = _toArray(n1);
        _settleDepositFor(arr, sharesAll);
        vm.prank(n1);
        wtAdapter.mint(sharesAll, n1, n1);

        // Node2 has only requested deposit (accumulated) - not forwarded
        _requestDepositDirect(n2, 200e6);

        uint256 divShares = 500e18;
        EventVerifierBase.OffchainArgs memory fargs = _mockDividend(divShares);
        fundToken.mint(address(wtAdapter), divShares);

        vm.prank(manager);
        address[] memory nodesArr = new address[](2);
        nodesArr[0] = n1;
        nodesArr[1] = n2;
        wtAdapter.settleDividend(nodesArr, fargs);

        assertEq(wtAdapter.balanceOf(n1), sharesAll + divShares, "pending depositor should not get dividend");
        assertEq(wtAdapter.balanceOf(n2), 0);
        assertEq(wtAdapter.pendingDepositRequest(0, n2), 200e6, "pending request untouched");
    }

    function test_dividend_reverts_when_pending_deposit() external {
        uint256 depositAmount = _invest();
        vm.prank(manager);
        wtAdapter.forwardRequests(); // creates pendingDepositRequest

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.DepositRequestPending.selector));
        wtAdapter.settleDividend(
            _toArray(address(node)),
            EventVerifierBase.OffchainArgs(0, bytes(""), bytes(""), 0, new bytes[](0), bytes(""))
        );
    }

    function test_dividend_reverts_when_pending_redeem() external {
        uint256 depositAmount = _invest();
        _forward();
        _settleDeposit(wtAdapter.convertToShares(depositAmount));
        _mint();

        vm.prank(owner);
        wtAdapter.setMinRedeemAmount(1);

        _liquidate(wtAdapter.balanceOf(address(node)) / 2);
        vm.prank(manager);
        wtAdapter.forwardRequests(); // pendingRedeemRequest > 0

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.RedeemRequestPending.selector));
        wtAdapter.settleDividend(
            _toArray(address(node)),
            EventVerifierBase.OffchainArgs(0, bytes(""), bytes(""), 0, new bytes[](0), bytes(""))
        );
    }

    function test_dividend_reverts_when_zero_amount() external {
        EventVerifierBase.OffchainArgs memory fargs = _mockDividend(0);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NothingToSettle.selector));
        wtAdapter.settleDividend(_toArray(address(node)), fargs);
    }

    function test_dividend_reverts_when_no_nodes() external {
        EventVerifierBase.OffchainArgs memory fargs = _mockDividend(1e18);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NothingToSettle.selector));
        wtAdapter.settleDividend(new address[](0), fargs);
    }

    function test_dividend_reverts_when_weights_mismatch() external {
        // give supply to node
        uint256 depositAmount = _invest();
        _forward();
        _settleDeposit(wtAdapter.convertToShares(depositAmount));
        _mint();

        // add a second node with zero weight
        address n2 = user2;
        _addNode(n2);

        EventVerifierBase.OffchainArgs memory fargs = _mockDividend(1e18);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(AdapterBase.NotAllNodesSettled.selector));
        wtAdapter.settleDividend(_toArray(n2), fargs);
    }

    function test_dividend_dust_to_last_node() external {
        // two nodes equal weight -> odd dividend triggers dust path
        address n1 = user;
        address n2 = user2;
        _addNode(n1);
        _addNode(n2);
        _ensureWhitelisted(n1);
        _ensureWhitelisted(n2);

        _requestDepositDirect(n1, 100e6);
        _requestDepositDirect(n2, 100e6);
        vm.prank(manager);
        wtAdapter.forwardRequests();
        uint256 totalShares = wtAdapter.convertToShares(200e6);
        address[] memory nodesAll = new address[](2);
        nodesAll[0] = n1;
        nodesAll[1] = n2;
        _settleDepositFor(nodesAll, totalShares);
        uint256 maxMint1 = wtAdapter.maxMint(n1);
        vm.prank(n1);
        wtAdapter.mint(maxMint1, n1, n1);
        uint256 maxMint2 = wtAdapter.maxMint(n2);
        vm.prank(n2);
        wtAdapter.mint(maxMint2, n2, n2);

        uint256 divShares = 5; // odd to force dust on last
        EventVerifierBase.OffchainArgs memory fargs = _mockDividend(divShares);
        fundToken.mint(address(wtAdapter), divShares);

        uint256[] memory before = new uint256[](2);
        before[0] = wtAdapter.balanceOf(n1);
        before[1] = wtAdapter.balanceOf(n2);

        vm.prank(manager);
        wtAdapter.settleDividend(nodesAll, fargs);

        uint256[] memory afterBals = new uint256[](2);
        afterBals[0] = wtAdapter.balanceOf(n1);
        afterBals[1] = wtAdapter.balanceOf(n2);

        assertEq((afterBals[0] - before[0]) + (afterBals[1] - before[1]), divShares);
        // dust should end up at last node (n2)
        assertEq(afterBals[0] - before[0], 2);
        assertEq(afterBals[1] - before[1], 3);
    }

    function test_dividend_two_nodes_success_covers_minted_check() external {
        address n1 = user;
        address n2 = user2;
        _addNode(n1);
        _addNode(n2);
        _ensureWhitelisted(n1);
        _ensureWhitelisted(n2);

        vm.prank(owner);
        wtAdapter.setMinDepositAmount(1);

        _requestDepositDirect(n1, 50e6);
        _requestDepositDirect(n2, 150e6);
        vm.prank(manager);
        wtAdapter.forwardRequests();
        uint256 totalShares = wtAdapter.convertToShares(200e6);
        address[] memory nodes = new address[](2);
        nodes[0] = n1;
        nodes[1] = n2;
        _settleDepositFor(nodes, totalShares);
        vm.startPrank(n1);
        wtAdapter.mint(wtAdapter.maxMint(n1), n1, n1);
        vm.stopPrank();
        vm.startPrank(n2);
        wtAdapter.mint(wtAdapter.maxMint(n2), n2, n2);
        vm.stopPrank();

        uint256 divShares = 7e18;
        EventVerifierBase.OffchainArgs memory fargs = _mockDividend(divShares);
        fundToken.mint(address(wtAdapter), divShares);

        uint256 supplyBefore = wtAdapter.totalSupply();
        vm.expectEmit(true, true, true, true, address(wtAdapter));
        emit WTAdapter.DividendSettled(divShares, divShares);
        vm.prank(manager);
        wtAdapter.settleDividend(nodes, fargs);
        assertEq(wtAdapter.totalSupply(), supplyBefore + divShares);
    }

    function test_onERC721Received_accepts_soulbound_token() external {
        bytes4 result = wtAdapter.onERC721Received(address(this), address(0xBEEF), 1, bytes(""));
        assertEq(result, IERC721Receiver.onERC721Received.selector, "must return magic value");
    }
}
