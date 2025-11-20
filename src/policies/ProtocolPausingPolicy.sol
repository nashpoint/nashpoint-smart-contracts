// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC7575} from "src/interfaces/IERC7575.sol";
import {INode} from "src/interfaces/INode.sol";

import {PolicyBase} from "src/policies/abstract/PolicyBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

/**
 * @title ProtocolPausingPolicy
 * @notice Enables protocol operators to pause actions across all nodes
 */
contract ProtocolPausingPolicy is PolicyBase {
    mapping(address user => bool whitelisted) public whitelist;

    mapping(bytes4 sig => bool paused) public sigPause;
    bool public globalPause;

    event SelectorsPaused(bytes4[] sigs);
    event SelectorsUnpaused(bytes4[] sigs);
    event GlobalPaused();
    event GlobalUnpaused();
    event WhitelistAdded(address[] users);
    event WhitelistRemoved(address[] users);

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

    /// @notice Grants protocol-level pause permissions to accounts
    /// @param users Addresses to whitelist
    function add(address[] calldata users) external onlyRegistryOwner {
        for (uint256 i; i < users.length; i++) {
            whitelist[users[i]] = true;
        }
        emit WhitelistAdded(users);
    }

    /// @notice Revokes protocol-level pause permissions from accounts
    /// @param users Addresses to remove from the whitelist
    function remove(address[] calldata users) external onlyRegistryOwner {
        for (uint256 i; i < users.length; i++) {
            whitelist[users[i]] = false;
        }
        emit WhitelistRemoved(users);
    }

    /// @notice Pauses specific function selectors across all nodes
    /// @param sigs Function selectors to pause
    function pauseSigs(bytes4[] calldata sigs) external onlyWhitelisted {
        for (uint256 i; i < sigs.length; i++) {
            sigPause[sigs[i]] = true;
        }
        emit SelectorsPaused(sigs);
    }

    /// @notice Resumes paused selectors across all nodes
    /// @param sigs Function selectors to unpause
    function unpauseSigs(bytes4[] calldata sigs) external onlyWhitelisted {
        for (uint256 i; i < sigs.length; i++) {
            sigPause[sigs[i]] = false;
        }
        emit SelectorsUnpaused(sigs);
    }

    /// @notice Triggers a global pause for all guarded selectors
    function pauseGlobal() external onlyWhitelisted {
        globalPause = true;
        emit GlobalPaused();
    }

    /// @notice Lifts the global pause for all guarded selectors
    function unpauseGlobal() external onlyWhitelisted {
        globalPause = false;
        emit GlobalUnpaused();
    }

    function _executeCheck(address node, address caller, bytes4 selector, bytes calldata payload)
        internal
        view
        override
    {
        if (globalPause) revert GlobalPause();
        if (sigPause[selector]) revert SigPause(selector);
    }

    modifier onlyWhitelisted() {
        _isWhitelisted(msg.sender);
        _;
    }

    function _isWhitelisted(address user) internal view {
        if (!whitelist[user]) revert ErrorsLib.NotWhitelisted();
    }
}
