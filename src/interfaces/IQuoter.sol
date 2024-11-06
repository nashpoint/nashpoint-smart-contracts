// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IQuoter {
    /// @notice Returns the total assets in the Node based on valuation of the underlying components
    function getTotalAssets(address node) external view returns (uint256);

    /// @notice Returns the price of a share of the Node
    function getPrice(address node) external view returns (uint128);
}
