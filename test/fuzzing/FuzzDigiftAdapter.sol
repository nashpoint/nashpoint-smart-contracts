// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsDigiftAdapter.sol";
import "./helpers/postconditions/PostconditionsDigiftAdapter.sol";

import {DigiftAdapter} from "../../src/adapters/digift/DigiftAdapter.sol";
import {DigiftEventVerifier} from "../../src/adapters/digift/DigiftEventVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract FuzzDigiftAdapter is PreconditionsDigiftAdapter, PostconditionsDigiftAdapter {
    // ========================================
    // CATEGORY 1: USER FUNCTIONS (PUBLIC)
    // ========================================
    // Standard ERC20 functions accessible to end users

    function fuzz_digift_approve(uint256 spenderSeed, uint256 amountSeed) public {
        _forceActor(address(node), amountSeed);
        DigiftApproveParams memory params = digiftApprovePreconditions(spenderSeed, amountSeed);
        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftAdapter),
            abi.encodeWithSelector(IERC20.approve.selector, params.spender, params.amount),
            address(node)
        );
        digiftApprovePostconditions(success, returnData, address(node), params);
    }

    function fuzz_digift_transfer(uint256 recipientSeed, uint256 amountSeed) public {
        _forceActor(address(node), amountSeed);
        DigiftTransferParams memory params = digiftTransferPreconditions(recipientSeed, amountSeed);
        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftAdapter),
            abi.encodeWithSelector(IERC20.transfer.selector, params.to, params.amount),
            address(node)
        );
        digiftTransferPostconditions(success, returnData, address(node), params);
    }

    function fuzz_digift_transferFrom(uint256 recipientSeed, uint256 amountSeed) public {
        address spender = _selectAddressFromSeed(amountSeed);
        _forceActor(spender, amountSeed);
        DigiftTransferParams memory params = digiftTransferFromPreconditions(spender, recipientSeed, amountSeed);
        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(digiftAdapter),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(node), params.to, params.amount),
            spender
        );
        digiftTransferPostconditions(success, returnData, address(node), params);
    }
}
