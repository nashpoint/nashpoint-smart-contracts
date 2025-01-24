// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IQuoter {
    /// @notice Returns the total assets in the Node based on valuation of the underlying components
    /// @return The total assets in the Node
    function getTotalAssets() external view returns (uint256);

    /// @notice Calculates the deposit bonus based on the asset, assets, shares exiting, reserve cash, total assets, max swing factor, and target reserve ratio
    /// @param asset The asset of the Node
    /// @param assets The assets to deposit
    /// @param sharesExiting The shares exiting
    /// @param reserveCash The reserve cash of the Node
    /// @param totalAssets The total assets of the Node
    /// @param maxSwingFactor The max swing factor of the Node
    /// @param targetReserveRatio The target reserve ratio of the Node
    /// @return The shares to mint after applying the deposit bonus
    function calculateDepositBonus(
        address asset,
        uint256 assets,
        uint256 sharesExiting,
        uint256 reserveCash,
        uint256 totalAssets,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external view returns (uint256);

    /// @notice Calculates the redeem penalty based on the asset, shares, shares exiting, reserve cash, total assets, max swing factor, and target reserve ratio
    /// @param asset The asset of the Node
    /// @param shares The shares to redeem
    /// @param sharesExiting The shares exiting
    /// @param reserveCash The reserve cash of the Node
    /// @param totalAssets The total assets of the Node
    /// @param maxSwingFactor The max swing factor of the Node
    /// @param targetReserveRatio The target reserve ratio of the Node
    /// @return The assets to redeem after applying the redeem penalty
    function calculateRedeemPenalty(
        address asset,
        uint256 shares,
        uint256 sharesExiting,
        uint256 reserveCash,
        uint256 totalAssets,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external returns (uint256);
}
