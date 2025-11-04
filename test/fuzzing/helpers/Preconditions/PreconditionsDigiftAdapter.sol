// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {DigiftAdapter} from "../../../../src/adapters/digift/DigiftAdapter.sol";
import {DigiftEventVerifier} from "../../../../src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftEventVerifierMock} from "../../../mocks/DigiftEventVerifierMock.sol";

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

        uint256 balance = digiftAdapter.balanceOf(currentActor);
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

        if (maxMintable > 0) {
            params.shares = maxMintable;
            params.shouldSucceed = true;
        } else {
            params.shares = fl.clamp(shareSeed, 1, type(uint128).max);
            params.shouldSucceed = false;
        }
    }

    function digiftForwardRequestsPreconditions(uint256)
        internal
        view
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
        params.shouldSucceed = params.deposits.length > 0 || params.redemptions.length > 0;
    }

    function digiftSettleDepositFlowPreconditions(uint256 seed)
        internal
        view
        returns (DigiftSettleDepositParams memory params)
    {
        seed;
        uint256 queueLength = _forwardedDigiftDepositCount();
        params.shouldSucceed = queueLength > 0 && digiftAdapter.globalPendingDepositRequest() > 0;

        if (!params.shouldSucceed) {
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
    }

    function digiftSettleRedeemFlowPreconditions(uint256 seed)
        internal
        returns (DigiftSettleRedeemParams memory params)
    {
        seed;
        uint256 queueLength = _forwardedDigiftRedemptionCount();
        uint256 pendingRedeemGlobal = digiftAdapter.globalPendingRedeemRequest();
        params.shouldSucceed = queueLength > 0 && pendingRedeemGlobal > 0;

        if (!params.shouldSucceed) {
            return params;
        }

        params.records = new DigiftPendingRedemptionRecord[](queueLength);

        uint256 totalShares;
        for (uint256 i = 0; i < queueLength; i++) {
            DigiftPendingRedemptionRecord memory record = _getDigiftForwardedRedemption(i);
            params.records[i] = record;
            totalShares += record.shares;
        }

        if (totalShares == 0 || totalShares != pendingRedeemGlobal) {
            params.shouldSucceed = false;
            return params;
        }

        params.sharesExpected = 0;
        params.assetsExpected = digiftAdapter.convertToAssets(pendingRedeemGlobal);

        // Fund the DigiftAdapter with assets to simulate Digift redemption payout
        // In reality, Digift would burn stTokens and transfer USDC to the adapter
        if (params.assetsExpected > 0) {
            assetToken.mint(address(digiftAdapter), params.assetsExpected);
        }
    }

    function digiftWithdrawPreconditions(uint256 assetSeed) internal returns (DigiftWithdrawParams memory params) {
        uint256 maxAssets = digiftAdapter.maxWithdraw(address(node));

        if (maxAssets > 0) {
            params.assets = maxAssets;
            params.shouldSucceed = true;
        } else {
            params.assets = fl.clamp(assetSeed, 1, type(uint128).max);
            params.shouldSucceed = false;
        }
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
