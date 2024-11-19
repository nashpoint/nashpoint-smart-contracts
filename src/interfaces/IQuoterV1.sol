// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IQuoter} from "./IQuoter.sol";

/// @title IQuoterV1
/// @author ODND Studios
interface IQuoterV1 is IQuoter {
    /// @notice Initializes the quoter with component classifications
    /// @param erc4626Components_ Array of ERC4626 component addresses
    /// @param erc7540Components_ Array of ERC7540 component addresses
    function initialize(address[] memory erc4626Components_, address[] memory erc7540Components_) external;

    /// @notice Sets whether a component is an ERC4626 vault
    /// @param component The component address
    /// @param value True if ERC4626, false otherwise
    function setErc4626(address component, bool value) external;

    /// @notice Sets whether a component is an ERC7540 vault
    /// @param component The component address
    /// @param value True if ERC7540, false otherwise
    function setErc7540(address component, bool value) external;

    /// @notice Checks if a component is an ERC4626 vault
    /// @param component The component address to check
    /// @return True if the component is an ERC4626 vault
    function isErc4626(address component) external view returns (bool);

    /// @notice Checks if a component is an ERC7540 vault
    /// @param component The component address to check
    /// @return True if the component is an ERC7540 vault
    function isErc7540(address component) external view returns (bool);

    /// @notice Checks if the quoter has been initialized
    /// @return True if initialized
    function isInitialized() external view returns (bool);
}
