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
import {ComponentAllocation, INode, NodeInitArgs} from "src/interfaces/INode.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract DigiftForkTest is BaseTest {
    DigiftAdapter digiftAdapter;
    address digiftEventVerifier = makeAddr("digiftEventVerifier");

    INode node2;

    uint256 DEPOSIT_AMOUNT = 1000e6;
    uint64 ALLOCATION = 0.9 ether;
    uint256 INVEST_AMOUNT = DEPOSIT_AMOUNT * ALLOCATION / 1e18;

    address manager = makeAddr("manager");

    address usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    ISubRedManagement constant subRedManagement = ISubRedManagement(0x3DAd21A73a63bBd186f57f733d271623467b6c78);
    IDFeedPriceOracle constant dFeedPriceOracle = IDFeedPriceOracle(0x67aE0CAAC7f6995d8B24d415F584e5625cdEe048);
    ISecurityToken constant stToken = ISecurityToken(0x37EC21365dC39B0b74ea7b6FabFfBcB277568AC4);

    function setUp() public override {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 375510069);
        super.setUp();

        address digiftAdapterImpl =
            address(new DigiftAdapter(address(subRedManagement), address(registry), digiftEventVerifier));

        DigiftAdapterFactory dFactory = new DigiftAdapterFactory(digiftAdapterImpl, address(this));

        digiftAdapter = dFactory.deploy(
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
                10 days,
                10 days,
                // set 100 USDC instead of 1000
                100e6,
                // set 1 stToken instead of 10
                1e18
            )
        );

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(digiftAdapter), true);
        vm.stopPrank();

        // DigiftAdapter is whitelisted
        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isWhiteInvestor.selector, address(digiftAdapter)),
            abi.encode(true)
        );
        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isWhiteContract.selector, address(digiftAdapter)),
            abi.encode(true)
        );
        // allow us minting of stToken to SubRedManagement and settle subscription
        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isContractManager.selector, address(this)),
            abi.encode(true)
        );

        // create Node2 and invest into DigiftAdapter
        vm.startPrank(owner);
        bytes[] memory payload = new bytes[](4);
        payload[0] = abi.encodeWithSelector(INode.addRouter.selector, address(router7540));
        payload[1] = abi.encodeWithSelector(INode.addRebalancer.selector, rebalancer);
        payload[2] = abi.encodeWithSelector(
            INode.addComponent.selector, address(digiftAdapter), 0.9 ether, 0.01 ether, address(router7540)
        );
        payload[3] = abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, 0.1 ether);

        (node2,) = factory.deployFullNode(
            NodeInitArgs("Test Node 2", "TNODE2", address(asset), owner), payload, keccak256("new salt")
        );

        node2.setMaxDepositSize(1e36);
        digiftAdapter.setNode(address(node2), true);

        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(rebalancer);
        node.startRebalance();
        node2.startRebalance();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.addRouter(address(router7540));
        // remove mock ERC4626 vault
        node.removeComponent(address(vault), false);
        node.addComponent(address(digiftAdapter), ALLOCATION, 0.01 ether, address(router7540));
        digiftAdapter.setManager(manager, true);
        digiftAdapter.setNode(address(node), true);
        digiftAdapter.setNode(address(node2), true);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        node.startRebalance();
        node2.startRebalance();

        vm.startPrank(user2);
        asset.approve(address(node2), DEPOSIT_AMOUNT / 3);
        node2.deposit(DEPOSIT_AMOUNT / 3, user2);
        vm.stopPrank();

        _userDeposits(user, DEPOSIT_AMOUNT);
    }

    function _invest() internal returns (uint256) {
        vm.startPrank(rebalancer);
        uint256 depositAmount = router7540.investInAsyncComponent(address(node), address(digiftAdapter));
        vm.stopPrank();
        return depositAmount;
    }

    function _invest2() internal returns (uint256) {
        vm.startPrank(rebalancer);
        uint256 depositAmount = router7540.investInAsyncComponent(address(node2), address(digiftAdapter));
        vm.stopPrank();
        return depositAmount;
    }

    function _liquidate(uint256 amount) internal {
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), address(digiftAdapter), amount);
        vm.stopPrank();
    }

    function _liquidate2(uint256 amount) internal {
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node2), address(digiftAdapter), amount);
        vm.stopPrank();
    }

    function _forward() internal {
        vm.startPrank(manager);
        digiftAdapter.forwardRequestsToDigift();
        vm.stopPrank();
    }

    function _settleDeposit(INode node, uint256 shares, uint256 assets) internal {
        DigiftEventVerifier.OffchainArgs memory fargs;
        DigiftEventVerifier.OnchainArgs memory nargs = DigiftEventVerifier.OnchainArgs(
            DigiftEventVerifier.EventType.SUBSCRIBE, address(subRedManagement), address(stToken), address(asset)
        );
        vm.mockCall(
            digiftEventVerifier,
            abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
            abi.encode(shares, assets)
        );
        vm.startPrank(manager);
        address[] memory nodes = new address[](1);
        nodes[0] = address(node);
        digiftAdapter.settleDeposit(nodes, fargs);
        vm.stopPrank();
    }

    function _settleRedeem(INode node, uint256 assets, uint256 shares) internal {
        DigiftEventVerifier.OffchainArgs memory fargs;
        DigiftEventVerifier.OnchainArgs memory nargs = DigiftEventVerifier.OnchainArgs(
            DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), address(stToken), address(asset)
        );
        vm.mockCall(
            digiftEventVerifier,
            abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
            abi.encode(shares, assets)
        );
        vm.startPrank(manager);
        address[] memory nodes = new address[](1);
        nodes[0] = address(node);
        digiftAdapter.settleRedeem(nodes, fargs);
        vm.stopPrank();
    }

    function _updateTotalAssets() internal {
        vm.startPrank(rebalancer);
        node.updateTotalAssets();
        vm.stopPrank();
    }

    function _settleSubscription(uint256 stTokens, uint256 assets, uint256 fee) internal {
        address[] memory investorList = new address[](1);
        investorList[0] = address(digiftAdapter);
        uint256[] memory quantityList = new uint256[](1);
        quantityList[0] = stTokens;
        address[] memory currencyTokenList = new address[](1);
        currencyTokenList[0] = address(asset);
        uint256[] memory amountList = new uint256[](1);
        amountList[0] = assets;
        uint256[] memory feeList = new uint256[](1);
        feeList[0] = fee;
        stToken.issue(address(subRedManagement), stTokens);
        subRedManagement.settleSubscriber(
            address(stToken), investorList, quantityList, currencyTokenList, amountList, feeList
        );
    }

    function _settleRedemption(uint256 stTokens, uint256 assets, uint256 fee) internal {
        address[] memory investorList = new address[](1);
        investorList[0] = address(digiftAdapter);
        uint256[] memory quantityList = new uint256[](1);
        quantityList[0] = stTokens;
        address[] memory currencyTokenList = new address[](1);
        currencyTokenList[0] = address(asset);
        uint256[] memory amountList = new uint256[](1);
        amountList[0] = assets;
        uint256[] memory feeList = new uint256[](1);
        feeList[0] = fee;
        subRedManagement.settleRedemption(
            address(stToken), investorList, quantityList, currencyTokenList, amountList, feeList
        );
    }

    function _mint(INode node) internal {
        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(digiftAdapter));
        vm.stopPrank();
    }

    function _withdraw(INode node, uint256 assets) internal {
        vm.startPrank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(digiftAdapter), assets);
        vm.stopPrank();
    }

    function test_deployment_success() external view {
        assertEq(address(digiftAdapter.subRedManagement()), address(subRedManagement));
        assertEq(address(digiftAdapter.digiftEventVerifier()), digiftEventVerifier);
    }

    function test_investInAsyncComponent_success() external {
        uint256 balance = asset.balanceOf(address(node));

        vm.expectEmit(true, true, true, true, address(digiftAdapter));
        emit IERC7540Deposit.DepositRequest(address(node), address(node), 0, address(node), INVEST_AMOUNT);
        uint256 depositAmount = _invest();
        assertEq(depositAmount, INVEST_AMOUNT, "Invested according to allocation");

        assertEq(digiftAdapter.pendingDepositRequest(0, address(node)), INVEST_AMOUNT);
        assertEq(digiftAdapter.accumulatedDeposit(), depositAmount, "Accumulated whole deposit amount");

        vm.startPrank(address(node));
        assertEq(router7540.getComponentAssets(address(digiftAdapter), false), INVEST_AMOUNT);
        vm.stopPrank();

        assertEq(node.totalAssets(), balance);

        _updateTotalAssets();

        assertEq(node.totalAssets(), balance);
    }

    function test_forwardRequestsToDigift_one_deposit_only() external {
        uint256 depositAmount = _invest();

        vm.expectEmit(true, true, true, true, address(subRedManagement));
        emit ISubRedManagement.Subscribe(
            address(subRedManagement), address(stToken), address(asset), address(digiftAdapter), INVEST_AMOUNT
        );
        vm.expectEmit(true, true, true, true, address(digiftAdapter));
        emit DigiftAdapter.DigiftSubscribed(depositAmount);
        _forward();

        assertEq(digiftAdapter.globalPendingDepositRequest(), depositAmount, "Pending whole deposit amount");

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.DepositRequestPending.selector));
        _forward();
    }

    function test_settleDeposit_success() external {
        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.DepositSettled(address(node), sharesToMint, 0);
        _settleDeposit(node, sharesToMint, 0);

        assertEq(digiftAdapter.globalPendingDepositRequest(), 0, "After settle there is nothing pending");
        assertEq(digiftAdapter.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
        assertEq(
            digiftAdapter.claimableDepositRequest(0, address(node)),
            INVEST_AMOUNT,
            "All deposit amount is claimable now"
        );
        assertEq(digiftAdapter.maxMint(address(node)), sharesToMint, "maxMint reflects shares to mint");
    }

    function test_mintClaimableShares_success() external {
        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);

        assertEq(digiftAdapter.balanceOf(address(node)), 0, "Node has no shares of digift adapter");

        _settleDeposit(node, sharesToMint, 0);

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Deposit(address(node), address(node), depositAmount, sharesToMint);
        _mint(node);

        assertEq(digiftAdapter.balanceOf(address(node)), sharesToMint, "Shares are minted to node");
        assertEq(digiftAdapter.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
        assertEq(digiftAdapter.claimableDepositRequest(0, address(node)), 0, "Everything is claimed");
        assertEq(digiftAdapter.maxMint(address(node)), 0, "Nothing to mint");
    }

    function test_mintClaimableShares_partialMintWithReimbursement() external {
        uint256 depositAmount = _invest();
        uint256 initialNodeAssetBalance = asset.balanceOf(address(node));

        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        // 80% of expected shares
        uint256 partialShares = sharesToMint * 8 / 10;
        uint256 assetsUsed = digiftAdapter.convertToAssets(partialShares);
        uint256 assetsToReimburse = depositAmount - assetsUsed;

        _forward();
        _settleSubscription(partialShares, assetsToReimburse, 0);

        assertEq(digiftAdapter.balanceOf(address(node)), 0, "Node has no shares initially");

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.DepositSettled(address(node), partialShares, assetsToReimburse);
        _settleDeposit(node, partialShares, assetsToReimburse);

        assertEq(digiftAdapter.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
        assertEq(
            digiftAdapter.claimableDepositRequest(0, address(node)), depositAmount, "All deposit amount is claimable"
        );
        assertEq(digiftAdapter.maxMint(address(node)), partialShares, "maxMint reflects partial shares");

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Deposit(address(node), address(node), assetsUsed, partialShares);
        _mint(node);

        assertEq(digiftAdapter.balanceOf(address(node)), partialShares, "Partial shares are minted to node");
        assertEq(digiftAdapter.claimableDepositRequest(0, address(node)), 0, "Everything is claimed");
        assertEq(digiftAdapter.maxMint(address(node)), 0, "Nothing to mint");

        uint256 finalNodeAssetBalance = asset.balanceOf(address(node));
        uint256 expectedFinalBalance = initialNodeAssetBalance + assetsToReimburse;
        assertEq(finalNodeAssetBalance, expectedFinalBalance, "Node received asset reimbursement");
    }

    function test_requestAsyncWithdrawal_success() external {
        uint256 balance = asset.balanceOf(address(node));

        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);

        _mint(node);

        assertEq(node.totalAssets(), balance);

        vm.expectEmit(true, true, true, true, address(digiftAdapter));
        emit IERC7540Redeem.RedeemRequest(address(node), address(node), 0, address(node), toLiquidate);
        _liquidate(toLiquidate);

        assertEq(digiftAdapter.pendingRedeemRequest(0, address(node)), toLiquidate);
        assertEq(digiftAdapter.claimableRedeemRequest(0, address(node)), 0);
        assertEq(digiftAdapter.accumulatedRedemption(), toLiquidate);

        _updateTotalAssets();

        assertApproxEqAbs(node.totalAssets(), balance, 2);
    }

    function test_forwardRequestsToDigift_one_redeem_only() external {
        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);

        vm.expectEmit(true, true, true, true, address(subRedManagement));
        emit ISubRedManagement.Redeem(
            address(subRedManagement), address(stToken), address(asset), address(digiftAdapter), toLiquidate
        );
        _forward();
        assertEq(digiftAdapter.globalPendingRedeemRequest(), toLiquidate);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.RedeemRequestPending.selector));
        _forward();
    }

    function test_settleRedeem_success() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.RedeemSettled(address(node), 0, assetsToReturn);
        _settleRedeem(node, assetsToReturn, 0);

        assertEq(digiftAdapter.pendingRedeemRequest(0, address(node)), 0);
        assertEq(digiftAdapter.claimableRedeemRequest(0, address(node)), toLiquidate);
        assertEq(digiftAdapter.maxWithdraw(address(node)), assetsToReturn);
    }

    function test_withdraw_success() external {
        uint256 balance = asset.balanceOf(address(node));

        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);
        _settleRedeem(node, assetsToReturn, 0);

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Withdraw(address(node), address(node), address(node), assetsToReturn, toLiquidate);
        _withdraw(node, assetsToReturn);

        assertEq(digiftAdapter.pendingRedeemRequest(0, address(node)), 0);
        assertEq(digiftAdapter.claimableRedeemRequest(0, address(node)), 0);
        assertEq(digiftAdapter.maxWithdraw(address(node)), 0);

        _updateTotalAssets();

        assertApproxEqAbs(node.totalAssets(), balance, 4);
    }

    function test_withdraw_partialRedeemWithReimbursement() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 initialNodeShareBalance = digiftAdapter.balanceOf(address(node));

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);

        assertEq(digiftAdapter.balanceOf(address(node)), sharesToMint, "Node has shares initially");

        uint256 sharesToRedeem = sharesToMint;
        _liquidate(sharesToRedeem);

        uint256 expectedAssets = digiftAdapter.convertToAssets(sharesToRedeem);
        // 80% of expected assets
        uint256 partialAssets = expectedAssets * 8 / 10;
        uint256 sharesUsed = digiftAdapter.convertToShares(partialAssets);
        uint256 sharesToReimburse = sharesToRedeem - sharesUsed;

        _forward();
        _settleRedemption(sharesToReimburse, partialAssets, 0);

        vm.expectEmit(true, true, true, true);
        emit DigiftAdapter.RedeemSettled(address(node), sharesToReimburse, partialAssets);
        _settleRedeem(node, partialAssets, sharesToReimburse);

        assertEq(digiftAdapter.pendingRedeemRequest(0, address(node)), 0, "No pending shares to redeem");
        assertEq(digiftAdapter.claimableRedeemRequest(0, address(node)), sharesToRedeem, "All shares are claimable");
        assertEq(digiftAdapter.maxWithdraw(address(node)), partialAssets, "maxWithdraw reflects partial assets");

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Withdraw(address(node), address(node), address(node), partialAssets, sharesUsed);
        _withdraw(node, partialAssets);

        assertEq(digiftAdapter.claimableRedeemRequest(0, address(node)), 0, "Everything is claimed");
        assertEq(digiftAdapter.maxWithdraw(address(node)), 0, "Nothing to withdraw");

        uint256 finalNodeShareBalance = digiftAdapter.balanceOf(address(node));
        uint256 expectedFinalShareBalance = initialNodeShareBalance + sharesToReimburse;
        assertEq(finalNodeShareBalance, expectedFinalShareBalance, "Node received share reimbursement");
    }

    // =============================
    //      Custom Error Tests
    // =============================

    function test_requestDeposit_BelowLimit() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.BelowLimit.selector, 100e6, 0));
        vm.prank(address(node));
        digiftAdapter.requestDeposit(0, address(node), address(node));
    }

    function test_requestDeposit_ControllerNotSender() external {
        vm.expectRevert(DigiftAdapter.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.requestDeposit(DEPOSIT_AMOUNT, address(this), address(node));
    }

    function test_requestDeposit_OwnerNotSender() external {
        vm.expectRevert(DigiftAdapter.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.requestDeposit(DEPOSIT_AMOUNT, address(node), address(this));
    }

    function test_requestDeposit_DepositRequestPending() external {
        _invest();
        vm.expectRevert(DigiftAdapter.DepositRequestPending.selector);
        vm.prank(address(node));
        digiftAdapter.requestDeposit(DEPOSIT_AMOUNT, address(node), address(node));
    }

    function test_requestDeposit_RedeemRequestPending() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(sharesToMint / 2);

        vm.expectRevert(DigiftAdapter.RedeemRequestPending.selector);
        vm.prank(address(node));
        digiftAdapter.requestDeposit(1000e6, address(node), address(node));
    }

    function test_requestDeposit_DepositRequestNotClaimed() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);

        vm.expectRevert(DigiftAdapter.DepositRequestNotClaimed.selector);
        vm.prank(address(node));
        digiftAdapter.requestDeposit(DEPOSIT_AMOUNT, address(node), address(node));
    }

    function test_requestDeposit_RedeemRequestNotClaimed() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);
        _settleRedeem(node, assetsToReturn, 0);

        vm.expectRevert(DigiftAdapter.RedeemRequestNotClaimed.selector);
        vm.prank(address(node));
        digiftAdapter.requestDeposit(1000e6, address(node), address(node));
    }

    function test_requestRedeem_BelowLimit() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.BelowLimit.selector, 1e18, 0));
        vm.prank(address(node));
        digiftAdapter.requestRedeem(0, address(node), address(node));
    }

    function test_requestRedeem_ControllerNotSender() external {
        vm.expectRevert(DigiftAdapter.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.requestRedeem(1000e18, address(this), address(node));
    }

    function test_requestRedeem_OwnerNotSender() external {
        vm.expectRevert(DigiftAdapter.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.requestRedeem(1000e18, address(node), address(this));
    }

    function test_requestRedeem_RedeemRequestPending() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(sharesToMint / 2);

        vm.expectRevert(DigiftAdapter.RedeemRequestPending.selector);
        vm.prank(address(node));
        digiftAdapter.requestRedeem(1000e6, address(node), address(node));
    }

    function test_requestRedeem_RedeemRequestNotClaimed() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);
        _settleRedeem(node, assetsToReturn, 0);

        vm.expectRevert(DigiftAdapter.RedeemRequestNotClaimed.selector);
        vm.prank(address(node));
        digiftAdapter.requestRedeem(1000e6, address(node), address(node));
    }

    function test_mint_BelowLimit() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.BelowLimit.selector, 1, 0));

        vm.prank(address(node));
        digiftAdapter.mint(0, address(node), address(node));
    }

    function test_mint_ControllerNotSender() external {
        vm.expectRevert(DigiftAdapter.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.mint(1000e6, address(node), address(this));
    }

    function test_mint_OwnerNotSender() external {
        vm.expectRevert(DigiftAdapter.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.mint(1000e6, address(this), address(node));
    }

    function test_mint_DepositRequestNotFulfilled() external {
        vm.expectRevert(DigiftAdapter.DepositRequestNotFulfilled.selector);
        vm.prank(address(node));
        digiftAdapter.mint(1000e6, address(node), address(node));
    }

    function test_mint_MintAllSharesOnly() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);

        vm.expectRevert(DigiftAdapter.MintAllSharesOnly.selector);
        vm.prank(address(node));
        digiftAdapter.mint(sharesToMint / 2, address(node), address(node));
    }

    function test_withdraw_BelowLimit() external {
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.BelowLimit.selector, 1, 0));
        vm.prank(address(node));
        digiftAdapter.withdraw(0, address(node), address(node));
    }

    function test_withdraw_ControllerNotSender() external {
        vm.expectRevert(DigiftAdapter.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.withdraw(1000e6, address(node), address(this));
    }

    function test_withdraw_OwnerNotSender() external {
        vm.expectRevert(DigiftAdapter.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftAdapter.withdraw(1000e6, address(this), address(node));
    }

    function test_withdraw_RedeemRequestNotFulfilled() external {
        vm.expectRevert(DigiftAdapter.RedeemRequestNotFulfilled.selector);
        vm.prank(address(node));
        digiftAdapter.withdraw(1000e6, address(node), address(node));
    }

    function test_withdraw_WithdrawAllAssetsOnly() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);
        _settleRedeem(node, assetsToReturn, 0);

        vm.expectRevert(DigiftAdapter.WithdrawAllAssetsOnly.selector);
        vm.prank(address(node));
        digiftAdapter.withdraw(assetsToReturn / 2, address(node), address(node));
    }

    function test_settleDeposit_NothingToSettle() external {
        vm.expectRevert(DigiftAdapter.NothingToSettle.selector);
        _settleDeposit(node, 1000e6, 0);
    }

    function test_settleDeposit_NoPendingDepositRequest() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);

        DigiftEventVerifier.OffchainArgs memory fargs;
        DigiftEventVerifier.OnchainArgs memory nargs = DigiftEventVerifier.OnchainArgs(
            DigiftEventVerifier.EventType.SUBSCRIBE, address(subRedManagement), address(stToken), address(asset)
        );
        vm.mockCall(
            digiftEventVerifier,
            abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
            abi.encode(sharesToMint, 0)
        );
        vm.startPrank(manager);
        address[] memory nodes = new address[](2);
        // pass two times the same node
        nodes[0] = address(node);
        nodes[1] = address(node);
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NoPendingDepositRequest.selector, address(node)));
        digiftAdapter.settleDeposit(nodes, fargs);
        vm.stopPrank();
    }

    function test_settleDeposit_SettlementNotInRange() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);

        {
            uint256 insufficientShares = sharesToMint * 98 / 100;
            vm.expectRevert(
                abi.encodeWithSelector(
                    DigiftAdapter.SettlementNotInRange.selector,
                    depositAmount,
                    digiftAdapter.convertToAssets(insufficientShares)
                )
            );
            _settleDeposit(node, insufficientShares, 0);
        }
        {
            uint256 insufficientAssets = (depositAmount / 2) * 99 / 100;
            uint256 insufficientShares = (sharesToMint / 2) * 99 / 100;
            vm.expectRevert(
                abi.encodeWithSelector(
                    DigiftAdapter.SettlementNotInRange.selector,
                    depositAmount,
                    insufficientAssets + digiftAdapter.convertToAssets(insufficientShares)
                )
            );
            _settleDeposit(node, insufficientShares, insufficientAssets);
        }
        {
            uint256 assets = depositAmount / 2;
            uint256 shares = sharesToMint / 2;
            // no revert
            _settleDeposit(node, shares, assets);
        }
    }

    function test_settleRedeem_NothingToSettle() external {
        vm.expectRevert(DigiftAdapter.NothingToSettle.selector);
        _settleRedeem(node, 1000e6, 0);
    }

    function test_settleRedeem_NoPendingRedeemRequest() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);

        DigiftEventVerifier.OffchainArgs memory fargs;
        DigiftEventVerifier.OnchainArgs memory nargs = DigiftEventVerifier.OnchainArgs(
            DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), address(stToken), address(asset)
        );
        vm.mockCall(
            digiftEventVerifier,
            abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
            abi.encode(0, assetsToReturn)
        );
        vm.startPrank(manager);
        // pass two times the same node
        address[] memory nodes = new address[](2);
        nodes[0] = address(node);
        nodes[1] = address(node);
        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NoPendingRedeemRequest.selector, address(node)));
        digiftAdapter.settleRedeem(nodes, fargs);
        vm.stopPrank();
    }

    function test_settleRedeem_SettlementNotInRange() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);

        {
            uint256 insufficientAssets = assetsToReturn * 98 / 100;
            vm.expectRevert(
                abi.encodeWithSelector(
                    DigiftAdapter.SettlementNotInRange.selector,
                    toLiquidate,
                    digiftAdapter.convertToShares(insufficientAssets)
                )
            );
            _settleRedeem(node, insufficientAssets, 0);
        }
        {
            uint256 insufficientAssets = (assetsToReturn / 2) * 99 / 100;
            uint256 insufficientShares = (toLiquidate / 2) * 99 / 100;
            vm.expectRevert(
                abi.encodeWithSelector(
                    DigiftAdapter.SettlementNotInRange.selector,
                    toLiquidate,
                    insufficientShares + digiftAdapter.convertToShares(insufficientAssets)
                )
            );
            _settleRedeem(node, insufficientAssets, insufficientShares);
        }
        {
            uint256 assets = assetsToReturn / 2;
            uint256 shares = toLiquidate / 2;
            // no revert
            _settleRedeem(node, assets, shares);
        }
    }

    // =============================
    //      Unsupported Function Tests
    // =============================

    function test_deposit_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.deposit(1000e6, address(node), address(node));
    }

    function test_deposit_single_param_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.deposit(1000e6, address(node));
    }

    function test_mint_single_param_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.mint(1000e6, address(node));
    }

    function test_redeem_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.redeem(1000e6, address(node), address(node));
    }

    function test_previewDeposit_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.previewDeposit(1000e6);
    }

    function test_previewMint_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.previewMint(1000e6);
    }

    function test_previewWithdraw_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.previewWithdraw(1000e6);
    }

    function test_previewRedeem_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.previewRedeem(1000e6);
    }

    function test_maxRedeem_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.maxRedeem(address(node));
    }

    function test_maxDeposit_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.maxDeposit(address(node));
    }

    function test_setOperator_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.setOperator(address(this), true);
    }

    function test_isOperator_Unsupported() external {
        vm.expectRevert(DigiftAdapter.Unsupported.selector);
        digiftAdapter.isOperator(address(node), address(this));
    }

    // =============================
    //      View Function Tests
    // =============================

    function test_totalAssets_initialState() external view {
        assertEq(digiftAdapter.totalAssets(), 0, "Total assets should be 0 initially");
    }

    function test_totalAssets_afterMinting() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);

        // After minting shares, totalAssets should equal convertToAssets(totalSupply())
        uint256 totalSupply = digiftAdapter.totalSupply();
        uint256 expectedTotalAssets = digiftAdapter.convertToAssets(totalSupply);
        uint256 actualTotalAssets = digiftAdapter.totalAssets();

        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
        assertEq(totalSupply, sharesToMint, "Total supply should equal minted shares");
    }

    function test_totalAssets_afterPartialMint() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 partialShares = sharesToMint * 8 / 10;
        uint256 assetsUsed = digiftAdapter.convertToAssets(partialShares);
        uint256 assetsToReimburse = depositAmount - assetsUsed;

        _forward();
        _settleSubscription(partialShares, assetsToReimburse, 0);
        _settleDeposit(node, partialShares, assetsToReimburse);
        _mint(node);

        // After partial minting, totalAssets should reflect the partial shares
        uint256 totalSupply = digiftAdapter.totalSupply();
        uint256 expectedTotalAssets = digiftAdapter.convertToAssets(totalSupply);
        uint256 actualTotalAssets = digiftAdapter.totalAssets();

        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
        assertEq(totalSupply, partialShares, "Total supply should equal partial minted shares");
    }

    function test_totalAssets_afterWithdrawal() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftAdapter.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftAdapter.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);
        _settleRedeem(node, assetsToReturn, 0);
        _withdraw(node, assetsToReturn);

        // After withdrawal, totalAssets should reflect remaining shares
        uint256 totalSupply = digiftAdapter.totalSupply();
        uint256 expectedTotalAssets = digiftAdapter.convertToAssets(totalSupply);
        uint256 actualTotalAssets = digiftAdapter.totalAssets();

        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
        assertEq(totalSupply, sharesToMint - toLiquidate, "Total supply should equal remaining shares");
    }

    function test_decimals() external view {
        uint8 expectedDecimals = stToken.decimals();
        uint8 actualDecimals = digiftAdapter.decimals();
        assertEq(actualDecimals, expectedDecimals, "decimals() should return stToken decimals");
    }

    function test_share() external view {
        address expectedShare = address(digiftAdapter);
        address actualShare = digiftAdapter.share();
        assertEq(actualShare, expectedShare, "share() should return adapter contract address");
    }

    function test_supportsInterface() external view {
        assertTrue(digiftAdapter.supportsInterface(type(IERC165).interfaceId), "Must support IERC165");
        assertTrue(digiftAdapter.supportsInterface(type(IERC7575).interfaceId), "Must support IERC7575");
        assertTrue(digiftAdapter.supportsInterface(type(IERC7540Deposit).interfaceId), "Must support IERC7540Deposit");
        assertTrue(digiftAdapter.supportsInterface(type(IERC7540Redeem).interfaceId), "Must support IERC7540Redeem");
        assertFalse(
            digiftAdapter.supportsInterface(bytes4(keccak256("UnknownInterface()"))),
            "Must not support unknown interfaces"
        );
    }

    function test_two_nodes_deposits() external {
        uint256 dAmount1 = _invest();
        uint256 dAmount2 = _invest2();

        uint256 shares1 = digiftAdapter.convertToShares(dAmount1);
        uint256 shares2 = digiftAdapter.convertToShares(dAmount2);

        uint256 sharesSum = shares1 + shares2;

        assertEq(digiftAdapter.accumulatedDeposit(), dAmount1 + dAmount2, "Accumulated deposit");

        _forward();
        _settleSubscription(sharesSum, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotAllNodesSettled.selector));
        _settleDeposit(node, sharesSum, 0);

        {
            DigiftEventVerifier.OffchainArgs memory fargs;
            DigiftEventVerifier.OnchainArgs memory nargs = DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.SUBSCRIBE, address(subRedManagement), address(stToken), address(asset)
            );
            vm.mockCall(
                digiftEventVerifier,
                abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
                abi.encode(shares1 + shares2, 0)
            );
            vm.startPrank(manager);
            address[] memory nodes = new address[](2);
            nodes[0] = address(node);
            nodes[1] = address(node2);
            // check correct dust handling
            vm.expectEmit(true, true, true, true);
            emit DigiftAdapter.DepositSettled(address(node), shares1 - 1, 0);
            vm.expectEmit(true, true, true, true);
            emit DigiftAdapter.DepositSettled(address(node2), shares2 + 1, 0);
            digiftAdapter.settleDeposit(nodes, fargs);
            vm.stopPrank();
        }
    }

    function test_two_nodes_redeems() external {
        uint256 dAmount1 = _invest();
        uint256 dAmount2 = _invest2();

        uint256 shares1 = digiftAdapter.convertToShares(dAmount1);
        uint256 shares2 = digiftAdapter.convertToShares(dAmount2);

        uint256 sharesSum = shares1 + shares2;

        uint256 assets1 = digiftAdapter.convertToAssets(shares1);
        uint256 assets2 = digiftAdapter.convertToAssets(shares2);
        // imitate small loss to impact dust
        uint256 assetsToReturn = digiftAdapter.convertToAssets(sharesSum) - 1;

        assertEq(assets1 + (assets2 + 1), assetsToReturn, "Assets to return");

        _forward();
        _settleSubscription(sharesSum, 0, 0);

        {
            DigiftEventVerifier.OffchainArgs memory fargs;
            DigiftEventVerifier.OnchainArgs memory nargs = DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.SUBSCRIBE, address(subRedManagement), address(stToken), address(asset)
            );
            vm.mockCall(
                digiftEventVerifier,
                abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
                abi.encode(shares1 + shares2, 0)
            );
            vm.startPrank(manager);
            address[] memory nodes = new address[](2);
            nodes[0] = address(node);
            nodes[1] = address(node2);
            // check correct dust handling
            vm.expectEmit(true, true, true, true);
            emit DigiftAdapter.DepositSettled(address(node), shares1 - 1, 0);
            vm.expectEmit(true, true, true, true);
            emit DigiftAdapter.DepositSettled(address(node2), shares2 + 1, 0);
            digiftAdapter.settleDeposit(nodes, fargs);
            vm.stopPrank();
        }

        _mint(node);
        _mint(node2);
        _liquidate(shares1 - 1);
        _liquidate2(shares2 + 1);

        _forward();

        _settleRedemption(0, assetsToReturn, 0);

        vm.expectRevert(abi.encodeWithSelector(DigiftAdapter.NotAllNodesSettled.selector));
        _settleRedeem(node, assetsToReturn, 0);

        {
            DigiftEventVerifier.OffchainArgs memory fargs;
            DigiftEventVerifier.OnchainArgs memory nargs = DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), address(stToken), address(asset)
            );
            vm.mockCall(
                digiftEventVerifier,
                abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
                abi.encode(0, assetsToReturn)
            );
            vm.startPrank(manager);
            address[] memory nodes = new address[](2);
            nodes[0] = address(node);
            nodes[1] = address(node2);
            // check correct dust handling
            vm.expectEmit(true, true, true, true);
            emit DigiftAdapter.RedeemSettled(address(node), 0, assets1);
            vm.expectEmit(true, true, true, true);
            emit DigiftAdapter.RedeemSettled(address(node2), 0, assets2 + 1);
            digiftAdapter.settleRedeem(nodes, fargs);
            vm.stopPrank();
        }
    }

    function test_fuzz_convertToAssets_convertToShares(uint256 shares) external view {
        shares = bound(shares, 1, 1e36);
        uint256 assets = digiftAdapter.convertToAssets(shares);
        uint256 calculatedShares = digiftAdapter.convertToShares(assets);
        // since stToken has 18 decimals and USDC only 6 decimals
        uint256 realisticLoss = digiftAdapter.convertToShares(1) * 2;
        assertApproxEqAbs(shares, calculatedShares, realisticLoss, "convertToAssets => convertToShares without loss");
    }

    function test_fuzz_convertToShares_convertToAssets(uint256 assets) external view {
        assets = bound(assets, 1, 1e36);
        uint256 shares = digiftAdapter.convertToShares(assets);
        uint256 calculatedAssets = digiftAdapter.convertToAssets(shares);
        assertApproxEqAbs(assets, calculatedAssets, 2, "convertToShares => convertToAssets without loss");
    }
}
