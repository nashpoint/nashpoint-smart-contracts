// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";

/**
 * @title TransferEventVerifierMock
 * @notice Simplified verifier used by the fuzzing harness to bypass Merkle proof checks.
 *         Returns a pre-configured transfer amount when `verifyEvent` is called.
 */
contract TransferEventVerifierMock is Ownable {
    mapping(address => bool) public whitelist;

    uint256 private _transferAmount;

    event WhitelistChange(address indexed adapter, bool status);
    event TransferAmountConfigured(uint256 amount);

    constructor(address owner_) Ownable(owner_) {}

    function setWhitelist(address adapter, bool status) external onlyOwner {
        whitelist[adapter] = status;
        emit WhitelistChange(adapter, status);
    }

    function setBlockHash(uint256, bytes32) external onlyOwner {}

    function configureTransferAmount(uint256 amount) external onlyOwner {
        _transferAmount = amount;
        emit TransferAmountConfigured(amount);
    }

    function verifyEvent(EventVerifierBase.OffchainArgs calldata, TransferEventVerifier.OnchainArgs calldata)
        external
        returns (uint256)
    {
        if (!whitelist[msg.sender]) revert("Verifier: not whitelisted");
        return _transferAmount;
    }

    function getExpectedTransferAmount() external view returns (uint256) {
        return _transferAmount;
    }
}
