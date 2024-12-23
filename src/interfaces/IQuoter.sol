// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IQuoter {
    /// @notice Returns the total assets in the Node based on valuation of the underlying components
    function getTotalAssets(address node) external view returns (uint256);

    function calculateDeposit(address asset, uint256 assets, uint256 maxSwingFactor, uint256 targetReserveRatio)
        external
        returns (uint256);

    function calculateReserveImpact(
        uint256 targetReserveRatio,
        uint256 reserveCash,
        uint256 totalAssets,
        uint256 deposit
    ) external pure returns (int256);

    function getSwingFactor(int256 reserveImpact, uint256 maxSwingFactor, uint256 targetReserveRatio)
        external
        pure
        returns (uint256);

    function getAdjustedAssets(
        address asset,
        uint256 sharesExiting,
        uint256 shares,
        uint256 maxSwingFactor,
        uint256 targetReserveRatio,
        bool swingPricingEnabled
    ) external returns (uint256);
}
