// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IQuoter {
    /// @notice Returns the total assets in the Node based on valuation of the underlying components
    function getTotalAssets() external view returns (uint256);

    /// @notice Calculates the deposit bonus based on the asset, assets, max swing factor, and target reserve ratio
    /// @param asset The asset of the Node
    /// @param assets The assets to deposit
    /// @param maxSwingFactor The max swing factor of the Node
    /// @param targetReserveRatio The target reserve ratio of the Node
    /// @return The deposit bonus
    function calculateDepositBonus(
        address asset,
        uint256 assets,
        uint256 sharesExiting,
        uint256 reserveCash,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external view returns (uint256);

    /// @notice Calculates the redeem penalty based on the asset, shares exiting, shares, max swing factor, and target reserve ratio
    /// @param asset The asset of the Node
    /// @param sharesExiting The shares exiting
    /// @param shares The shares to redeem
    /// @param maxSwingFactor The max swing factor of the Node
    /// @param targetReserveRatio The target reserve ratio of the Node
    /// @return The redeem penalty
    function calculateRedeemPenalty(
        address asset,
        uint256 sharesExiting,
        uint256 shares,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external returns (uint256);
}
