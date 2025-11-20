// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {GatePolicyBase} from "src/policies/abstract/GatePolicyBase.sol";

contract GatePolicyBlacklist is GatePolicyBase {
    constructor(address registry_) GatePolicyBase(registry_) {}

    function _actorCheck(address node, address actor) internal view override {
        _notBlacklisted(node, actor);
    }
}
