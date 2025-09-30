// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";
import {DigiftWrapperFactory} from "src/wrappers/digift/DigiftWrapperFactory.sol";
import {DigiftWrapper} from "src/wrappers/digift/DigiftWrapper.sol";
import {ISubRedManagement, IDFeedPriceOracle, IManagement, ISecurityToken} from "src/interfaces/external/IDigift.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract DigiftForkTest is BaseTest {
    DigiftWrapper digiftWrapper;
    address digiftEventVerifier = makeAddr("digiftEventVerifier");

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

        _userDeposits(user, DEPOSIT_AMOUNT);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        // remove mock ERC4626 vault
        node.removeComponent(address(vault), false);
        vm.stopPrank();

        address digiftWrapperImpl =
            address(new DigiftWrapper(address(subRedManagement), address(registry), digiftEventVerifier));

        DigiftWrapperFactory factory = new DigiftWrapperFactory(digiftWrapperImpl, address(this));

        digiftWrapper = factory.deploy(
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
        );

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(digiftWrapper), true);
        node.addRouter(address(router7540));
        node.addComponent(address(digiftWrapper), ALLOCATION, 0.01 ether, address(router7540));
        digiftWrapper.setManager(manager, true);
        digiftWrapper.setNode(address(node), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();

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
    }

    function _invest() internal returns (uint256) {
        vm.startPrank(rebalancer);
        uint256 depositAmount = router7540.investInAsyncComponent(address(node), address(digiftWrapper));
        vm.stopPrank();
        return depositAmount;
    }

    function _liquidate(uint256 amount) internal {
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), address(digiftWrapper), amount);
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

    // function test_investInAsyncComponent_success() external {
    //     uint256 balance = asset.balanceOf(address(node));

    //     vm.expectEmit(true, true, true, true, address(subRedManagement));
    //     emit ISubRedManagement.Subscribe(
    //         address(subRedManagement), address(stToken), address(asset), address(digiftWrapper), INVEST_AMOUNT
    //     );
    //     vm.expectEmit(true, true, true, true, address(digiftWrapper));
    //     emit IERC7540Deposit.DepositRequest(address(node), address(node), 0, address(node), INVEST_AMOUNT);
    //     uint256 depositAmount = _invest();
    //     assertEq(depositAmount, INVEST_AMOUNT, "Invested according to allocation");

    //     assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), INVEST_AMOUNT);

    //     vm.startPrank(address(node));
    //     assertEq(router7540.getComponentAssets(address(digiftWrapper), false), INVEST_AMOUNT);
    //     vm.stopPrank();

    //     assertEq(node.totalAssets(), balance);

    //     _updateTotalAssets();

    //     assertEq(node.totalAssets(), balance);
    // }

    // function test_settleDeposit_success() external {
    //     uint256 depositAmount = _invest();

    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.expectEmit(true, true, true, true);
    //     emit DigiftWrapper.DepositSettled(address(node), sharesToMint, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
    //     assertEq(
    //         digiftWrapper.claimableDepositRequest(0, address(node)),
    //         INVEST_AMOUNT,
    //         "All deposit amount is claimable now"
    //     );
    //     assertEq(digiftWrapper.maxMint(address(node)), sharesToMint, "maxMint reflects shares to mint");
    // }

    // function test_mintClaimableShares_success() external {
    //     uint256 depositAmount = _invest();

    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     assertEq(digiftWrapper.balanceOf(address(node)), 0, "Node has no shares of digift wrapper");

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     vm.expectEmit(true, true, true, true);
    //     emit IERC7575.Deposit(address(node), address(node), depositAmount, sharesToMint);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.balanceOf(address(node)), sharesToMint, "Shares are minted to node");
    //     assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
    //     assertEq(digiftWrapper.claimableDepositRequest(0, address(node)), 0, "Everything is claimed");
    //     assertEq(digiftWrapper.maxMint(address(node)), 0, "Nothing to mint");
    // }

    // function test_mintClaimableShares_partialMintWithReimbursement() external {
    //     uint256 depositAmount = _invest();
    //     uint256 initialNodeAssetBalance = asset.balanceOf(address(node));

    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     // 80% of expected shares
    //     uint256 partialShares = sharesToMint * 8 / 10;
    //     uint256 assetsUsed = digiftWrapper.convertToAssets(partialShares);
    //     uint256 assetsToReimburse = depositAmount - assetsUsed;

    //     _settleSubscription(partialShares, assetsToReimburse, 0);

    //     assertEq(digiftWrapper.balanceOf(address(node)), 0, "Node has no shares initially");

    //     vm.expectEmit(true, true, true, true);
    //     emit DigiftWrapper.DepositSettled(address(node), partialShares, assetsToReimburse);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), partialShares, assetsToReimburse);
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
    //     assertEq(
    //         digiftWrapper.claimableDepositRequest(0, address(node)), depositAmount, "All deposit amount is claimable"
    //     );
    //     assertEq(digiftWrapper.maxMint(address(node)), partialShares, "maxMint reflects partial shares");

    //     vm.startPrank(rebalancer);
    //     vm.expectEmit(true, true, true, true);
    //     emit IERC7575.Deposit(address(node), address(node), assetsUsed, partialShares);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.balanceOf(address(node)), partialShares, "Partial shares are minted to node");
    //     assertEq(digiftWrapper.claimableDepositRequest(0, address(node)), 0, "Everything is claimed");
    //     assertEq(digiftWrapper.maxMint(address(node)), 0, "Nothing to mint");

    //     uint256 finalNodeAssetBalance = asset.balanceOf(address(node));
    //     uint256 expectedFinalBalance = initialNodeAssetBalance + assetsToReimburse;
    //     assertEq(finalNodeAssetBalance, expectedFinalBalance, "Node received asset reimbursement");
    // }

    // function test_requestAsyncWithdrawal_success() external {
    //     uint256 balance = asset.balanceOf(address(node));

    //     uint256 depositAmount = _invest();

    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 toLiquidate = sharesToMint / 2;

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));

    //     assertEq(node.totalAssets(), balance);

    //     vm.expectEmit(true, true, true, true, address(subRedManagement));
    //     emit ISubRedManagement.Redeem(
    //         address(subRedManagement), address(stToken), address(asset), address(digiftWrapper), toLiquidate
    //     );
    //     vm.expectEmit(true, true, true, true, address(digiftWrapper));
    //     emit IERC7540Redeem.RedeemRequest(address(node), address(node), 0, address(node), toLiquidate);
    //     _liquidate(toLiquidate);

    //     assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), toLiquidate);
    //     assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0);

    //     _updateTotalAssets();

    //     assertApproxEqAbs(node.totalAssets(), balance, 2);
    // }

    // function test_settleRedeem_success() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 toLiquidate = sharesToMint / 2;
    //     uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     _liquidate(toLiquidate);

    //     _settleRedemption(0, assetsToReturn, 0);

    //     vm.expectEmit(true, true, true, true);
    //     emit DigiftWrapper.RedeemSettled(address(node), 0, assetsToReturn);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), 0);
    //     assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), toLiquidate);
    //     assertEq(digiftWrapper.maxWithdraw(address(node)), assetsToReturn);
    // }

    // function test_withdraw_success() external {
    //     uint256 balance = asset.balanceOf(address(node));

    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 toLiquidate = sharesToMint / 2;
    //     uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     _liquidate(toLiquidate);

    //     _settleRedemption(0, assetsToReturn, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);

    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     vm.expectEmit(true, true, true, true);
    //     emit IERC7575.Withdraw(address(node), address(node), address(node), assetsToReturn, toLiquidate);
    //     router7540.executeAsyncWithdrawal(address(node), address(digiftWrapper), assetsToReturn);

    //     assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), 0);
    //     assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0);
    //     assertEq(digiftWrapper.maxWithdraw(address(node)), 0);

    //     _updateTotalAssets();

    //     assertApproxEqAbs(node.totalAssets(), balance, 4);
    // }

    // function test_withdraw_partialRedeemWithReimbursement() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 initialNodeShareBalance = digiftWrapper.balanceOf(address(node));

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.balanceOf(address(node)), sharesToMint, "Node has shares initially");

    //     uint256 sharesToRedeem = sharesToMint;
    //     _liquidate(sharesToRedeem);

    //     uint256 expectedAssets = digiftWrapper.convertToAssets(sharesToRedeem);
    //     // 80% of expected assets
    //     uint256 partialAssets = expectedAssets * 8 / 10;
    //     uint256 sharesUsed = digiftWrapper.convertToShares(partialAssets);
    //     uint256 sharesToReimburse = sharesToRedeem - sharesUsed;

    //     _settleRedemption(sharesToReimburse, partialAssets, 0);

    //     vm.startPrank(manager);
    //     vm.expectEmit(true, true, true, true);
    //     emit DigiftWrapper.RedeemSettled(address(node), sharesToReimburse, partialAssets);
    //     digiftWrapper.settleRedeem(address(node), sharesToReimburse, partialAssets);
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), 0, "No pending shares to redeem");
    //     assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), sharesToRedeem, "All shares are claimable");
    //     assertEq(digiftWrapper.maxWithdraw(address(node)), partialAssets, "maxWithdraw reflects partial assets");

    //     vm.startPrank(rebalancer);
    //     vm.expectEmit(true, true, true, true);
    //     emit IERC7575.Withdraw(address(node), address(node), address(node), partialAssets, sharesUsed);
    //     router7540.executeAsyncWithdrawal(address(node), address(digiftWrapper), partialAssets);
    //     vm.stopPrank();

    //     assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0, "Everything is claimed");
    //     assertEq(digiftWrapper.maxWithdraw(address(node)), 0, "Nothing to withdraw");

    //     uint256 finalNodeShareBalance = digiftWrapper.balanceOf(address(node));
    //     uint256 expectedFinalShareBalance = initialNodeShareBalance + sharesToReimburse;
    //     assertEq(finalNodeShareBalance, expectedFinalShareBalance, "Node received share reimbursement");
    // }

    // =============================
    //      Custom Error Tests
    // =============================

    // function test_requestDeposit_ZeroAmount() external {
    //     vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestDeposit(0, address(node), address(node));
    // }

    // function test_requestDeposit_ControllerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(this), address(node));
    // }

    // function test_requestDeposit_OwnerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(node), address(this));
    // }

    // function test_requestDeposit_DepositRequestPending() external {
    //     _invest();
    //     vm.expectRevert(DigiftWrapper.DepositRequestPending.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(node), address(node));
    // }

    // function test_requestDeposit_DepositRequestNotClaimed() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();

    //     vm.expectRevert(DigiftWrapper.DepositRequestNotClaimed.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestDeposit(DEPOSIT_AMOUNT, address(node), address(node));
    // }

    // function test_requestRedeem_ZeroAmount() external {
    //     vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestRedeem(0, address(node), address(node));
    // }

    // function test_requestRedeem_ControllerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestRedeem(1000e6, address(this), address(node));
    // }

    // function test_requestRedeem_OwnerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestRedeem(1000e6, address(node), address(this));
    // }

    // function test_requestRedeem_RedeemRequestPending() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     _liquidate(sharesToMint / 2);

    //     vm.expectRevert(DigiftWrapper.RedeemRequestPending.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestRedeem(1000e6, address(node), address(node));
    // }

    // function test_requestRedeem_RedeemRequestNotClaimed() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 toLiquidate = sharesToMint / 2;
    //     uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     _liquidate(toLiquidate);
    //     _settleRedemption(0, assetsToReturn, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);
    //     vm.stopPrank();

    //     vm.expectRevert(DigiftWrapper.RedeemRequestNotClaimed.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.requestRedeem(1000e6, address(node), address(node));
    // }

    // function test_mint_ZeroAmount() external {
    //     vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.mint(0, address(node), address(node));
    // }

    // function test_mint_ControllerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.mint(1000e6, address(node), address(this));
    // }

    // function test_mint_OwnerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.mint(1000e6, address(this), address(node));
    // }

    // function test_mint_DepositRequestNotFulfilled() external {
    //     vm.expectRevert(DigiftWrapper.DepositRequestNotFulfilled.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.mint(1000e6, address(node), address(node));
    // }

    // function test_mint_MintAllSharesOnly() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();

    //     vm.expectRevert(DigiftWrapper.MintAllSharesOnly.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.mint(sharesToMint / 2, address(node), address(node));
    // }

    // function test_withdraw_ZeroAmount() external {
    //     vm.expectRevert(DigiftWrapper.ZeroAmount.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.withdraw(0, address(node), address(node));
    // }

    // function test_withdraw_ControllerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.ControllerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.withdraw(1000e6, address(node), address(this));
    // }

    // function test_withdraw_OwnerNotSender() external {
    //     vm.expectRevert(DigiftWrapper.OwnerNotSender.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.withdraw(1000e6, address(this), address(node));
    // }

    // function test_withdraw_RedeemRequestNotFulfilled() external {
    //     vm.expectRevert(DigiftWrapper.RedeemRequestNotFulfilled.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.withdraw(1000e6, address(node), address(node));
    // }

    // function test_withdraw_WithdrawAllAssetsOnly() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 toLiquidate = sharesToMint / 2;
    //     uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     _liquidate(toLiquidate);
    //     _settleRedemption(0, assetsToReturn, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);
    //     vm.stopPrank();

    //     vm.expectRevert(DigiftWrapper.WithdrawAllAssetsOnly.selector);
    //     vm.prank(address(node));
    //     digiftWrapper.withdraw(assetsToReturn / 2, address(node), address(node));
    // }

    // function test_settleDeposit_NothingToSettle() external {
    //     vm.expectRevert(DigiftWrapper.NothingToSettle.selector);
    //     vm.prank(manager);
    //     digiftWrapper.settleDeposit(address(node), 1000e6, 0);
    // }

    // function test_settleRedeem_NothingToSettle() external {
    //     vm.expectRevert(DigiftWrapper.NothingToSettle.selector);
    //     vm.prank(manager);
    //     digiftWrapper.settleRedeem(address(node), 1000e6, 0);
    // }

    // =============================
    //      Event Tests
    // =============================

    // function test_settleDeposit_emits_DepositSettled() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.expectEmit(true, true, true, true);
    //     emit DigiftWrapper.DepositSettled(address(node), sharesToMint, 0);

    //     vm.prank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    // }

    // function test_settleRedeem_emits_RedeemSettled() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 toLiquidate = sharesToMint / 2;
    //     uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     _liquidate(toLiquidate);
    //     _settleRedemption(0, assetsToReturn, 0);

    //     vm.expectEmit(true, true, true, true);
    //     emit DigiftWrapper.RedeemSettled(address(node), 0, assetsToReturn);

    //     vm.prank(manager);
    //     digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);
    // }

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

    // function test_totalAssets_initialState() external view {
    //     assertEq(digiftWrapper.totalAssets(), 0, "Total assets should be 0 initially");
    // }

    // function test_totalAssets_afterMinting() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     // After minting shares, totalAssets should equal convertToAssets(totalSupply())
    //     uint256 totalSupply = digiftWrapper.totalSupply();
    //     uint256 expectedTotalAssets = digiftWrapper.convertToAssets(totalSupply);
    //     uint256 actualTotalAssets = digiftWrapper.totalAssets();

    //     assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
    //     assertEq(totalSupply, sharesToMint, "Total supply should equal minted shares");
    // }

    // function test_totalAssets_afterPartialMint() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 partialShares = sharesToMint * 8 / 10;
    //     uint256 assetsUsed = digiftWrapper.convertToAssets(partialShares);
    //     uint256 assetsToReimburse = depositAmount - assetsUsed;

    //     _settleSubscription(partialShares, assetsToReimburse, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), partialShares, assetsToReimburse);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     // After partial minting, totalAssets should reflect the partial shares
    //     uint256 totalSupply = digiftWrapper.totalSupply();
    //     uint256 expectedTotalAssets = digiftWrapper.convertToAssets(totalSupply);
    //     uint256 actualTotalAssets = digiftWrapper.totalAssets();

    //     assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
    //     assertEq(totalSupply, partialShares, "Total supply should equal partial minted shares");
    // }

    // function test_totalAssets_afterWithdrawal() external {
    //     uint256 depositAmount = _invest();
    //     uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
    //     uint256 toLiquidate = sharesToMint / 2;
    //     uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

    //     _settleSubscription(sharesToMint, 0, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.mintClaimableShares(address(node), address(digiftWrapper));
    //     vm.stopPrank();

    //     _liquidate(toLiquidate);
    //     _settleRedemption(0, assetsToReturn, 0);

    //     vm.startPrank(manager);
    //     digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);
    //     vm.stopPrank();
    //     vm.startPrank(rebalancer);
    //     router7540.executeAsyncWithdrawal(address(node), address(digiftWrapper), assetsToReturn);
    //     vm.stopPrank();

    //     // After withdrawal, totalAssets should reflect remaining shares
    //     uint256 totalSupply = digiftWrapper.totalSupply();
    //     uint256 expectedTotalAssets = digiftWrapper.convertToAssets(totalSupply);
    //     uint256 actualTotalAssets = digiftWrapper.totalAssets();

    //     assertEq(actualTotalAssets, expectedTotalAssets, "totalAssets should match convertToAssets(totalSupply())");
    //     assertEq(totalSupply, sharesToMint - toLiquidate, "Total supply should equal remaining shares");
    // }

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
}
