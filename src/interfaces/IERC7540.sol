// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC7540 {
    // Functions
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);
    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);
    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);
    function processPendingDeposits() external;

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);
    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);
    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);
    function processPendingRedemptions() external;

    function isOperator(address controller, address operator) external view returns (bool);
    function setOperator(address operator, bool approved) external returns (bool);

    // function currentRequestId() external view returns (uint256);
    // function poolManager() external view returns (address);
    // function pendingShares() external view returns (uint256);

    // function share() external view returns (address);

    // IERC4626
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    // IERC20
    function balanceOf(address account) external view returns (uint256);
}
