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
}
