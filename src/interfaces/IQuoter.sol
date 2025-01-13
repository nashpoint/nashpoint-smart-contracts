// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IQuoter {
    /// @notice Returns the total assets in the Node based on valuation of the underlying components
    function getTotalAssets() external view returns (uint256);

    function calculateDepositBonus(address asset, uint256 assets, uint64 maxSwingFactor, uint64 targetReserveRatio)
        external
        view
        returns (uint256);

    function calculateRedeemPenalty(
        address asset,
        uint256 sharesExiting,
        uint256 shares,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external returns (uint256);
}
