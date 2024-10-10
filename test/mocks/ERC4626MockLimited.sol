// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC4626LimitsMock} from "@openzeppelin/contracts/mocks/token/ERC4626LimitsMock.sol";

contract ERC4626MockLimited is ERC4626LimitsMock {
    constructor(address underlying) ERC20("ERC4626Mock", "E4626M") ERC4626(IERC20(underlying)) {}
}
