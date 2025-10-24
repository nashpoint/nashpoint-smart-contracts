// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {IPolicy} from "src/interfaces/IPolicy.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

/**
 * @title NodeLib
 * @notice Shared helpers for node policy registration and maintenance
 */
library NodeLib {
    /// @notice Adds policies for selectors after verifying them against the registry
    /// @param registry Address of the node registry contract
    /// @param policies Mapping storing registered policies per selector
    /// @param sigPolicy Mapping that tracks whether a policy is active for a selector
    /// @param proof Merkle proof nodes
    /// @param proofFlags Flags describing the Merkle multi-proof
    /// @param sigs Function selectors to update
    /// @param policies_ Policy contract addresses to attach
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

    /// @notice Removes policies from selectors
    /// @param policies Mapping storing registered policies per selector
    /// @param sigPolicy Mapping that tracks whether a policy is active for a selector
    /// @param sigs Function selectors to update
    /// @param policies_ Policy contract addresses to detach
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

    /// @notice Forwards auxiliary data to a registered policy
    /// @param sigPolicy Mapping that tracks registered policies
    /// @param sig Selector the data applies to
    /// @param policy Policy contract that will receive the data
    /// @param data ABI encoded payload to forward
    function submitPolicyData(
        mapping(bytes4 => mapping(address => bool)) storage sigPolicy,
        bytes4 sig,
        address policy,
        bytes calldata data
    ) external {
        if (!sigPolicy[sig][policy]) revert ErrorsLib.Forbidden();
        IPolicy(policy).receiveUserData(msg.sender, data);
    }

    /// @notice Utility helper to remove an element from an array without preserving order
    /// @param list Storage array to mutate
    /// @param element Address to remove
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
