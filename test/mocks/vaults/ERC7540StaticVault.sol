// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC7540Mock} from "../ERC7540Mock.sol";

/**
 * @title ERC7540StaticVault
 * @notice Async vault mock with no automatic yield.
 */
contract ERC7540StaticVault is ERC7540Mock {
    constructor(IERC20 asset_, string memory name_, string memory symbol_, address manager_)
        ERC7540Mock(asset_, name_, symbol_, manager_)
    {}
}
