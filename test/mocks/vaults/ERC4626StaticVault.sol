// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title ERC4626StaticVault
 * @notice Minimal immediate-settlement vault with 1:1 asset <-> share exchange.
 */
contract ERC4626StaticVault is ERC4626 {
    constructor(address underlying, string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC4626(IERC20(underlying))
    {}
}
