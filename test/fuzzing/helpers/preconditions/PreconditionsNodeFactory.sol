// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {NodeInitArgs} from "../../../../src/interfaces/INode.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract PreconditionsNodeFactory is PreconditionsBase {
    using Strings for uint256;

    function nodeFactoryDeployPreconditions(uint256 seed) internal returns (NodeFactoryDeployParams memory params) {
        uint256 entropy = uint256(keccak256(abi.encodePacked(block.timestamp, iteration, seed, currentActor)));
        string memory suffix = (seed % 10_000).toString();

        params.initArgs = NodeInitArgs({
            name: string(abi.encodePacked("FuzzNode-", suffix)),
            symbol: string(abi.encodePacked("FN", suffix)),
            asset: address(asset),
            owner: owner
        });

        params.payload = new bytes[](0);
        params.salt = keccak256(abi.encodePacked(address(this), currentActor, iteration, seed, entropy));
        params.shouldSucceed = true;
    }
}
