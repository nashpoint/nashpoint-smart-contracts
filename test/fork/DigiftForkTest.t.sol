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
import {ComponentAllocation, INode} from "src/interfaces/INode.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract DigiftForkTest is BaseTest {
    DigiftWrapper digiftWrapper;
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

        address digiftWrapperImpl =
            address(new DigiftWrapper(address(subRedManagement), address(registry), digiftEventVerifier));

        DigiftWrapperFactory dFactory = new DigiftWrapperFactory(digiftWrapperImpl, address(this));

        digiftWrapper = dFactory.deploy(
            DigiftWrapper.InitArgs(
                "stToken Wrapper",
                "wst",
                address(asset),
                usdcPriceOracle,
                address(stToken),
                address(dFeedPriceOracle),
                // 0.1%
                1e15,
                10 days
            )
        );

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(digiftWrapper), true);
        vm.stopPrank();

        // DififtWrapper is whitelisted
        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isWhiteInvestor.selector, address(digiftWrapper)),
            abi.encode(true)
        );
        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isWhiteContract.selector, address(digiftWrapper)),
            abi.encode(true)
        );
        // allow us minting of stToken to SubRedManagement and settle subscription
        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isContractManager.selector, address(this)),
            abi.encode(true)
        );

        // create Node2 and invest into DigiftWrapper
        vm.startPrank(owner);
        ComponentAllocation[] memory allocations = new ComponentAllocation[](1);
        allocations[0] = ComponentAllocation({
            targetWeight: 0.9 ether,
            maxDelta: 0.01 ether,
            router: address(router7540),
            isComponent: true
        });
        (node2,) = factory.deployFullNode(
            "Test Node 2",
            "TNODE2",
            address(asset),
            owner,
            _toArray(address(digiftWrapper)),
            allocations,
            0.1 ether,
            address(rebalancer),
            address(quoter),
            bytes32(uint256(2))
        );
        node2.setMaxDepositSize(1e36);
        digiftWrapper.setNode(address(node2), true);

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
        node.addComponent(address(digiftWrapper), ALLOCATION, 0.01 ether, address(router7540));
        digiftWrapper.setManager(manager, true);
        digiftWrapper.setNode(address(node), true);
        digiftWrapper.setNode(address(node2), true);
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
        uint256 depositAmount = router7540.investInAsyncComponent(address(node), address(digiftWrapper));
        vm.stopPrank();
        return depositAmount;
    }

    function _invest2() internal returns (uint256) {
        vm.startPrank(rebalancer);
        uint256 depositAmount = router7540.investInAsyncComponent(address(node2), address(digiftWrapper));
        vm.stopPrank();
        return depositAmount;
    }

    function _liquidate(uint256 amount) internal {
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), address(digiftWrapper), amount);
        vm.stopPrank();
    }

    function _liquidate2(uint256 amount) internal {
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node2), address(digiftWrapper), amount);
        vm.stopPrank();
    }

    function _forward() internal {
        vm.startPrank(manager);
        digiftWrapper.forwardRequestsToDigift();
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
        digiftWrapper.settleDeposit(nodes, fargs);
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
        digiftWrapper.settleRedeem(nodes, fargs);
        vm.stopPrank();
    }

    function _updateTotalAssets() internal {
        vm.startPrank(rebalancer);
        node.updateTotalAssets();
        vm.stopPrank();
    }

    function _settleSubscription(uint256 stTokens, uint256 assets, uint256 fee) internal {
        address[] memory investorList = new address[](1);
        investorList[0] = address(digiftWrapper);
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
        investorList[0] = address(digiftWrapper);
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
        router7540.mintClaimableShares(address(node), address(digiftWrapper));
        vm.stopPrank();
    }

    function _withdraw(INode node, uint256 assets) internal {
        vm.startPrank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(digiftWrapper), assets);
        vm.stopPrank();
    }

    function test_deployment_success() external view {
        assertEq(address(digiftWrapper.subRedManagement()), address(subRedManagement));
        assertEq(address(digiftWrapper.digiftEventVerifier()), digiftEventVerifier);
    }

    function test_investInAsyncComponent_success() external {
        uint256 balance = asset.balanceOf(address(node));

        vm.expectEmit(true, true, true, true, address(digiftWrapper));
        emit IERC7540Deposit.DepositRequest(address(node), address(node), 0, address(node), INVEST_AMOUNT);
        uint256 depositAmount = _invest();
        assertEq(depositAmount, INVEST_AMOUNT, "Invested according to allocation");

        assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), INVEST_AMOUNT);
        assertEq(digiftWrapper.accumulatedDeposit(), depositAmount, "Accumulated whole deposit amount");

        vm.startPrank(address(node));
        assertEq(router7540.getComponentAssets(address(digiftWrapper), false), INVEST_AMOUNT);
        vm.stopPrank();

        assertEq(node.totalAssets(), balance);

        _updateTotalAssets();

        assertEq(node.totalAssets(), balance);
    }

    function test_forwardRequestsToDigift_one_deposit_only() external {
        uint256 depositAmount = _invest();

        vm.expectEmit(true, true, true, true, address(subRedManagement));
        emit ISubRedManagement.Subscribe(
            address(subRedManagement), address(stToken), address(asset), address(digiftWrapper), INVEST_AMOUNT
        );
        vm.expectEmit(true, true, true, true, address(digiftWrapper));
        emit DigiftWrapper.DigiftSubscribed(depositAmount);
        _forward();

        assertEq(digiftWrapper.globalPendingDepositRequest(), depositAmount, "Pending whole deposit amount");

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.DepositRequestPending.selector));
        _forward();
    }

    function test_settleDeposit_success() external {
        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.DepositSettled(address(node), sharesToMint, 0);
        _settleDeposit(node, sharesToMint, 0);

        assertEq(digiftWrapper.globalPendingDepositRequest(), 0, "After settle there is nothing pending");
        assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
        assertEq(
            digiftWrapper.claimableDepositRequest(0, address(node)),
            INVEST_AMOUNT,
            "All deposit amount is claimable now"
        );
        assertEq(digiftWrapper.maxMint(address(node)), sharesToMint, "maxMint reflects shares to mint");
    }

    function test_mintClaimableShares_success() external {
        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);

        assertEq(digiftWrapper.balanceOf(address(node)), 0, "Node has no shares of digift wrapper");

        _settleDeposit(node, sharesToMint, 0);

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Deposit(address(node), address(node), depositAmount, sharesToMint);
        _mint(node);

        assertEq(digiftWrapper.balanceOf(address(node)), sharesToMint, "Shares are minted to node");
        assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
        assertEq(digiftWrapper.claimableDepositRequest(0, address(node)), 0, "Everything is claimed");
        assertEq(digiftWrapper.maxMint(address(node)), 0, "Nothing to mint");
    }

    function test_mintClaimableShares_partialMintWithReimbursement() external {
        uint256 depositAmount = _invest();
        uint256 initialNodeAssetBalance = asset.balanceOf(address(node));

        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        // 80% of expected shares
        uint256 partialShares = sharesToMint * 8 / 10;
        uint256 assetsUsed = digiftWrapper.convertToAssets(partialShares);
        uint256 assetsToReimburse = depositAmount - assetsUsed;

        _forward();
        _settleSubscription(partialShares, assetsToReimburse, 0);

        assertEq(digiftWrapper.balanceOf(address(node)), 0, "Node has no shares initially");

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.DepositSettled(address(node), partialShares, assetsToReimburse);
        _settleDeposit(node, partialShares, assetsToReimburse);

        assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
        assertEq(
            digiftWrapper.claimableDepositRequest(0, address(node)), depositAmount, "All deposit amount is claimable"
        );
        assertEq(digiftWrapper.maxMint(address(node)), partialShares, "maxMint reflects partial shares");

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Deposit(address(node), address(node), assetsUsed, partialShares);
        _mint(node);

        assertEq(digiftWrapper.balanceOf(address(node)), partialShares, "Partial shares are minted to node");
        assertEq(digiftWrapper.claimableDepositRequest(0, address(node)), 0, "Everything is claimed");
        assertEq(digiftWrapper.maxMint(address(node)), 0, "Nothing to mint");

        uint256 finalNodeAssetBalance = asset.balanceOf(address(node));
        uint256 expectedFinalBalance = initialNodeAssetBalance + assetsToReimburse;
        assertEq(finalNodeAssetBalance, expectedFinalBalance, "Node received asset reimbursement");
    }

    function test_requestAsyncWithdrawal_success() external {
        uint256 balance = asset.balanceOf(address(node));

        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);

        _mint(node);

        assertEq(node.totalAssets(), balance);

        vm.expectEmit(true, true, true, true, address(digiftWrapper));
        emit IERC7540Redeem.RedeemRequest(address(node), address(node), 0, address(node), toLiquidate);
        _liquidate(toLiquidate);

        assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), toLiquidate);
        assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0);
        assertEq(digiftWrapper.accumulatedRedemption(), toLiquidate);

        _updateTotalAssets();

        assertApproxEqAbs(node.totalAssets(), balance, 2);
    }

    function test_forwardRequestsToDigift_one_redeem_only() external {
        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);

        vm.expectEmit(true, true, true, true, address(subRedManagement));
        emit ISubRedManagement.Redeem(
            address(subRedManagement), address(stToken), address(asset), address(digiftWrapper), toLiquidate
        );
        _forward();
        assertEq(digiftWrapper.globalPendingRedeemRequest(), toLiquidate);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.RedeemRequestPending.selector));
        _forward();
    }

    function test_settleRedeem_success() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.RedeemSettled(address(node), 0, assetsToReturn);
        _settleRedeem(node, assetsToReturn, 0);

        assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), 0);
        assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), toLiquidate);
        assertEq(digiftWrapper.maxWithdraw(address(node)), assetsToReturn);
    }

    function test_withdraw_success() external {
        uint256 balance = asset.balanceOf(address(node));

        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

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

        assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), 0);
        assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0);
        assertEq(digiftWrapper.maxWithdraw(address(node)), 0);

        _updateTotalAssets();

        assertApproxEqAbs(node.totalAssets(), balance, 4);
    }

    function test_withdraw_partialRedeemWithReimbursement() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 initialNodeShareBalance = digiftWrapper.balanceOf(address(node));

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);

        assertEq(digiftWrapper.balanceOf(address(node)), sharesToMint, "Node has shares initially");

        uint256 sharesToRedeem = sharesToMint;
        _liquidate(sharesToRedeem);

        uint256 expectedAssets = digiftWrapper.convertToAssets(sharesToRedeem);
        // 80% of expected assets
        uint256 partialAssets = expectedAssets * 8 / 10;
        uint256 sharesUsed = digiftWrapper.convertToShares(partialAssets);
        uint256 sharesToReimburse = sharesToRedeem - sharesUsed;

        _forward();
        _settleRedemption(sharesToReimburse, partialAssets, 0);

        vm.expectEmit(true, true, true, true);
        emit DigiftWrapper.RedeemSettled(address(node), sharesToReimburse, partialAssets);
        _settleRedeem(node, partialAssets, sharesToReimburse);

        assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), 0, "No pending shares to redeem");
        assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), sharesToRedeem, "All shares are claimable");
        assertEq(digiftWrapper.maxWithdraw(address(node)), partialAssets, "maxWithdraw reflects partial assets");

        vm.expectEmit(true, true, true, true);
        emit IERC7575.Withdraw(address(node), address(node), address(node), partialAssets, sharesUsed);
        _withdraw(node, partialAssets);

        assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0, "Everything is claimed");
        assertEq(digiftWrapper.maxWithdraw(address(node)), 0, "Nothing to withdraw");

        uint256 finalNodeShareBalance = digiftWrapper.balanceOf(address(node));
        uint256 expectedFinalShareBalance = initialNodeShareBalance + sharesToReimburse;
        assertEq(finalNodeShareBalance, expectedFinalShareBalance, "Node received share reimbursement");
    }

    // =============================
    //      Custom Error Tests
    // =============================

    function test_requestDeposit_ZeroAmount() external {
        vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
        vm.prank(address(node));
        digiftWrapper.requestDeposit(0, address(node), address(node));
    }

    function test_requestDeposit_ControllerNotSender() external {
        vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(this), address(node));
    }

    function test_requestDeposit_OwnerNotSender() external {
        vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(node), address(this));
    }

    function test_requestDeposit_DepositRequestPending() external {
        _invest();
        vm.expectRevert(DigiftWrapper.DepositRequestPending.selector);
        vm.prank(address(node));
        digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(node), address(node));
    }

    function test_requestDeposit_DepositRequestNotClaimed() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);

        vm.expectRevert(DigiftWrapper.DepositRequestNotClaimed.selector);
        vm.prank(address(node));
        digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(node), address(node));
    }

    function test_requestRedeem_ZeroAmount() external {
        vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
        vm.prank(address(node));
        digiftWrapper.requestRedeem(0, address(node), address(node));
    }

    function test_requestRedeem_ControllerNotSender() external {
        vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.requestRedeem(1000e6, address(this), address(node));
    }

    function test_requestRedeem_OwnerNotSender() external {
        vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.requestRedeem(1000e6, address(node), address(this));
    }

    function test_requestRedeem_RedeemRequestPending() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(sharesToMint / 2);

        vm.expectRevert(DigiftWrapper.RedeemRequestPending.selector);
        vm.prank(address(node));
        digiftWrapper.requestRedeem(1000e6, address(node), address(node));
    }

    function test_requestRedeem_RedeemRequestNotClaimed() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);
        _settleRedeem(node, assetsToReturn, 0);

        vm.expectRevert(DigiftWrapper.RedeemRequestNotClaimed.selector);
        vm.prank(address(node));
        digiftWrapper.requestRedeem(1000e6, address(node), address(node));
    }

    function test_mint_ZeroAmount() external {
        vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
        vm.prank(address(node));
        digiftWrapper.mint(0, address(node), address(node));
    }

    function test_mint_ControllerNotSender() external {
        vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.mint(1000e6, address(node), address(this));
    }

    function test_mint_OwnerNotSender() external {
        vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.mint(1000e6, address(this), address(node));
    }

    function test_mint_DepositRequestNotFulfilled() external {
        vm.expectRevert(DigiftWrapper.DepositRequestNotFulfilled.selector);
        vm.prank(address(node));
        digiftWrapper.mint(1000e6, address(node), address(node));
    }

    function test_mint_MintAllSharesOnly() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);

        vm.expectRevert(DigiftWrapper.MintAllSharesOnly.selector);
        vm.prank(address(node));
        digiftWrapper.mint(sharesToMint / 2, address(node), address(node));
    }

    function test_withdraw_ZeroAmount() external {
        vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
        vm.prank(address(node));
        digiftWrapper.withdraw(0, address(node), address(node));
    }

    function test_withdraw_ControllerNotSender() external {
        vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.withdraw(1000e6, address(node), address(this));
    }

    function test_withdraw_OwnerNotSender() external {
        vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
        vm.prank(address(node));
        digiftWrapper.withdraw(1000e6, address(this), address(node));
    }

    function test_withdraw_RedeemRequestNotFulfilled() external {
        vm.expectRevert(DigiftWrapper.RedeemRequestNotFulfilled.selector);
        vm.prank(address(node));
        digiftWrapper.withdraw(1000e6, address(node), address(node));
    }

    function test_withdraw_WithdrawAllAssetsOnly() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);
        _liquidate(toLiquidate);
        _forward();
        _settleRedemption(0, assetsToReturn, 0);
        _settleRedeem(node, assetsToReturn, 0);

        vm.expectRevert(DigiftWrapper.WithdrawAllAssetsOnly.selector);
        vm.prank(address(node));
        digiftWrapper.withdraw(assetsToReturn / 2, address(node), address(node));
    }

    function test_settleDeposit_NothingToSettle() external {
        vm.expectRevert(DigiftWrapper.NothingToSettle.selector);
        _settleDeposit(node, 1000e6, 0);
    }

    function test_settleRedeem_NothingToSettle() external {
        vm.expectRevert(DigiftWrapper.NothingToSettle.selector);
        _settleRedeem(node, 1000e6, 0);
    }

    // =============================
    //      Unsupported Function Tests
    // =============================

    function test_deposit_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.deposit(1000e6, address(node), address(node));
    }

    function test_deposit_single_param_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.deposit(1000e6, address(node));
    }

    function test_mint_single_param_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.mint(1000e6, address(node));
    }

    function test_redeem_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.redeem(1000e6, address(node), address(node));
    }

    function test_previewDeposit_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.previewDeposit(1000e6);
    }

    function test_previewMint_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.previewMint(1000e6);
    }

    function test_previewWithdraw_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.previewWithdraw(1000e6);
    }

    function test_previewRedeem_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.previewRedeem(1000e6);
    }

    function test_maxRedeem_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.maxRedeem(address(node));
    }

    function test_maxDeposit_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.maxDeposit(address(node));
    }

    function test_setOperator_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.setOperator(address(this), true);
    }

    function test_isOperator_Unsupported() external {
        vm.expectRevert(DigiftWrapper.Unsupported.selector);
        digiftWrapper.isOperator(address(node), address(this));
    }

    // =============================
    //      View Function Tests
    // =============================

    function test_totalAssets_initialState() external view {
        assertEq(digiftWrapper.totalAssets(), 0, "Total assets should be 0 initially");
    }

    function test_totalAssets_afterMinting() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        _forward();
        _settleSubscription(sharesToMint, 0, 0);
        _settleDeposit(node, sharesToMint, 0);
        _mint(node);

        // After minting shares, totalAssets should equal convertToAssets(totalSupply())
        uint256 totalSupply = digiftWrapper.totalSupply();
        uint256 expectedTotalAssets = digiftWrapper.convertToAssets(totalSupply);
        uint256 actualTotalAssets = digiftWrapper.totalAssets();

        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
        assertEq(totalSupply, sharesToMint, "Total supply should equal minted shares");
    }

    function test_totalAssets_afterPartialMint() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 partialShares = sharesToMint * 8 / 10;
        uint256 assetsUsed = digiftWrapper.convertToAssets(partialShares);
        uint256 assetsToReimburse = depositAmount - assetsUsed;

        _forward();
        _settleSubscription(partialShares, assetsToReimburse, 0);
        _settleDeposit(node, partialShares, assetsToReimburse);
        _mint(node);

        // After partial minting, totalAssets should reflect the partial shares
        uint256 totalSupply = digiftWrapper.totalSupply();
        uint256 expectedTotalAssets = digiftWrapper.convertToAssets(totalSupply);
        uint256 actualTotalAssets = digiftWrapper.totalAssets();

        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
        assertEq(totalSupply, partialShares, "Total supply should equal partial minted shares");
    }

    function test_totalAssets_afterWithdrawal() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

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
        uint256 totalSupply = digiftWrapper.totalSupply();
        uint256 expectedTotalAssets = digiftWrapper.convertToAssets(totalSupply);
        uint256 actualTotalAssets = digiftWrapper.totalAssets();

        assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
        assertEq(totalSupply, sharesToMint - toLiquidate, "Total supply should equal remaining shares");
    }

    function test_decimals() external view {
        uint8 expectedDecimals = stToken.decimals();
        uint8 actualDecimals = digiftWrapper.decimals();
        assertEq(actualDecimals, expectedDecimals, "decimals() should return stToken decimals");
    }

    function test_share() external view {
        address expectedShare = address(digiftWrapper);
        address actualShare = digiftWrapper.share();
        assertEq(actualShare, expectedShare, "share() should return wrapper contract address");
    }

    function test_supportsInterface() external view {
        assertTrue(digiftWrapper.supportsInterface(type(IERC165).interfaceId), "Must support IERC165");
        assertTrue(digiftWrapper.supportsInterface(type(IERC7575).interfaceId), "Must support IERC7575");
        assertTrue(digiftWrapper.supportsInterface(type(IERC7540Deposit).interfaceId), "Must support IERC7540Deposit");
        assertTrue(digiftWrapper.supportsInterface(type(IERC7540Redeem).interfaceId), "Must support IERC7540Redeem");
        assertFalse(
            digiftWrapper.supportsInterface(bytes4(keccak256("UnknownInterface()"))),
            "Must not support unknown interfaces"
        );
    }
    // _forward();
    // _settleSubscription(sharesToMint, 0, 0);
    // _settleDeposit(node, sharesToMint, 0);
    // _mint(node);
    // _liquidate(toLiquidate);
    // _forward();
    // _settleRedemption(0, assetsToReturn, 0);
    // _settleRedeem(node, assetsToReturn, 0);
    // _withdraw(node, assetsToReturn);

    function test_two_nodes_deposits() external {
        uint256 dAmount1 = _invest();
        uint256 dAmount2 = _invest2();

        uint256 shares1 = digiftWrapper.convertToShares(dAmount1);
        uint256 shares2 = digiftWrapper.convertToShares(dAmount2);

        uint256 sharesSum = shares1 + shares2;

        assertEq(digiftWrapper.accumulatedDeposit(), dAmount1 + dAmount2, "Accumulated deposit");

        _forward();
        _settleSubscription(sharesSum, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotAllNodesSettled.selector));
        _settleDeposit(node, shares1, 0);

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
            emit DigiftWrapper.DepositSettled(address(node), shares1 - 1, 0);
            vm.expectEmit(true, true, true, true);
            emit DigiftWrapper.DepositSettled(address(node2), shares2 + 1, 0);
            digiftWrapper.settleDeposit(nodes, fargs);
            vm.stopPrank();
        }
    }

    function test_two_nodes_redeems() external {
        uint256 dAmount1 = _invest();
        uint256 dAmount2 = _invest2();

        uint256 shares1 = digiftWrapper.convertToShares(dAmount1);
        uint256 shares2 = digiftWrapper.convertToShares(dAmount2);

        uint256 sharesSum = shares1 + shares2;

        uint256 assets1 = digiftWrapper.convertToAssets(shares1);
        uint256 assets2 = digiftWrapper.convertToAssets(shares2);
        // imitate small loss to impact dust
        uint256 assetsToReturn = digiftWrapper.convertToAssets(sharesSum) - 1;

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
            emit DigiftWrapper.DepositSettled(address(node), shares1 - 1, 0);
            vm.expectEmit(true, true, true, true);
            emit DigiftWrapper.DepositSettled(address(node2), shares2 + 1, 0);
            digiftWrapper.settleDeposit(nodes, fargs);
            vm.stopPrank();
        }

        _mint(node);
        _mint(node2);
        _liquidate(shares1 - 1);
        _liquidate2(shares2 + 1);

        _forward();

        _settleRedemption(0, assetsToReturn, 0);

        vm.expectRevert(abi.encodeWithSelector(DigiftWrapper.NotAllNodesSettled.selector));
        _settleRedeem(node, assets2, 0);

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
            emit DigiftWrapper.RedeemSettled(address(node), 0, assets1);
            vm.expectEmit(true, true, true, true);
            emit DigiftWrapper.RedeemSettled(address(node2), 0, assets2 + 1);
            digiftWrapper.settleRedeem(nodes, fargs);
            vm.stopPrank();
        }
    }
}
