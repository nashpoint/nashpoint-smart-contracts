// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "test/BaseTest.sol";
import {DigiftWrapper} from "src/wrappers/DigiftWrapper.sol";
import {ISubRedManagement, IDFeedPriceOracle, IManagement, ISecurityToken} from "src/interfaces/external/IDigift.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";

contract DigiftForkTest is BaseTest {
    DigiftWrapper digiftWrapper;
    uint256 DEPOSIT_AMOUNT = 1000e6;
    uint64 ALLOCATION = 0.9 ether;
    uint256 INVEST_AMOUNT = DEPOSIT_AMOUNT * ALLOCATION / 1e18;

    ISubRedManagement constant subRedManagement = ISubRedManagement(0x3DAd21A73a63bBd186f57f733d271623467b6c78);
    IDFeedPriceOracle constant dFeedPriceOracle = IDFeedPriceOracle(0x67aE0CAAC7f6995d8B24d415F584e5625cdEe048);
    ISecurityToken constant stToken = ISecurityToken(0x37EC21365dC39B0b74ea7b6FabFfBcB277568AC4);

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
        // Node should be whitelisted as well otherwise it is not possible to transfer stTokens from it
        vm.mockCall(
            subRedManagement.management(),
            abi.encodeWithSelector(IManagement.isWhiteInvestor.selector, address(node)),
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

    function test_investInAsyncComponent_success() external {
        uint256 balance = asset.balanceOf(address(node));

        vm.expectEmit(true, true, true, true, address(subRedManagement));
        emit ISubRedManagement.Subscribe(
            address(subRedManagement), address(stToken), address(asset), address(digiftWrapper), INVEST_AMOUNT
        );
        vm.expectEmit(true, true, true, true, address(digiftWrapper));
        emit IERC7540Deposit.DepositRequest(address(node), address(node), 0, address(node), INVEST_AMOUNT);
        uint256 depositAmount = _invest();
        assertEq(depositAmount, INVEST_AMOUNT, "Invested according to allocation");

        assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), INVEST_AMOUNT);

        vm.startPrank(address(node));
        assertEq(router7540.getComponentAssets(address(digiftWrapper), false), INVEST_AMOUNT);
        vm.stopPrank();

        assertEq(node.totalAssets(), balance);

        _updateTotalAssets();

        assertEq(node.totalAssets(), balance);
    }

    function test_settleDeposit_success() external {
        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);

        _settleSubscription(sharesToMint, 0, 0);

        vm.startPrank(rebalancer);
        digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
        vm.stopPrank();

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

        _settleSubscription(sharesToMint, 0, 0);

        assertEq(digiftWrapper.balanceOf(address(node)), 0, "Node has no shares of digift wrapper");

        vm.startPrank(rebalancer);
        digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
        router7540.mintClaimableShares(address(node), address(digiftWrapper));
        vm.stopPrank();

        assertEq(digiftWrapper.balanceOf(address(node)), sharesToMint, "Shares are minted to node");
        assertEq(digiftWrapper.pendingDepositRequest(0, address(node)), 0, "No pending assets to deposit");
        assertEq(digiftWrapper.claimableDepositRequest(0, address(node)), 0, "Everything is claimed");
        assertEq(digiftWrapper.maxMint(address(node)), 0, "Nothing to mint");
    }

    function test_requestAsyncWithdrawal_success() external {
        uint256 balance = asset.balanceOf(address(node));

        uint256 depositAmount = _invest();

        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;

        _settleSubscription(sharesToMint, 0, 0);

        vm.startPrank(rebalancer);
        digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
        router7540.mintClaimableShares(address(node), address(digiftWrapper));

        assertEq(node.totalAssets(), balance);

        vm.expectEmit(true, true, true, true, address(subRedManagement));
        emit ISubRedManagement.Redeem(
            address(subRedManagement), address(stToken), address(asset), address(digiftWrapper), toLiquidate
        );
        vm.expectEmit(true, true, true, true, address(digiftWrapper));
        emit IERC7540Redeem.RedeemRequest(address(node), address(node), 0, address(node), toLiquidate);
        _liquidate(toLiquidate);

        assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), toLiquidate);
        assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0);

        _updateTotalAssets();

        assertApproxEqAbs(node.totalAssets(), balance, 2);
    }

    function test_settleRedeem_success() external {
        uint256 depositAmount = _invest();
        uint256 sharesToMint = digiftWrapper.convertToShares(depositAmount);
        uint256 toLiquidate = sharesToMint / 2;
        uint256 assetsToReturn = digiftWrapper.convertToAssets(toLiquidate);

        _settleSubscription(sharesToMint, 0, 0);

        vm.startPrank(rebalancer);
        digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
        router7540.mintClaimableShares(address(node), address(digiftWrapper));
        vm.stopPrank();

        _liquidate(toLiquidate);

        _settleRedemption(0, assetsToReturn, 0);

        vm.startPrank(rebalancer);
        digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);
        vm.stopPrank();

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

        _settleSubscription(sharesToMint, 0, 0);

        vm.startPrank(rebalancer);
        digiftWrapper.settleDeposit(address(node), sharesToMint, 0);
        router7540.mintClaimableShares(address(node), address(digiftWrapper));
        vm.stopPrank();

        _liquidate(toLiquidate);

        _settleRedemption(0, assetsToReturn, 0);

        vm.startPrank(rebalancer);
        digiftWrapper.settleRedeem(address(node), 0, assetsToReturn);

        router7540.executeAsyncWithdrawal(address(node), address(digiftWrapper), assetsToReturn);

        assertEq(digiftWrapper.pendingRedeemRequest(0, address(node)), 0);
        assertEq(digiftWrapper.claimableRedeemRequest(0, address(node)), 0);
        assertEq(digiftWrapper.maxWithdraw(address(node)), 0);

        _updateTotalAssets();

        assertApproxEqAbs(node.totalAssets(), balance, 2);
    }
}
