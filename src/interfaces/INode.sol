// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC7575, IERC165} from "./IERC7575.sol";
import {IERC7540Redeem} from "./IERC7540.sol";
import {IQuoterV1} from "./IQuoterV1.sol";

/// @notice Component allocation parameters
/// @dev targetWeight is the target weight of the component in the node
/// @dev maxDelta is the maximum deviation allowed from the target weight
struct ComponentAllocation {
    uint64 targetWeight;
    uint64 maxDelta;
    address router;
    bool isComponent;
}

/// @notice Redeem request state
/// @dev pendingRedeemRequest is the amount of shares pending redemption
/// @dev claimableRedeemRequest is the amount of shares claimable from the reserve
/// @dev claimableAssets is the amount of assets claimable from the reserve
/// @dev sharesAdjusted is the amount of shares adjusted for swing pricing
struct Request {
    uint256 pendingRedeemRequest;
    uint256 claimableRedeemRequest;
    uint256 claimableAssets;
    uint256 sharesAdjusted;
}

/**
 * @title INode
 * @author ODND Studios
 */
interface INode is IERC20Metadata, IERC7540Redeem, IERC7575 {
    /// @notice Returns the target reserve ratio
    /// @return uint64 The target reserve ratio
    function targetReserveRatio() external view returns (uint64);

    /// @notice Returns whether the node has been initialized
    function isInitialized() external view returns (bool);

    /// @notice Initializes the Node with escrow and manager contracts
    /// @param escrow_ The address of the escrow contract
    function initialize(address escrow_) external;

    /// @notice Adds a new component to the node
    /// @param component The address of the component to add
    /// @param targetWeight The target weight of the component
    /// @param maxDelta The max delta of the component
    /// @param router The router of the component
    /// @dev Only callable by owner
    function addComponent(address component, uint64 targetWeight, uint64 maxDelta, address router) external payable;

    /// @notice Removes a component from the node. Must have zero balance.
    /// @param component The address of the component to remove
    /// @param force Whether to force the removal of the component
    /// @dev Only callable by owner. Component must be rebalanced to zero before removal or force is true
    function removeComponent(address component, bool force) external payable;

    /// @notice Updates the allocation for an existing component. Set to zero to rebalance out of component before removing.
    /// @param component The address of the component to update
    /// @param targetWeight The target weight of the component
    /// @param maxDelta The max delta of the component
    /// @param router The router of the component
    /// @dev Only callable by owner
    function updateComponentAllocation(address component, uint64 targetWeight, uint64 maxDelta, address router)
        external
        payable;

    /// @notice Updates the allocation for the reserve asset
    /// @param targetReserveRatio The new target reserve ratio
    /// @dev Only callable by owner
    function updateTargetReserveRatio(uint64 targetReserveRatio) external payable;

    /// @notice Adds a router
    function addRouter(address newRouter) external payable;

    /// @notice Removes a router
    function removeRouter(address oldRouter) external payable;

    /// @notice Adds a rebalancer
    function addRebalancer(address newRebalancer) external payable;

    /// @notice Removes a rebalancer
    function removeRebalancer(address oldRebalancer) external payable;

    /// @notice Sets the quoter
    function setQuoter(address newQuoter) external payable;

    /// @notice Sets the liquidation queue
    function setLiquidationQueue(address[] calldata newQueue) external payable;

    /// @notice Sets the rebalance cooldown
    function setRebalanceCooldown(uint64 newRebalanceCooldown) external payable;

    /// @notice Sets the rebalance window
    function setRebalanceWindow(uint64 newRebalanceWindow) external payable;

    /// @notice Enables swing pricing
    function enableSwingPricing(bool enabled, uint64 maxSwingFactor) external payable;

    /// @notice Sets the node owner fee address
    /// @param newNodeOwnerFeeAddress The address of the new node owner fee address
    function setNodeOwnerFeeAddress(address newNodeOwnerFeeAddress) external payable;

    /// @notice Sets the annual management fee
    /// @param newAnnualManagementFee The new annual management fee
    function setAnnualManagementFee(uint64 newAnnualManagementFee) external payable;

    /// @notice Sets the max deposit size
    /// @param newMaxDepositSize The new max deposit size
    function setMaxDepositSize(uint256 newMaxDepositSize) external payable;

    /// @notice Rescues tokens from the node
    /// @param token The address of the token to rescue
    /// @param recipient The address of the recipient
    /// @param amount The amount of tokens to rescue
    function rescueTokens(address token, address recipient, uint256 amount) external payable;

    /// @notice Starts a rebalance
    function startRebalance() external payable;

    /// @notice Allows routers to execute external calls
    function execute(address target, bytes calldata data) external payable returns (bytes memory);

    /// @notice Pays management fees
    /// @dev called by owner or rebalancer to pay management fees
    /// fees are paid from the reserve in assets and transferred to the node owner and protocol fee addresses
    /// @return uint256 The amount of assets paid
    function payManagementFees() external payable returns (uint256);

    /// @notice Subtracts the protocol execution fee
    /// @dev called by router to subtract the protocol execution fee during investment in a component
    /// @param executionFee The amount of execution fee to subtract
    function subtractProtocolExecutionFee(uint256 executionFee) external payable;

    /// @notice Updates the total assets
    function updateTotalAssets() external payable;

    /// @notice Fulfill a redeem request from the reserve
    /// @param user The address of the user to redeem for
    function fulfillRedeemFromReserve(address user) external payable;

