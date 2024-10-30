// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./INode.sol";

interface IQuoter {
    /// @notice Node that the Quoter serves
    function node() external view returns (INode);

    /// @notice Returns the ERC4626 status of a component
    function isErc4626(address component) external view returns (bool);

    /// @notice Returns the ERC7540 status of a component
    function isErc7540(address component) external view returns (bool);

    /// @notice Sets the ERC4626 status of a component
    function setErc4626(address component, bool value) external;

    /// @notice Sets the ERC7540 status of a component
    function setErc7540(address component, bool value) external;

    /// @notice Returns the total assets in the Node based on valuation of the underlying components
    function getTotalAssets() external view returns (uint256);

    /// @notice Returns the price of a share of the Node
    function getPrice() external view returns (uint128);
}
