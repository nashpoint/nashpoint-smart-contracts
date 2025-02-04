// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

/// @title  Escrow
/// @notice Escrow contract that holds tokens for pending Node withdrawals
/// @dev    Node is granted maximum allowance to move asset tokens out of Escrow
///         Node can also _burn shares stored at Escrow but requires no allowance
contract Escrow {
    using SafeERC20 for IERC20;
    /* IMMUTABLES */
    /// @notice The Node contract this escrow serves

    address public immutable node;

    /* CONSTRUCTOR */
    constructor(address node_) {
        if (node_ == address(0)) revert ErrorsLib.ZeroAddress();
        node = node_;
        IERC20(IERC4626(node).asset()).safeIncreaseAllowance(address(node), type(uint256).max);
    }
}
