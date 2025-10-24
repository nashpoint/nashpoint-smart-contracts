// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PolicyBase} from "src/policies/PolicyBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

abstract contract WhitelistBase is PolicyBase {
    mapping(address node => mapping(address user => bool whitelisted)) public whitelist;

    event WhitelistAdded(address indexed node, address[] users);
    event WhitelistRemoved(address indexed node, address[] users);

    constructor(address registry_) PolicyBase(registry_) {}

    function add(address node, address[] calldata users) external onlyNodeOwner(node) {
        for (uint256 i; i < users.length; i++) {
            whitelist[node][users[i]] = true;
        }
        emit WhitelistAdded(node, users);
    }

    function remove(address node, address[] calldata users) external onlyNodeOwner(node) {
        for (uint256 i; i < users.length; i++) {
            whitelist[node][users[i]] = false;
        }
        emit WhitelistRemoved(node, users);
    }

    modifier onlyWhitelisted(address node, address user) {
        _isWhitelisted(node, user);
        _;
    }

    function _isWhitelisted(address node, address user) internal view {
        if (!whitelist[node][user]) revert ErrorsLib.NotWhitelisted();
    }
}
