// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";

/**
 * @title DigiftEventVerifierMock
 * @notice Simplified verifier used by the fuzzing harness to bypass Merkle proof checks.
 */
contract DigiftEventVerifierMock is Ownable {
    mapping(address => bool) public whitelist;

    uint256 private subscribeShares;
    uint256 private subscribeAssets;
    uint256 private redeemShares;
    uint256 private redeemAssets;

    event WhitelistChange(address indexed adapter, bool status);
    event SettlementConfigured(DigiftEventVerifier.EventType indexed eventType, uint256 shares, uint256 assets);

    constructor(address owner_) Ownable(owner_) {}

    function setWhitelist(address adapter, bool status) external onlyOwner {
        whitelist[adapter] = status;
        emit WhitelistChange(adapter, status);
    }

    function setBlockHash(uint256, bytes32) external onlyOwner {}

    function configureSettlement(DigiftEventVerifier.EventType eventType, uint256 shares, uint256 assets)
        external
        onlyOwner
    {
        if (eventType == DigiftEventVerifier.EventType.SUBSCRIBE) {
            subscribeShares = shares;
            subscribeAssets = assets;
        } else {
            redeemShares = shares;
            redeemAssets = assets;
        }
        emit SettlementConfigured(eventType, shares, assets);
    }

    function verifySettlementEvent(
        DigiftEventVerifier.OffchainArgs calldata,
        DigiftEventVerifier.OnchainArgs calldata nargs
    ) external returns (uint256 shares, uint256 assets) {
        if (!whitelist[msg.sender]) revert("Verifier: not whitelisted");

        if (nargs.eventType == DigiftEventVerifier.EventType.SUBSCRIBE) {
            shares = subscribeShares;
            assets = subscribeAssets;
        } else {
            shares = redeemShares;
            assets = redeemAssets;
        }
    }

    function getExpectedSettlement(DigiftEventVerifier.EventType eventType)
        external
        view
        returns (uint256 shares, uint256 assets)
    {
        if (eventType == DigiftEventVerifier.EventType.SUBSCRIBE) {
            shares = subscribeShares;
            assets = subscribeAssets;
        } else {
            shares = redeemShares;
            assets = redeemAssets;
        }
    }
}
