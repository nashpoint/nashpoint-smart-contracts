// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC7540 {
    // 7540 Functions
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);
    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);
    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);
    function processPendingDeposits() external;

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);
    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);
    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);
    function processPendingRedemptions() external;

    function maxMint(address controller) external view returns (uint256 maxShares);

    function isOperator(address controller, address operator) external view returns (bool);
    function setOperator(address operator, bool approved) external returns (bool);

    function manager() external view returns (address);
    function poolId() external view returns (uint64);
    function trancheId() external view returns (bytes16);

    // IERC7575
    function asset() external view returns (address assetTokenAddress);
    function share() external view returns (address vaultShareAddress);

    // Extended Functions: these do not match 7540 spec
    function claimableDepositRequests(address) external view returns (uint256);
    function claimableRedeemRequests(address) external view returns (uint256);
    function controllerToDepositIndex(address) external view returns (uint256);
    function controllerToRedeemIndex(address) external view returns (uint256);

    // IERC4626
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    // IERC20
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}
