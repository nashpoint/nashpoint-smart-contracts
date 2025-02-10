// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IQuoterV1 {
    /// @notice Calculates the deposit bonus based on the assets, reserve cash, total assets, max swing factor, and target reserve ratio
    /// @param assets The assets to deposit
    /// @param reserveCash The reserve cash of the Node
    /// @param totalAssets The total assets of the Node
    /// @param maxSwingFactor The max swing factor of the Node
    /// @param targetReserveRatio The target reserve ratio of the Node
    /// @return The shares to mint after applying the deposit bonus
    function calculateDepositBonus(
        uint256 assets,
        uint256 reserveCash,
        uint256 totalAssets,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external view returns (uint256);

    /// @notice Calculates the redeem penalty based on the shares, reserve cash, total assets, max swing factor, and target reserve ratio
    /// @param shares The shares to redeem
    /// @param reserveCash The reserve cash of the Node
    /// @param totalAssets The total assets of the Node
    /// @param maxSwingFactor The max swing factor of the Node
    /// @param targetReserveRatio The target reserve ratio of the Node
    /// @return The assets to redeem after applying the redeem penalty
    function calculateRedeemPenalty(
        uint256 shares,
        uint256 reserveCash,
        uint256 totalAssets,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external returns (uint256);
}
