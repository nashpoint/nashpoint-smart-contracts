// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {WTAdapter} from "../../../../src/adapters/wt/WTAdapter.sol";
import {TransferEventVerifierMock} from "../../../mocks/TransferEventVerifierMock.sol";
import {EventVerifierBase} from "../../../../src/adapters/EventVerifierBase.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreconditionsWTAdapter is PreconditionsBase {
    function wtForwardRequestsPreconditions(uint256 seed)
        internal
        returns (WTForwardRequestParams memory params)
    {
        uint256 depositCount = _pendingWTDepositCount();
        uint256 redeemCount = _pendingWTRedemptionCount();

        params.deposits = new WTPendingDepositRecord[](depositCount);
        for (uint256 i = 0; i < depositCount; i++) {
            params.deposits[i] = _getWTPendingDeposit(i);
        }

        params.redemptions = new WTPendingRedemptionRecord[](redeemCount);
        for (uint256 i = 0; i < redeemCount; i++) {
            params.redemptions[i] = _getWTPendingRedemption(i);
        }

        params.accumulatedDepositBefore = wtAdapter.accumulatedDeposit();
        params.accumulatedRedeemBefore = wtAdapter.accumulatedRedemption();

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed =
                (params.deposits.length > 0 || params.redemptions.length > 0) && params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("WT_FORWARD_CALLER", seed) % 23 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = (params.deposits.length > 0 || params.redemptions.length > 0) && authorized;
    }

    function wtSettleDepositFlowPreconditions(uint256 seed)
        internal
        returns (WTSettleDepositParams memory params)
    {
        uint256 queueLength = _forwardedWTDepositCount();
        bool queueReady = queueLength > 0 && wtAdapter.globalPendingDepositRequest() > 0;
        if (!queueReady) {
            params.shouldSucceed = false;
            return params;
        }

        params.records = new WTPendingDepositRecord[](queueLength);

        uint256 totalAssets;
        for (uint256 i = 0; i < queueLength; i++) {
            WTPendingDepositRecord memory record = _getWTForwardedDeposit(i);
            params.records[i] = record;
            totalAssets += record.assets;
        }

        if (totalAssets == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.sharesExpected = wtAdapter.convertToShares(totalAssets);

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("WT_SETTLE_DEPOSIT_CALLER", seed) % 23 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;
    }

    function wtSettleRedeemFlowPreconditions(uint256 seed)
        internal
        returns (WTSettleRedeemParams memory params)
    {
        uint256 queueLength = _forwardedWTRedemptionCount();
        uint256 pendingRedeemGlobal = wtAdapter.globalPendingRedeemRequest();
        uint256 accumulatedRedemption = wtAdapter.accumulatedRedemption();
        uint256 assetsExpected;

        if (queueLength == 0 && (pendingRedeemGlobal > 0 || accumulatedRedemption > 0)) {
            if (accumulatedRedemption > 0 && pendingRedeemGlobal == 0) {
                // WT transfers fund shares to receiver on redeem
                uint256 fundNeeded = accumulatedRedemption;
                wtFundToken.mint(address(wtAdapter), fundNeeded);

                vm.prank(rebalancer);
                try wtAdapter.forwardRequests() {} catch {}

                pendingRedeemGlobal = wtAdapter.globalPendingRedeemRequest();
            }

            if (pendingRedeemGlobal == 0) {
                params.shouldSucceed = false;
                return params;
            }

            assetsExpected = wtAdapter.convertToAssets(pendingRedeemGlobal);
            if (assetsExpected == 0) {
                assetsExpected = pendingRedeemGlobal;
            }

            // WT redeem: assets come from senderAddress, mint them there
            assetToken.mint(wtSenderAddress, assetsExpected);
            vm.prank(wtSenderAddress);
            assetToken.approve(address(wtAdapter), assetsExpected);
            // Actually need to transfer to adapter directly since mock verifier returns amount
            assetToken.mint(address(wtAdapter), assetsExpected);

            params.records = new WTPendingRedemptionRecord[](1);
            params.records[0] = WTPendingRedemptionRecord({
                node: address(node),
                component: address(wtAdapter),
                shares: pendingRedeemGlobal
            });

            _recordWTForwardedRedemption(params.records[0]);

            params.assetsExpected = assetsExpected;

            if (_hasPreferredAdminActor) {
                params.caller = _preferredAdminActor;
                _preferredAdminActor = address(0);
                _hasPreferredAdminActor = false;
                params.shouldSucceed = params.caller == rebalancer;
                return params;
            }

            bool authorized = _rand("WT_SETTLE_REDEEM_CALLER", seed) % 23 != 0;
            params.caller = authorized ? rebalancer : randomUser;
            params.shouldSucceed = authorized;

            if (seed % 5 == 0) {
                params.shouldSucceed = false;
                params.assetsExpected = assetsExpected / 2 + 1;
                params.caller = randomUser;
            }
            return params;
        } else if (queueLength == 0 || pendingRedeemGlobal == 0) {
            uint8 recordCount = uint8(2 + (seed % 2));
            uint256 totalShares = Math.max(wtAdapter.minRedeemAmount() * recordCount, 5e18);
            assetsExpected = _prepareWTRedemption(totalShares, recordCount);

            queueLength = _forwardedWTRedemptionCount();
            pendingRedeemGlobal = wtAdapter.globalPendingRedeemRequest();
        } else {
            assetsExpected = wtAdapter.convertToAssets(pendingRedeemGlobal);
            if (assetsExpected == 0) {
                assetsExpected = pendingRedeemGlobal;
            }

            uint256 adapterBalance = asset.balanceOf(address(wtAdapter));
            if (assetsExpected > 0 && adapterBalance < assetsExpected) {
                assetToken.mint(address(wtAdapter), assetsExpected - adapterBalance);
            }
        }

        if (queueLength == 0 || pendingRedeemGlobal == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.records = new WTPendingRedemptionRecord[](queueLength);

        uint256 totalSharesAggregated;
        for (uint256 i = 0; i < queueLength; i++) {
            WTPendingRedemptionRecord memory record = _getWTForwardedRedemption(i);
            params.records[i] = record;
            totalSharesAggregated += record.shares;
        }

        if (totalSharesAggregated == 0 || totalSharesAggregated != pendingRedeemGlobal) {
            params.shouldSucceed = false;
            return params;
        }

        params.assetsExpected = assetsExpected;

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("WT_SETTLE_REDEEM_CALLER", seed) % 23 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;

        if (seed % 5 == 0) {
            params.shouldSucceed = false;
            params.assetsExpected = assetsExpected / 2 + 1;
            params.caller = randomUser; // Added this
        }
    }

    function wtMintPreconditions(uint256 shareSeed) internal returns (WTMintParams memory params) {
        uint256 maxMintable = wtAdapter.maxMint(address(node));

        if (maxMintable == 0) {
            uint256 minAssets = Math.max(wtAdapter.minDepositAmount(), 5_000e6);
            _prepareWTDeposit(minAssets);

            maxMintable = wtAdapter.maxMint(address(node));
        }

        if (maxMintable > 0) {
            params.shares = maxMintable;
            params.shouldSucceed = true;
        } else {
            params.shares = 0;
            params.shouldSucceed = false;
        }
    }

    function wtWithdrawPreconditions(uint256 assetSeed) internal returns (WTWithdrawParams memory params) {
        params.maxWithdrawBefore = wtAdapter.maxWithdraw(address(node));
        params.nodeBalanceBefore = asset.balanceOf(address(node));

        if (params.maxWithdrawBefore == 0) {
            uint256 totalShares = Math.max(wtAdapter.minRedeemAmount(), 5e18);
            uint256 assetsExpected = _prepareWTRedemption(totalShares, 2);

            address[] memory nodesArr = _singleton(address(node));
            EventVerifierBase.OffchainArgs memory verifyArgs;

            vm.prank(owner);
            wtEventVerifier.configureTransferAmount(assetsExpected);

            vm.prank(rebalancer);
            try wtAdapter.settleRedeem(nodesArr, verifyArgs) {} catch {}

            params.maxWithdrawBefore = wtAdapter.maxWithdraw(address(node));
            params.nodeBalanceBefore = asset.balanceOf(address(node));
        }

        if (params.maxWithdrawBefore > 0) {
            if (assetSeed % 10 < 9) {
                params.assets = params.maxWithdrawBefore;
                params.shouldSucceed = true;
            } else {
                params.assets = params.maxWithdrawBefore + 1;
                params.shouldSucceed = false;
            }
        } else {
            params.assets = 0;
            params.shouldSucceed = false;
        }
    }

    function wtRequestRedeemFlowPreconditions(uint256 sharesSeed)
        internal
        returns (WTRequestRedeemParams memory params)
    {
        _ensureWTShares(wtAdapter.minRedeemAmount() * 2);

        params.balanceBefore = wtAdapter.balanceOf(address(node));
        params.pendingBefore = wtAdapter.pendingRedeemRequest(0, address(node));

        uint256 minShares = wtAdapter.minRedeemAmount();
        if (params.balanceBefore < minShares) {
            params.shares = 0;
            params.shouldSucceed = false;
            return params;
        }

        params.shares = fl.clamp(sharesSeed + 1, minShares, params.balanceBefore);
        params.shouldSucceed = params.shares >= minShares && params.shares <= params.balanceBefore;
    }

    function wtSettleDividendPreconditions(uint256 seed)
        internal
        returns (WTSettleDividendParams memory params)
    {
        // Ensure adapter has shares and no pending cycle
        _ensureWTShares(wtAdapter.minDepositAmount());

        uint256 pendingDeposit = wtAdapter.globalPendingDepositRequest();
        uint256 pendingRedeem = wtAdapter.globalPendingRedeemRequest();

        if (pendingDeposit > 0 || pendingRedeem > 0) {
            params.shouldSucceed = false;
            return params;
        }

        uint256 dividendAmount = 1e18;
        params.dividendAmount = dividendAmount;

        params.nodes = new address[](1);
        params.nodes[0] = address(node);
        params.totalSupplyBefore = wtAdapter.totalSupply();
        params.nodeBalancesBefore = new uint256[](params.nodes.length);
        for (uint256 i = 0; i < params.nodes.length; i++) {
            params.nodeBalancesBefore[i] = wtAdapter.balanceOf(params.nodes[i]);
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("WT_SETTLE_DIVIDEND_CALLER", seed) % 23 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;
    }

    // ==============================================================
    // INTERNAL HELPERS
    // ==============================================================

    function _ensureWTShares(uint256 minShares) internal {
        if (wtAdapter.balanceOf(address(node)) >= minShares) {
            return;
        }

        uint256 minAssets = Math.max(wtAdapter.minDepositAmount(), 5_000e6);
        uint256 sharesMinted = _prepareWTDeposit(minAssets);
        if (sharesMinted < minShares) {
            _prepareWTDeposit(minAssets * 2);
        }
    }

    function _prepareWTDeposit(uint256 assetsAmount) internal returns (uint256 sharesMinted) {
        _clearWTQueues();

        vm.startPrank(address(node));
        try wtAdapter.requestDeposit(assetsAmount, address(node), address(node)) {} catch {}
        vm.stopPrank();

        _recordWTPendingDeposit(address(node), address(wtAdapter), assetsAmount);

        vm.prank(rebalancer);
        try wtAdapter.forwardRequests() {} catch {}

        _flushWTPendingDeposits();

        sharesMinted = wtAdapter.convertToShares(assetsAmount);
        if (sharesMinted == 0) {
            sharesMinted = assetsAmount;
        }

        // WT settle deposit verifies Transfer event (fund mint to adapter)
        // Fund tokens minted to adapter by external protocol in reality; mock it
        wtFundToken.mint(address(wtAdapter), sharesMinted);

        vm.prank(owner);
        wtEventVerifier.configureTransferAmount(sharesMinted);

        address[] memory nodesArr = _singleton(address(node));
        EventVerifierBase.OffchainArgs memory verifyArgs;

        vm.prank(rebalancer);
        try wtAdapter.settleDeposit(nodesArr, verifyArgs) {} catch {}

        vm.startPrank(address(node));
        try wtAdapter.mint(sharesMinted, address(node), address(node)) {} catch {}
        vm.stopPrank();

        _clearWTQueues();
    }

    function _prepareWTRedemption(uint256 totalShares, uint8)
        internal
        returns (uint256 assetsExpected)
    {
        _ensureWTShares(totalShares * 2);
        _clearWTRedemptionQueues();

        // AdapterBase only allows one pending request at a time (RedeemRequestPending guard),
        // so issue a single requestRedeem instead of looping over recordCount.
        uint256 sharesPortion = Math.max(totalShares, wtAdapter.minRedeemAmount());
        sharesPortion = Math.min(sharesPortion, wtAdapter.balanceOf(address(node)));

        vm.startPrank(address(node));
        try wtAdapter.requestRedeem(sharesPortion, address(node), address(node)) {
            _recordWTPendingRedemption(address(node), address(wtAdapter), sharesPortion);
        } catch {}
        vm.stopPrank();

        vm.prank(rebalancer);
        try wtAdapter.forwardRequests() {} catch {}

        _flushWTPendingRedemptions();

        uint256 pendingRedeemGlobal = wtAdapter.globalPendingRedeemRequest();
        assetsExpected = wtAdapter.convertToAssets(pendingRedeemGlobal);
        if (assetsExpected == 0) {
            assetsExpected = pendingRedeemGlobal;
        }

        // WT redeem: assets sent by wtSender to adapter
        if (assetsExpected > 0) {
            assetToken.mint(address(wtAdapter), assetsExpected);
        }
    }

    function _clearWTQueues() internal {
        while (_pendingWTDepositCount() > 0) {
            _consumeWTPendingDeposit(_pendingWTDepositCount() - 1);
        }
        while (_forwardedWTDepositCount() > 0) {
            _consumeWTForwardedDeposit(_forwardedWTDepositCount() - 1);
        }
    }

    function _clearWTRedemptionQueues() internal {
        while (_pendingWTRedemptionCount() > 0) {
            _consumeWTPendingRedemption(_pendingWTRedemptionCount() - 1);
        }
        while (_forwardedWTRedemptionCount() > 0) {
            _consumeWTForwardedRedemption(_forwardedWTRedemptionCount() - 1);
        }
    }

    function _flushWTPendingDeposits() internal {
        while (_pendingWTDepositCount() > 0) {
            WTPendingDepositRecord memory record = _consumeWTPendingDeposit(_pendingWTDepositCount() - 1);
            _recordWTForwardedDeposit(record);
        }
    }

    function _flushWTPendingRedemptions() internal {
        while (_pendingWTRedemptionCount() > 0) {
            WTPendingRedemptionRecord memory record =
                _consumeWTPendingRedemption(_pendingWTRedemptionCount() - 1);
            _recordWTForwardedRedemption(record);
        }
    }
}
