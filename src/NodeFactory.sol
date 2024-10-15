// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Node} from "src/Node.sol";

// TODO's
// DONE: Update Constructor and vault handling (Node)
// DONE: Create() Function (Factory)
// Create checks to ensure valid input data
// Emit Event when created
// Track create Node on Core contract

contract NodeFactory {
    function create(
        address depositAsset,
        string memory name,
        string memory symbol,
        address rebalancer,
        uint256 maxDiscount,
        uint256 targetReserveRatio,
        uint256 maxDelta,
        uint256 asyncMaxDelta,
        address owner
    ) external returns (address) {
        // TODO: build a bunch of require statements for the numbers to make sure they will work
        Node node = new Node(
            depositAsset,
            name,
            symbol,
            rebalancer,
            maxDiscount,
            targetReserveRatio,
            maxDelta,
            asyncMaxDelta,
            owner
        );
        return address(node);
    }
}
