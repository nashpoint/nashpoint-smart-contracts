// SPDX-License-Identifier: None
pragma solidity 0.8.28;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IERC20PermitHardhat is IERC20Permit {
    function permit(address owner, address spender, uint256 value, uint256 deadline, bytes memory signature) external;
}
