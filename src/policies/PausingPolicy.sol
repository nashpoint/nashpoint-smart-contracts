// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {WhitelistBase} from "src/policies/WhitelistBase.sol";

contract PausingPolicy is WhitelistBase {
    mapping(address node => mapping(bytes4 sig => bool paused)) public sigPause;
    mapping(address node => bool paused) public globalPause;

    event SelectorsPaused(address indexed node, bytes4[] sigs);
    event SelectorsUnpaused(address indexed node, bytes4[] sigs);
    event GlobalPaused(address indexed node);
    event GlobalUnpaused(address indexed node);

    error GlobalPause();
    error SigPause(bytes4 sig);

    constructor(address registry_) WhitelistBase(registry_) {
        actions[IERC7575.deposit.selector] = true;
        actions[IERC7575.mint.selector] = true;
        actions[IERC7575.withdraw.selector] = true;
        actions[IERC7575.redeem.selector] = true;

        actions[INode.requestRedeem.selector] = true;
        actions[INode.execute.selector] = true;
        actions[INode.subtractProtocolExecutionFee.selector] = true;
        actions[INode.fulfillRedeemFromReserve.selector] = true;
        actions[INode.finalizeRedemption.selector] = true;
        actions[INode.setOperator.selector] = true;
        actions[INode.startRebalance.selector] = true;
        actions[INode.payManagementFees.selector] = true;
        actions[INode.updateTotalAssets.selector] = true;

        actions[IERC20.transfer.selector] = true;
        actions[IERC20.approve.selector] = true;
        actions[IERC20.transferFrom.selector] = true;
    }

    function pauseSigs(address node, bytes4[] calldata sigs) external isWhitelisted(node, msg.sender) {
        for (uint256 i; i < sigs.length; i++) {
            sigPause[node][sigs[i]] = true;
        }
        emit SelectorsPaused(node, sigs);
    }

    function unpauseSigs(address node, bytes4[] calldata sigs) external isWhitelisted(node, msg.sender) {
        for (uint256 i; i < sigs.length; i++) {
            sigPause[node][sigs[i]] = false;
        }
        emit SelectorsUnpaused(node, sigs);
    }

    function pauseGlobal(address node) external isWhitelisted(node, msg.sender) {
        globalPause[node] = true;
        emit GlobalPaused(node);
    }

    function unpauseGlobal(address node) external isWhitelisted(node, msg.sender) {
        globalPause[node] = false;
        emit GlobalUnpaused(node);
    }

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view override {
        if (globalPause[msg.sender]) revert GlobalPause();
        if (sigPause[msg.sender][selector]) revert SigPause(selector);
    }
}
