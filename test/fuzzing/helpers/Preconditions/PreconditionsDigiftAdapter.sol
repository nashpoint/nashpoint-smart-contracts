// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {DigiftAdapter} from "../../../../src/adapters/digift/DigiftAdapter.sol";
import {DigiftEventVerifier} from "../../../../src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftEventVerifierMock} from "../../../mocks/DigiftEventVerifierMock.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PreconditionsDigiftAdapter is PreconditionsBase {
    function digiftApprovePreconditions(uint256 spenderSeed, uint256 amountSeed)
        internal
        returns (DigiftApproveParams memory params)
    {
        params.spender = _selectAddressFromSeed(spenderSeed);
        params.amount = fl.clamp(amountSeed, 0, type(uint96).max);
        params.shouldSucceed = true;
    }

    function digiftTransferPreconditions(uint256 recipientSeed, uint256 amountSeed)
        internal
        returns (DigiftTransferParams memory params)
    {
        params.to = _selectAddressFromSeed(recipientSeed);
        params.amount = fl.clamp(amountSeed, 0, type(uint128).max);

        address caller = address(node);
        uint256 balance = digiftAdapter.balanceOf(caller);
        params.shouldSucceed = params.amount <= balance;
    }

    function digiftTransferFromPreconditions(address spender, uint256 recipientSeed, uint256 amountSeed)
        internal
        returns (DigiftTransferParams memory params)
    {
        params.to = _selectAddressFromSeed(recipientSeed);
        params.amount = fl.clamp(amountSeed, 0, type(uint128).max);

        uint256 balance = digiftAdapter.balanceOf(address(node));
        uint256 allowance = digiftAdapter.allowance(address(node), spender);
        params.shouldSucceed = params.amount <= balance && params.amount <= allowance;
    }

    function digiftRequestDepositPreconditions(uint256 amountSeed)
        internal
        returns (DigiftRequestParams memory params)
    {
        params.amount = fl.clamp(amountSeed, 1, type(uint128).max);

        uint256 minAmount = digiftAdapter.minDepositAmount();
        uint256 allowance = asset.allowance(address(node), address(digiftAdapter));
        uint256 balance = asset.balanceOf(address(node));

        params.shouldSucceed = params.amount >= minAmount && params.amount <= allowance && params.amount <= balance
            && _nodeHasNoPendingState();
    }

    function digiftRequestRedeemPreconditions(uint256 shareSeed) internal returns (DigiftRequestParams memory params) {
        params.amount = fl.clamp(shareSeed, 1, type(uint128).max);

        uint256 minAmount = digiftAdapter.minRedeemAmount();
        uint256 balance = digiftAdapter.balanceOf(address(node));
        uint256 allowance = digiftAdapter.allowance(address(node), address(digiftAdapter));

        params.shouldSucceed = params.amount >= minAmount && params.amount <= balance && params.amount <= allowance
            && _nodeHasNoPendingState();
    }

    function digiftMintPreconditions(uint256 shareSeed) internal returns (DigiftMintParams memory params) {
        uint256 maxMintable = digiftAdapter.maxMint(address(node));

        // If no mintable shares, prime the contract by settling a deposit
        if (maxMintable == 0) {
            uint256 minAssets = Math.max(digiftAdapter.minDepositAmount(), 5_000e6);
            uint256 sharesMinted = _prepareDigiftDeposit(minAssets);

            maxMintable = digiftAdapter.maxMint(address(node));
        }

        if (maxMintable > 0) {
            params.shares = maxMintable;
            params.shouldSucceed = true;
        } else {
            params.shares = 0;
            params.shouldSucceed = false;
        }
    }

    function digiftForwardRequestsPreconditions(uint256 seed)
        internal
        returns (DigiftForwardRequestParams memory params)
    {
        uint256 depositCount = _pendingDigiftDepositCount();
        uint256 redeemCount = _pendingDigiftRedemptionCount();

        params.deposits = new DigiftPendingDepositRecord[](depositCount);
        for (uint256 i = 0; i < depositCount; i++) {
            params.deposits[i] = _getDigiftPendingDeposit(i);
        }

        params.redemptions = new DigiftPendingRedemptionRecord[](redeemCount);
        for (uint256 i = 0; i < redeemCount; i++) {
            params.redemptions[i] = _getDigiftPendingRedemption(i);
        }

        params.accumulatedDepositBefore = digiftAdapter.accumulatedDeposit();
        params.accumulatedRedeemBefore = digiftAdapter.accumulatedRedemption();

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed =
                (params.deposits.length > 0 || params.redemptions.length > 0) && params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("DIGIFT_FORWARD_CALLER", seed) % 23 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = (params.deposits.length > 0 || params.redemptions.length > 0) && authorized;
    }

    function digiftSettleDepositFlowPreconditions(uint256 seed)
        internal
        returns (DigiftSettleDepositParams memory params)
    {
        uint256 queueLength = _forwardedDigiftDepositCount();
        bool queueReady = queueLength > 0 && digiftAdapter.globalPendingDepositRequest() > 0;
        if (!queueReady) {
            params.shouldSucceed = false;
            return params;
        }

        params.records = new DigiftPendingDepositRecord[](queueLength);

        uint256 totalAssets;
        for (uint256 i = 0; i < queueLength; i++) {
            DigiftPendingDepositRecord memory record = _getDigiftForwardedDeposit(i);
            params.records[i] = record;
            totalAssets += record.assets;
        }

        if (totalAssets == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.sharesExpected = digiftAdapter.convertToShares(totalAssets);
        params.assetsExpected = 0;

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("DIGIFT_SETTLE_DEPOSIT_CALLER", seed) % 23 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;
    }

    function digiftSettleRedeemFlowPreconditions(uint256 seed)
        internal
        returns (DigiftSettleRedeemParams memory params)
    {
        uint256 queueLength = _forwardedDigiftRedemptionCount();
        uint256 pendingRedeemGlobal = digiftAdapter.globalPendingRedeemRequest();
        uint256 assetsExpected;

        if (queueLength == 0 || pendingRedeemGlobal == 0) {
            uint8 recordCount = uint8(2 + (seed % 2));
            uint256 totalShares = Math.max(digiftAdapter.minRedeemAmount() * recordCount, 5e18);
            assetsExpected = _prepareDigiftRedemption(totalShares, recordCount);

            queueLength = _forwardedDigiftRedemptionCount();
            pendingRedeemGlobal = digiftAdapter.globalPendingRedeemRequest();
        } else {
            assetsExpected = digiftAdapter.convertToAssets(pendingRedeemGlobal);
            if (assetsExpected == 0) {
                assetsExpected = pendingRedeemGlobal;
            }

            uint256 adapterBalance = asset.balanceOf(address(digiftAdapter));
            if (assetsExpected > 0 && adapterBalance < assetsExpected) {
                assetToken.mint(address(digiftAdapter), assetsExpected - adapterBalance);
            }
        }

        if (queueLength == 0 || pendingRedeemGlobal == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.records = new DigiftPendingRedemptionRecord[](queueLength);

        uint256 totalSharesAggregated;
        for (uint256 i = 0; i < queueLength; i++) {
            DigiftPendingRedemptionRecord memory record = _getDigiftForwardedRedemption(i);
            params.records[i] = record;
            totalSharesAggregated += record.shares;
        }

        if (totalSharesAggregated == 0 || totalSharesAggregated != pendingRedeemGlobal) {
            params.shouldSucceed = false;
            return params;
        }

        params.sharesExpected = 0;
        params.assetsExpected = assetsExpected;

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("DIGIFT_SETTLE_REDEEM_CALLER", seed) % 23 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;

        if (seed % 5 == 0) {
            params.shouldSucceed = false;
            params.assetsExpected = assetsExpected / 2 + 1;
        }
    }

    function digiftWithdrawPreconditions(uint256 assetSeed) internal returns (DigiftWithdrawParams memory params) {
        params.maxWithdrawBefore = digiftAdapter.maxWithdraw(address(node));
        params.nodeBalanceBefore = asset.balanceOf(address(node));

        // If no withdrawable assets, prime the contract by settling a redemption
        if (params.maxWithdrawBefore == 0) {
            uint256 totalShares = Math.max(digiftAdapter.minRedeemAmount(), 5e18);
            uint256 assetsExpected = _prepareDigiftRedemption(totalShares, 2);

            address[] memory nodesArr = _singleton(address(node));
            DigiftEventVerifier.OffchainArgs memory verifyArgs;

            vm.prank(owner);
            digiftEventVerifier.configureSettlement(DigiftEventVerifier.EventType.REDEEM, 0, assetsExpected);

            vm.prank(rebalancer);
            try digiftAdapter.settleRedeem(nodesArr, verifyArgs) {} catch {}

            params.maxWithdrawBefore = digiftAdapter.maxWithdraw(address(node));
            params.nodeBalanceBefore = asset.balanceOf(address(node));
        }

        // Branch 1 (90%): Withdraw exact max amount (happy path)
        // Branch 2 (10%): Try to withdraw more than max → WithdrawAllAssetsOnly()
        if (params.maxWithdrawBefore > 0) {
            if (assetSeed % 10 < 9) {
                // Happy path: withdraw exactly maxWithdraw
                params.assets = params.maxWithdrawBefore;
                params.shouldSucceed = true;
            } else {
                // Error path: try to withdraw more than max
                params.assets = params.maxWithdrawBefore + 1;
                params.shouldSucceed = false;
            }
        } else {
            // No withdrawable assets
            params.assets = 0;
            params.shouldSucceed = false;
        }
    }

    function digiftRequestRedeemFlowPreconditions(uint256 sharesSeed)
        internal
        returns (DigiftRequestRedeemParams memory params)
    {
        _ensureDigiftShares(digiftAdapter.minRedeemAmount() * 2);

        params.balanceBefore = digiftAdapter.balanceOf(address(node));
        params.pendingBefore = digiftAdapter.pendingRedeemRequest(0, address(node));

        uint256 minShares = digiftAdapter.minRedeemAmount();
        if (params.balanceBefore < minShares) {
            params.shares = 0;
            params.shouldSucceed = false;
            return params;
        }

        params.shares = fl.clamp(sharesSeed + 1, minShares, params.balanceBefore);
        params.shouldSucceed = params.shares >= minShares && params.shares <= params.balanceBefore;
    }

    function digiftAssetFundingPreconditions(uint256 amountSeed)
        internal
        returns (DigiftAssetFundingParams memory params)
    {
        params.amount = fl.clamp(amountSeed, 1, type(uint128).max);
        params.shouldSucceed = true;
    }

    function digiftAssetApprovalPreconditions(uint256 amountSeed)
        internal
        returns (DigiftAssetApprovalParams memory params)
    {
        params.amount = fl.clamp(amountSeed, 0, type(uint128).max);
        params.shouldSucceed = true;
    }

    function digiftForwardPreconditions(bool, bool) internal view returns (DigiftForwardParams memory params) {
        params.expectDeposit = digiftAdapter.accumulatedDeposit() > 0;
        params.expectRedeem = digiftAdapter.accumulatedRedemption() > 0;
        params.shouldSucceed =
            digiftAdapter.globalPendingDepositRequest() == 0 && digiftAdapter.globalPendingRedeemRequest() == 0;
    }

    function digiftSettleDepositPreconditions(uint256, uint256)
        internal
        view
        returns (DigiftSettleParams memory params)
    {
        address[] memory nodes = new address[](1);
        nodes[0] = address(node);
        params.nodes = nodes;
        (params.shares, params.assets) = _getExpectedSettlement(DigiftEventVerifier.EventType.SUBSCRIBE);
        params.shouldSucceed = digiftAdapter.globalPendingDepositRequest() > 0;
    }

    function digiftSettleRedeemPreconditions(uint256, uint256)
        internal
        view
        returns (DigiftSettleParams memory params)
    {
        address[] memory nodes = new address[](1);
        nodes[0] = address(node);
        params.nodes = nodes;
        (params.shares, params.assets) = _getExpectedSettlement(DigiftEventVerifier.EventType.REDEEM);
        params.shouldSucceed = digiftAdapter.globalPendingRedeemRequest() > 0;
    }

    function digiftSetAddressBoolPreconditions(uint256 addressSeed, bool status)
        internal
        pure
        returns (DigiftSetAddressBoolParams memory params)
    {
        params.target = address(uint160(uint256(keccak256(abi.encodePacked(addressSeed, status)))));
        params.status = status;
        params.shouldSucceed = true;
    }

    function digiftSetUintPreconditions(uint256 valueSeed, uint256 maxValue)
        internal
        pure
        returns (DigiftSetUintParams memory params)
    {
        params.value = valueSeed % maxValue;
        params.shouldSucceed = true;
    }

    function _ensureDigiftShares(uint256 minShares) internal {
        if (digiftAdapter.balanceOf(address(node)) >= minShares) {
            return;
        }

        uint256 minAssets = Math.max(digiftAdapter.minDepositAmount(), 5_000e6);
        uint256 sharesMinted = _prepareDigiftDeposit(minAssets);
        if (sharesMinted < minShares) {
            _prepareDigiftDeposit(minAssets * 2);
        }
    }

    function _prepareDigiftDeposit(uint256 assetsAmount) internal returns (uint256 sharesMinted) {
        _clearDigiftQueues();

        vm.startPrank(address(node));
        try digiftAdapter.requestDeposit(assetsAmount, address(node), address(node)) {} catch {}
        vm.stopPrank();

        _recordDigiftPendingDeposit(address(node), address(digiftAdapter), assetsAmount);

        vm.prank(rebalancer);
        try digiftAdapter.forwardRequestsToDigift() {} catch {}

        _flushPendingDeposits();

        sharesMinted = digiftAdapter.convertToShares(assetsAmount);
        if (sharesMinted == 0) {
            sharesMinted = assetsAmount;
        }

        vm.prank(owner);
        digiftEventVerifier.configureSettlement(DigiftEventVerifier.EventType.SUBSCRIBE, sharesMinted, 0);

        address[] memory nodesArr = _singleton(address(node));
        DigiftEventVerifier.OffchainArgs memory verifyArgs;

        vm.prank(rebalancer);
        try digiftAdapter.settleDeposit(nodesArr, verifyArgs) {} catch {}

        vm.startPrank(address(node));
        try digiftAdapter.mint(sharesMinted, address(node), address(node)) {} catch {}
        vm.stopPrank();

        _clearDigiftQueues();
    }

    function _prepareDigiftRedemption(uint256 totalShares, uint8 recordCount)
        internal
        returns (uint256 assetsExpected)
    {
        _ensureDigiftShares(totalShares * 2);
        _clearDigiftRedemptionQueues();

        uint256 basePortion = totalShares / recordCount;
        uint256 remainder = totalShares % recordCount;

        for (uint8 i = 0; i < recordCount; i++) {
            uint256 sharesPortion = basePortion;
            if (i == recordCount - 1) {
                sharesPortion += remainder;
            }
            sharesPortion = Math.max(sharesPortion, digiftAdapter.minRedeemAmount());
            sharesPortion = Math.min(sharesPortion, digiftAdapter.balanceOf(address(node)));

            vm.startPrank(address(node));
            try digiftAdapter.requestRedeem(sharesPortion, address(node), address(node)) {} catch {}
            vm.stopPrank();

            _recordDigiftPendingRedemption(address(node), address(digiftAdapter), sharesPortion);
        }

        vm.prank(rebalancer);
        try digiftAdapter.forwardRequestsToDigift() {} catch {}

        _flushPendingRedemptions();

        uint256 pendingRedeemGlobal = digiftAdapter.globalPendingRedeemRequest();
        assetsExpected = digiftAdapter.convertToAssets(pendingRedeemGlobal);
        if (assetsExpected == 0) {
            assetsExpected = pendingRedeemGlobal;
        }

        if (assetsExpected > 0) {
            assetToken.mint(address(digiftAdapter), assetsExpected);
        }
    }

    function _clearDigiftQueues() internal {
        while (_pendingDigiftDepositCount() > 0) {
            _consumeDigiftPendingDeposit(_pendingDigiftDepositCount() - 1);
        }
        while (_forwardedDigiftDepositCount() > 0) {
            _consumeDigiftForwardedDeposit(_forwardedDigiftDepositCount() - 1);
        }
    }

    function _clearDigiftRedemptionQueues() internal {
        while (_pendingDigiftRedemptionCount() > 0) {
            _consumeDigiftPendingRedemption(_pendingDigiftRedemptionCount() - 1);
        }
        while (_forwardedDigiftRedemptionCount() > 0) {
            _consumeDigiftForwardedRedemption(_forwardedDigiftRedemptionCount() - 1);
        }
    }

    function _flushPendingDeposits() internal {
        while (_pendingDigiftDepositCount() > 0) {
            DigiftPendingDepositRecord memory record = _consumeDigiftPendingDeposit(_pendingDigiftDepositCount() - 1);
            _recordDigiftForwardedDeposit(record);
        }
    }

    function _flushPendingRedemptions() internal {
        while (_pendingDigiftRedemptionCount() > 0) {
            DigiftPendingRedemptionRecord memory record =
                _consumeDigiftPendingRedemption(_pendingDigiftRedemptionCount() - 1);
            _recordDigiftForwardedRedemption(record);
        }
    }

    function _selectAddressFromSeed(uint256 seed) internal view returns (address) {
        address[] memory candidates = new address[](USERS.length + 4);
        for (uint256 i = 0; i < USERS.length; i++) {
            candidates[i] = USERS[i];
        }
        candidates[USERS.length] = owner;
        candidates[USERS.length + 1] = rebalancer;
        candidates[USERS.length + 2] = randomUser;
        candidates[USERS.length + 3] = address(digiftAdapter);
        return candidates[seed % candidates.length];
    }

    function _nodeHasNoPendingState() internal view returns (bool) {
        return digiftAdapter.pendingDepositRequest(0, address(node)) == 0 && digiftAdapter.maxMint(address(node)) == 0
            && digiftAdapter.pendingRedeemRequest(0, address(node)) == 0 && digiftAdapter.maxWithdraw(address(node)) == 0;
    }

    function _getExpectedSettlement(DigiftEventVerifier.EventType eventType)
        internal
        view
        returns (uint256 shares, uint256 assets)
    {
        (shares, assets) = DigiftEventVerifierMock(address(digiftEventVerifier)).getExpectedSettlement(eventType);
    }
}
