// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

/// @title  Escrow
/// @notice Escrow contract that holds tokens for pending Node withdrawals.
contract Escrow is Ownable, IEscrow {
    constructor(address _owner) Ownable(_owner) {}

    /* TOKEN APPROVALS */

    /// @inheritdoc IEscrow
    function approveMax(address token, address spender) external onlyOwner {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            _safeApprove(token, spender, type(uint256).max);
            emit Approve(token, spender, type(uint256).max);
        }
    }

    /// @inheritdoc IEscrow
    function unapprove(address token, address spender) external onlyOwner {
        _safeApprove(token, spender, 0);
        emit Approve(token, spender, 0);
    }

    /* INTERNAL FUNCTIONS */

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.approve, (spender, amount)));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert ErrorsLib.SafeApproveFailed();
    }
}
