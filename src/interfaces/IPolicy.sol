// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IPolicy {
    /// @notice Executes the policy's validation logic for a given call
    /// @param caller Original caller of the Node function
    /// @param data ABI encoded call data that triggered the policy check
    function onCheck(address caller, bytes calldata data) external view;

    /// @notice Supplies auxiliary data that policies may need for future checks
    /// @param caller The address providing the data
    /// @param data ABI encoded payload understood by the policy
    function receiveUserData(address caller, bytes calldata data) external;
}
