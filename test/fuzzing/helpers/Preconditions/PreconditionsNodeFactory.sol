// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {NodeInitArgs} from "../../../../src/interfaces/INode.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract PreconditionsNodeFactory is PreconditionsBase {
    using Strings for uint256;

    function nodeFactoryDeployPreconditions(uint256 seed) internal returns (NodeFactoryDeployParams memory params) {
        bool attemptSuccess = seed % 5 != 0;

        address ownerCandidate = USERS[seed % USERS.length];
        address assetCandidate = attemptSuccess ? address(asset) : address(0);

        string memory nameCandidate = attemptSuccess ? string(abi.encodePacked("FuzzNode-", seed.toString())) : "";
        string memory symbolCandidate = attemptSuccess ? string(abi.encodePacked("FN", (seed % 1000).toString())) : "";

        params.initArgs = NodeInitArgs({
            name: nameCandidate,
            symbol: symbolCandidate,
            asset: assetCandidate,
            owner: attemptSuccess ? ownerCandidate : address(0)
        });

        params.payload = new bytes[](0);
        params.salt = keccak256(abi.encodePacked(address(this), currentActor, iteration, seed, block.timestamp));
        params.shouldSucceed = attemptSuccess;

        if (!attemptSuccess) {
            uint256 toggle = seed % 3;
            if (toggle == 0) {
                params.initArgs.name = "";
            } else if (toggle == 1) {
                params.initArgs.symbol = "";
            } else {
                params.initArgs.owner = address(0);
            }
        }
    }
}
