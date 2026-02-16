// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsWTAdapter.sol";
import "./helpers/postconditions/PostconditionsWTAdapter.sol";

import {WTAdapter} from "../../src/adapters/wt/WTAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FuzzWTAdapter is PreconditionsWTAdapter, PostconditionsWTAdapter {
    // ========================================
    // CATEGORY 1: USER FUNCTIONS (PUBLIC)
    // ========================================

    function fuzz_wt_mint(uint256 shareSeed) public {
        WTMintParams memory params = wtMintPreconditions(shareSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(wtAdapter),
            abi.encodeWithSignature("mint(uint256,address,address)", params.shares, address(node), address(node)),
            address(node)
        );

        wtMintPostconditions(success, returnData, params);
    }

    function fuzz_wt_withdraw(uint256 assetsSeed) public {
        WTWithdrawParams memory params = wtWithdrawPreconditions(assetsSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(wtAdapter),
            abi.encodeWithSignature("withdraw(uint256,address,address)", params.assets, address(node), address(node)),
            address(node)
        );

        wtWithdrawPostconditions(success, returnData, params);
    }

    function fuzz_wt_requestRedeem(uint256 sharesSeed) public {
        WTRequestRedeemParams memory params = wtRequestRedeemFlowPreconditions(sharesSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(wtAdapter),
            abi.encodeWithSignature(
                "requestRedeem(uint256,address,address)", params.shares, address(node), address(node)
            ),
            address(node)
        );

        wtRequestRedeemFlowPostconditions(success, returnData, params);
    }
}
