// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC7575} from "src/interfaces/IERC7575.sol";

library PolicyLib {
    function decodeDeposit(bytes calldata payload) internal view returns (uint256 assets, address receiver) {
        (assets, receiver) = abi.decode(payload, (uint256, address));
    }

    function decodeMint(bytes calldata payload) internal view returns (uint256 shares, address receiver) {
        (shares, receiver) = abi.decode(payload, (uint256, address));
    }

    function decodeRequestRedeem(bytes calldata payload)
        internal
        view
        returns (uint256 shares, address controller, address owner)
    {
        (shares, controller, owner) = abi.decode(payload, (uint256, address, address));
    }

    function decodeTransfer(bytes calldata payload) internal view returns (address to, uint256 value) {
        (to, value) = abi.decode(payload, (address, uint256));
    }

    function decodeApprove(bytes calldata payload) internal view returns (address spender, uint256 value) {
        (spender, value) = abi.decode(payload, (address, uint256));
    }

    function decodeTransferFrom(bytes calldata payload)
        internal
        view
        returns (address from, address to, uint256 value)
    {
        (from, to, value) = abi.decode(payload, (address, address, uint256));
    }

    function decodeExecute(bytes calldata payload) internal view returns (address target, bytes memory data) {
        (target, data) = abi.decode(payload, (address, bytes));
    }

    function decodeSubtractProtocolExecutionFee(bytes calldata payload) internal view returns (uint256 executionFee) {
        (executionFee) = abi.decode(payload, (uint256));
    }

    function decodeFulfillRedeemFromReserve(bytes calldata payload) internal view returns (address controller) {
        (controller) = abi.decode(payload, (address));
    }

    function decodeFinalizeRedemption(bytes calldata payload)
        internal
        view
        returns (address controller, uint256 assetsToReturn, uint256 sharesPending)
    {
        (controller, assetsToReturn, sharesPending) = abi.decode(payload, (address, uint256, uint256));
    }

    function decodeSetOperator(bytes calldata payload) internal view returns (address operator, bool approved) {
        (operator, approved) = abi.decode(payload, (address, bool));
    }

    function decodeWithdraw(bytes calldata payload)
        internal
        view
        returns (uint256 assets, address receiver, address controller)
    {
        (assets, receiver, controller) = abi.decode(payload, (uint256, address, address));
    }

    function decodeRedeem(bytes calldata payload)
        internal
        view
        returns (uint256 shares, address receiver, address controller)
    {
        (shares, receiver, controller) = abi.decode(payload, (uint256, address, address));
    }
}
