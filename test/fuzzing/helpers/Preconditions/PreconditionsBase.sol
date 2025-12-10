// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzStructs.sol";
import "forge-std/console.sol";

contract PreconditionsBase is FuzzStructs {
    event LogAddress(address actor);

    address internal _preferredAdminActor;
    bool internal _hasPreferredAdminActor;

    modifier setCurrentActor(uint256 seed) {
        require(protocolSet, "PreconditionsBase: Protocol not set");

        if (_setActor) {
            uint256 fuzzNumber = generateFuzzNumber(iteration, SEED);
            console.log("fuzz iteration", iteration);

            currentActor = USERS[fuzzNumber % (USERS.length)];

            iteration += 1;

            console.log("Pranking: ", toString(currentActor)); //echidna logs output
            console.log("Block timestamp: ", block.timestamp);
            //check state and revert workaround
            if (block.timestamp < lastTimestamp) {
                vm.warp(lastTimestamp);
            } else {
                lastTimestamp = block.timestamp;
            }
            // Refresh oracle timestamps to prevent StalePriceData errors
            _refreshOracles();
        }
        if (_hasPreferredAdminActor) {
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
        }
        emit LogAddress(currentActor);
        _;
    }

    function setActor(address targetUser) internal {
        address[] memory targetArray = USERS; //use several arrays
        require(targetArray.length > 0, "Target array is empty");

        // Find target user index
        uint256 targetIndex;
        bool found = false;
        for (uint256 i = 0; i < targetArray.length; i++) {
            if (targetArray[i] == targetUser) {
                targetIndex = i;
                console.log("Setting user", targetUser);
                console.log("Index", i);

                found = true;
                break;
            }
        }

        require(found, "Target user not found in array");

        uint256 maxIterations = 100000; //  prevent infinite loops
        uint256 currentIteration = iteration;
        bool iterationFound = false;

        for (uint256 i = 0; i < maxIterations; i++) {
            uint256 hash = uint256(keccak256(abi.encodePacked(currentIteration * PRIME + SEED)));
            uint256 index = hash % targetArray.length;

            if (index == targetIndex) {
                iteration = currentIteration;
                iterationFound = true;
                break;
            }

            currentIteration++;
        }

        require(iterationFound, "User index not found by setter");

        _preferredAdminActor = targetUser;
        _hasPreferredAdminActor = true;
        console.log("setActor override", targetUser);
    }

    function _rand(bytes32 tag, uint256 seedA) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tag, seedA, SEED)));
    }

    function _rand(bytes32 tag, uint256 seedA, uint256 seedB) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tag, seedA, seedB, SEED)));
    }

    /// @notice Refreshes oracle timestamps to current block.timestamp to prevent StalePriceData errors
    function _refreshOracles() internal {
        if (address(assetPriceOracleMock) != address(0)) {
            assetPriceOracleMock.setLatestRoundData(1, 1e8, block.timestamp, block.timestamp, 1);
        }
        if (address(digiftPriceOracleMock) != address(0)) {
            digiftPriceOracleMock.setLatestRoundData(1, 2e10, block.timestamp, block.timestamp, 1);
        }
    }

    /// @notice Wrapper for vm.warp that also refreshes oracle timestamps
    function _warp(uint256 target) internal {
        if (block.timestamp < target) {
            vm.warp(target);
            lastTimestamp = block.timestamp;
            _refreshOracles();
        }
    }
}
