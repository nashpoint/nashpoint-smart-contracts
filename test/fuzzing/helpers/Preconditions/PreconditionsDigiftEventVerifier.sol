// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {DigiftEventVerifier} from "../../../../src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftEventVerifierMock} from "../../../mocks/DigiftEventVerifierMock.sol";

contract PreconditionsDigiftEventVerifier is PreconditionsBase {
    function digiftVerifierSetWhitelistPreconditions(uint256 seed, bool status)
        internal
        view
        returns (DigiftVerifierWhitelistParams memory params)
    {
        params.adapter = _selectWhitelistTarget(seed);
        params.status = status;
        params.shouldSucceed = currentActor == owner;
    }

    function digiftVerifierSetBlockHashPreconditions(uint256 seed)
        internal
        view
        returns (DigiftVerifierBlockHashParams memory params)
    {
        uint256 offset = seed % 16;
        if (block.number > offset) {
            params.blockNumber = block.number - offset;
        } else {
            params.blockNumber = block.number;
        }

        bytes32 referenceHash = block.number > 1 ? blockhash(block.number - 1) : bytes32(seed);
        params.blockHash = keccak256(abi.encodePacked(seed, referenceHash, address(this)));
        params.shouldSucceed = currentActor == owner;
    }

    function digiftVerifierConfigurePreconditions(uint256 seed, bool isSubscribe)
        internal
        returns (DigiftVerifierConfigureParams memory params)
    {
        params.eventType = isSubscribe ? DigiftEventVerifier.EventType.SUBSCRIBE : DigiftEventVerifier.EventType.REDEEM;
        params.expectedShares = fl.clamp(seed, 1e18, 100e18);
        params.expectedAssets = fl.clamp(seed >> 1, 1e6, 10_000e6);
        params.shouldSucceed = currentActor == owner;
    }

    function digiftVerifierVerifyPreconditions(uint256 seed, bool isSubscribe)
        internal
        returns (DigiftVerifierVerifyParams memory params)
    {
        params.eventType = isSubscribe ? DigiftEventVerifier.EventType.SUBSCRIBE : DigiftEventVerifier.EventType.REDEEM;
        params.adapter = address(digiftAdapter);
        params.securityToken = address(stToken);
        params.currencyToken = address(asset);
        params.shouldSucceed = DigiftEventVerifierMock(address(digiftEventVerifier)).whitelist(params.adapter);

        (params.expectedShares, params.expectedAssets) =
            DigiftEventVerifierMock(address(digiftEventVerifier)).getExpectedSettlement(params.eventType);

        if (params.expectedShares == 0 && params.expectedAssets == 0) {
            params.expectedShares = fl.clamp(seed, 1e18, 100e18);
            params.expectedAssets = fl.clamp(seed >> 1, 1e6, 10_000e6);
        }
    }

    function _selectWhitelistTarget(uint256 seed) internal view returns (address) {
        address[] memory candidates = new address[](USERS.length + 4);
        for (uint256 i = 0; i < USERS.length; i++) {
            candidates[i] = USERS[i];
        }
        candidates[USERS.length] = owner;
        candidates[USERS.length + 1] = rebalancer;
        candidates[USERS.length + 2] = address(node);
        candidates[USERS.length + 3] = address(digiftAdapter);

        return candidates[seed % candidates.length];
    }
}
