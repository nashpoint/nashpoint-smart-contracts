// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title INode
 * @author ODND Studios
 */
interface INode {
    /// @notice Sets the escrow.
    /// @param newEscrow The address of the new escrow.
    function setEscrow(address newEscrow) external;

    /// @notice Adds a rebalancer.
    /// @param newRebalancer The address of the new rebalancer.
    function addRebalancer(address newRebalancer) external;

    /// @notice Removes a rebalancer.
    /// @param oldRebalancer The address of the rebalancer to remove.
    function removeRebalancer(address oldRebalancer) external;

    /// @notice Allows authorized rebalancers to execute external calls.
    /// @param target The address of the contract to interact with.
    /// @param value The amount of Ether to send with the call.
    /// @param data The calldata for the function to be called.
    /// @return result The data returned by the external call.
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory result);
}
