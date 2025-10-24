// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {IPolicy} from "src/interfaces/IPolicy.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

library NodeLib {
    function addPolicies(
        address registry,
        mapping(bytes4 => address[]) storage policies,
        mapping(bytes4 => mapping(address => bool)) storage sigPolicy,
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes4[] calldata sigs,
        address[] calldata policies_
    ) external {
        if (!INodeRegistry(registry).verifyPolicies(proof, proofFlags, sigs, policies_)) {
            revert ErrorsLib.NotWhitelisted();
        }
        for (uint256 i; i < sigs.length; i++) {
            if (sigPolicy[sigs[i]][policies_[i]]) revert ErrorsLib.PolicyAlreadyAdded(sigs[i], policies_[i]);
            policies[sigs[i]].push(policies_[i]);
            sigPolicy[sigs[i]][policies_[i]] = true;
        }
        emit EventsLib.PoliciesAdded(sigs, policies_);
    }

    function removePolicies(
        mapping(bytes4 => address[]) storage policies,
        mapping(bytes4 => mapping(address => bool)) storage sigPolicy,
        bytes4[] calldata sigs,
        address[] calldata policies_
    ) external {
        for (uint256 i; i < sigs.length; i++) {
            if (!sigPolicy[sigs[i]][policies_[i]]) revert ErrorsLib.PolicyAlreadyRemoved(sigs[i], policies_[i]);
            remove(policies[sigs[i]], policies_[i]);
            delete sigPolicy[sigs[i]][policies_[i]];
        }
        emit EventsLib.PoliciesRemoved(sigs, policies_);
    }

    function submitPolicyData(
        mapping(bytes4 => mapping(address => bool)) storage sigPolicy,
        bytes4 sig,
        address policy,
        bytes calldata data
    ) external {
        if (!sigPolicy[sig][policy]) revert ErrorsLib.Forbidden();
        IPolicy(policy).receiveUserData(msg.sender, data);
    }

    function remove(address[] storage list, address element) public {
        uint256 length = list.length;
        for (uint256 i = 0; i < length; i++) {
            if (list[i] == element) {
                if (i != length - 1) {
                    list[i] = list[length - 1];
                }
                list.pop();
                return;
            }
        }
        revert ErrorsLib.NotFound(element);
    }
}
