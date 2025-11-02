// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RevertHandler.sol";
import {ErrorsLib} from "../../../src/libraries/ErrorsLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

abstract contract Properties_ERR is RevertHandler {
    /*
    *
    * FUZZ NOTE: CHECK REVERTS CONFIGURATION IN FUZZ STORAGE VARIABLES
    *
    */

    function _getAllowedPanicCodes() internal pure virtual override returns (uint256[] memory) {
        uint256[] memory panicCodes = new uint256[](2);
        panicCodes[0] = PANIC_ARITHMETIC;
        panicCodes[1] = PANIC_ARRAY_OUT_OF_BOUNDS;
        return panicCodes;
    }

    // Add additional errors here
    // Example:
    // Deposit errors [0-5]
    // allowedErrors[0] = IUsdnProtocolErrors.UsdnProtocolEmptyVault.selector;
    // allowedErrors[1] = IUsdnProtocolErrors
    //     .UsdnProtocolDepositTooSmall
    //     .selector;

    function _getAllowedCustomErrors() internal pure virtual override returns (bytes4[] memory) {
        bytes4[] memory allowedErrors = new bytes4[](15);
        allowedErrors[0] = ErrorsLib.ExceedsMaxDeposit.selector;
        allowedErrors[1] = ErrorsLib.ExceedsMaxMint.selector;
        allowedErrors[2] = ErrorsLib.ExceedsMaxRedeem.selector;
        allowedErrors[3] = ErrorsLib.ExceedsMaxWithdraw.selector;
        allowedErrors[4] = ErrorsLib.ExceedsAvailableReserve.selector;
        allowedErrors[5] = ErrorsLib.InvalidSender.selector;
        allowedErrors[6] = ErrorsLib.InvalidController.selector;
        allowedErrors[7] = ErrorsLib.InvalidOwner.selector;
        allowedErrors[8] = ErrorsLib.NoPendingRedeemRequest.selector;
        allowedErrors[9] = ErrorsLib.InsufficientBalance.selector;
        allowedErrors[10] = ErrorsLib.ZeroAmount.selector;
        allowedErrors[11] = ErrorsLib.CannotSetSelfAsOperator.selector;
        allowedErrors[12] = Ownable.OwnableUnauthorizedAccount.selector;
        allowedErrors[13] = Ownable.OwnableInvalidOwner.selector;
        allowedErrors[14] = UpgradeableBeacon.BeaconInvalidImplementation.selector;
        return allowedErrors;
    }

    function _isAllowedERC20Error(bytes memory returnData) internal pure virtual override returns (bool) {
        bytes[] memory allowedErrors = new bytes[](9);
        allowedErrors[0] = INSUFFICIENT_ALLOWANCE;
        allowedErrors[1] = TRANSFER_FROM_ZERO;
        allowedErrors[2] = TRANSFER_TO_ZERO;
        allowedErrors[3] = APPROVE_TO_ZERO;
        allowedErrors[4] = MINT_TO_ZERO;
        allowedErrors[5] = BURN_FROM_ZERO;
        allowedErrors[6] = DECREASED_ALLOWANCE;
        allowedErrors[7] = BURN_EXCEEDS_BALANCE;
        allowedErrors[8] = EXCEEDS_BALANCE_ERROR;

        for (uint256 i = 0; i < allowedErrors.length; i++) {
            if (keccak256(returnData) == keccak256(allowedErrors[i])) {
                return true;
            }
        }
        return false;
    }

    function _getAllowedSoladyERC20Error() internal pure virtual override returns (bytes4[] memory) {
        bytes4[] memory allowedErrors = new bytes4[](5);
        allowedErrors[0] = SafeTransferLib.ETHTransferFailed.selector;
        allowedErrors[1] = SafeTransferLib.TransferFromFailed.selector;
        allowedErrors[2] = SafeTransferLib.TransferFailed.selector;
        allowedErrors[3] = SafeTransferLib.ApproveFailed.selector;
        allowedErrors[4] = bytes4(0x82b42900); //unauthorized selector

        return allowedErrors;
    }
}