    /// @notice Fulfill a batch of redeem requests from the reserve
    /// @param controllers The addresses of the controllers to redeem for
    function fulfillRedeemBatch(address[] memory controllers) external payable;

    /// @notice Finalizes a redemption request
    /// @dev called by router or rebalancer to update the request state after a redemption
    /// @param controller The address of the controller to finalize
    /// @param assetsToReturn The amount of assets to return
    /// @param sharesPending The amount of shares pending
    /// @param sharesAdjusted The amount of shares adjusted
    function finalizeRedemption(
        address controller,
        uint256 assetsToReturn,
        uint256 sharesPending,
        uint256 sharesAdjusted
    ) external payable;

    /// @notice Requests a redemption
    /// @param shares The amount of shares to redeem
    /// @param controller The address of the controller to redeem for
    /// @param owner The address of the owner to redeem for
    /// @return uint256 The amount of shares redeemed
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256);

    /// @notice Returns the pending redeem request for a user
    /// @param user The address of the user to check
    /// @return uint256 The pending redeem request
    function pendingRedeemRequest(uint256, address user) external view returns (uint256);

    /// @notice Returns the claimable redeem request for a user
    /// @param user The address of the user to check
    /// @return uint256 The claimable redeem request
    function claimableRedeemRequest(uint256, address user) external view returns (uint256);

    /// @notice Sets an operator
    /// @param operator The address of the operator to set
    /// @param approved The approval status
    /// @return bool True if the operator was set, false otherwise
    function setOperator(address operator, bool approved) external returns (bool);

    /// @notice Returns the operator status
    /// @param operator The address of the operator to check
    /// @return bool True if the operator is approved, false otherwise
    function isOperator(address operator, address user) external view returns (bool);

    /// @notice Supports an interface
    /// @param interfaceId The interface ID to check
    /// @return bool True if the interface is supported, false otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /// @notice Returns the total assets
    /// @return uint256 The total assets
    function totalAssets() external view returns (uint256);

    /// @notice Converts assets to shares
    /// @param assets The amount of assets to convert
    /// @return shares The amount of shares received
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Converts shares to assets
    /// @param shares The amount of shares to convert
    /// @return assets The amount of assets received
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Returns the maximum deposit amount
    /// @param controller The address of the controller to check
    /// @return uint256 The maximum deposit amount
    function maxDeposit(address controller) external view returns (uint256);

    /// @notice Returns the maximum mint amount
    /// @param controller The address of the controller to check
    /// @return uint256 The maximum mint amount
    function maxMint(address controller) external view returns (uint256);

    /// @notice Returns the maximum withdraw amount
    /// @param controller The address of the controller to check
    /// @return uint256 The maximum withdraw amount
    function maxWithdraw(address controller) external view returns (uint256);

    /// @notice Returns the maximum redeem amount
    /// @param controller The address of the controller to check
    /// @return uint256 The maximum redeem amount
    function maxRedeem(address controller) external view returns (uint256);

    /// @notice Returns the preview deposit amount
    /// @param assets The amount of assets to deposit
    /// @return uint256 The preview deposit amount
    function previewDeposit(uint256 assets) external view returns (uint256);

    /// @notice Returns the preview mint amount
    /// @param shares The amount of shares to mint
    /// @return uint256 The preview mint amount
    function previewMint(uint256 shares) external view returns (uint256);

    /// @notice Returns the preview withdraw amount
    /// @param assets The amount of assets to withdraw
    /// @dev Reverts per ERC7540
    function previewWithdraw(uint256 assets) external view returns (uint256);

    /// @notice Returns the preview redeem amount
    /// @param shares The amount of shares to redeem
    /// @dev Reverts per ERC7540
    function previewRedeem(uint256 shares) external view returns (uint256);

    function requests(address controller)
        external
        view
        returns (
            uint256 pendingRedeemRequest,
            uint256 claimableRedeemRequest,
            uint256 claimableAssets,
            uint256 sharesAdjusted
        );

    /// @notice Returns the components of the node
    function getComponents() external view returns (address[] memory);

    /// @notice Returns target weight and max delta for a component
    /// @param component The address of the component
    /// @return ComponentAllocation The allocation parameters for the component
    function getComponentAllocation(address component) external view returns (ComponentAllocation memory);

    /// @notice Returns whether the given address is a component
    /// @param component The address to check
    /// @return bool True if the address is a component, false otherwise
    function isComponent(address component) external view returns (bool);

    /// @notice Checks if the cache is valid
    /// @return bool True if the cache is valid, false otherwise
    function isCacheValid() external view returns (bool);

    /// @notice Validates the component ratios
    /// @return bool True if the component ratios are valid, false otherwise
    function validateComponentRatios() external view returns (bool);

    /// @notice Returns the current cash of the node
    /// @return uint256 The current cash of the node
    /// subtracts the asset value of shares exiting from the reserve balance
    function getCashAfterRedemptions() external view returns (uint256);

    /// @notice Enforces the liquidation order
    /// @param component The address of the component
    /// @param assetsToReturn The amount of assets to return
    function enforceLiquidationOrder(address component, uint256 assetsToReturn) external view;

    /// @notice The address of the node registry
    function registry() external view returns (address);

    /// @notice The address of the escrow
    function escrow() external view returns (address);

    /// @notice The address of the quoter
    function quoter() external view returns (IQuoterV1);

    /// @notice Returns if an address is a router
    function isRouter(address) external view returns (bool);

    /// @notice Returns if an address is a rebalancer
    function isRebalancer(address) external view returns (bool);
}
