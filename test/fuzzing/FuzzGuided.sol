// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzNode.sol";
import "./FuzzDonate.sol";
import "./FuzzDigiftAdapter.sol";
import "./FuzzDigiftEventVerifier.sol";
import "./FuzzNodeFactory.sol";

/**
 * @title FuzzGuided
 * @notice Provides composite flows that help the fuzzer reach deeper Node states
 * @dev Updated to only import remaining user-facing fuzz contracts
 *      Admin contracts moved to FuzzAdmin/ folder
 *      Router and other internal-only contracts deleted
 */
contract FuzzGuided is FuzzNode, FuzzDonate, FuzzDigiftAdapter, FuzzDigiftEventVerifier, FuzzNodeFactory {}
