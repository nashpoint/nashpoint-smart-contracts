// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {PolicyBase} from "src/policies/PolicyBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {PolicyLib} from "src/libraries/PolicyLib.sol";

contract PausingPolicy is PolicyBase {
    mapping(address node => mapping(address operator => bool enabled)) operators;
    mapping(address node => mapping(bytes4 sig => bool paused)) sigPause;
    mapping(address node => bool paused) globalPause;

    event OperatorsAdded(address indexed node, address[] operators);
    event OperatorsRemoved(address indexed node, address[] operators);

    event SelectorsPaused(address indexed node, bytes4[] sigs);
    event SelectorsUnpaused(address indexed node, bytes4[] sigs);
    event GlobalPaused(address indexed node);
    event GlobalUnpaused(address indexed node);

    error GlobalPause();
    error SigPause(bytes4 sig);

    constructor(address registry_) PolicyBase(registry_) {
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

    function pauseSigs(address node, bytes4[] calldata sigs) external onlyOperator(node) {
        for (uint256 i; i < sigs.length; i++) {
            sigPause[node][sigs[i]] = true;
        }
        emit SelectorsPaused(node, sigs);
    }

    function unpauseSigs(address node, bytes4[] calldata sigs) external onlyOperator(node) {
        for (uint256 i; i < sigs.length; i++) {
            sigPause[node][sigs[i]] = false;
        }
        emit SelectorsUnpaused(node, sigs);
    }

    function pauseGlobal(address node) external onlyOperator(node) {
        globalPause[node] = true;
        emit GlobalPaused(node);
    }

    function unpauseGlobal(address node) external onlyOperator(node) {
        globalPause[node] = false;
        emit GlobalUnpaused(node);
    }

    function add(address node, address[] calldata operators_) external onlyNodeOwner(node) {
        for (uint256 i; i < operators_.length; i++) {
            operators[node][operators_[i]] = true;
        }
        emit OperatorsAdded(node, operators_);
    }

    function remove(address node, address[] calldata operators_) external onlyNodeOwner(node) {
        for (uint256 i; i < operators_.length; i++) {
            operators[node][operators_[i]] = false;
        }
        emit OperatorsRemoved(node, operators_);
    }

    function _executeCheck(address caller, bytes4 selector, bytes calldata payload) internal view override {
        if (globalPause[msg.sender]) revert GlobalPause();
        if (sigPause[msg.sender][selector]) revert SigPause(selector);
    }

    modifier onlyOperator(address node) {
        _isOperator(node);
        _;
    }

    function _isOperator(address node) internal view {
        if (!operators[node][msg.sender]) revert ErrorsLib.NotWhitelisted();
    }
}
