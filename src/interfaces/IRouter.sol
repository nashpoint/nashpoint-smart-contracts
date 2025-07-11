// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title IQuoterV1
/// @author ODND Studios
interface IRouter {
    function isWhitelisted(address component) external view returns (bool status);
    function isBlacklisted(address component) external view returns (bool status);
    function getComponentAssets(address component, bool claimableOnly) external view returns (uint256 assets);
}
