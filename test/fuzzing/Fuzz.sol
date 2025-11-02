// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzGuided.sol";

contract Fuzz is FuzzGuided {
    constructor() payable {
        fuzzSetup();
    }
}
