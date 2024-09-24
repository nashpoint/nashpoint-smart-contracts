// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Bestia} from "src/bestia.sol";

// TODO's
// DONE: Update Constructor and vault handling (Node)
// DONE: Create() Function (Factory)
// Create checks to ensure valid input data
// Emit Event when created
// Track create Node on Core contract

contract NodeFactory {
    function create(
        address _depositAsset,
        string memory _name,
        string memory _symbol,
        address _banker,
        uint256 _maxDiscount,
        uint256 _targetReserveRatio,
        uint256 _maxDelta,
        uint256 _asyncMaxDelta,
        address _owner
    ) external returns (address) {
        // TODO: build a bunch of require statements for the numbers to make sure they will work
        Bestia bestia = new Bestia(
            _depositAsset, _name, _symbol, _banker, _maxDiscount, _targetReserveRatio, _maxDelta, _asyncMaxDelta, _owner
        );
        return address(bestia);
    }
}
