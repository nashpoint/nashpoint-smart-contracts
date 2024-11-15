// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC7575} from "./IERC7575.sol";
import {IERC7540Redeem} from "./IERC7540.sol";
import {IQuoter} from "./IQuoter.sol";

struct ComponentAllocation {
    uint256 targetWeight;
}

/**
 * @title INode
 * @author ODND Studios
 */
interface INode is IERC20Metadata, IERC7540Redeem, IERC7575 {
    event DepositClaimable(address indexed controller, uint256 indexed requestId, uint256 assets, uint256 shares);
    event RedeemClaimable(address indexed controller, uint256 indexed requestId, uint256 assets, uint256 shares);

    /// @notice The address of the node registry
    function registry() external view returns (address);

    /// @notice The address of the escrow
    function escrow() external view returns (address);

    /// @notice The address of the quoter
    function quoter() external view returns (IQuoter);

    /// @notice The address of the rebalancer
    function rebalancer() external view returns (address);

    /// @notice Returns if an address is a router
    function isRouter(address) external view returns (bool);

    /// @notice Sets the escrow
    function setEscrow(address newEscrow) external;

    /// @notice Sets the quoter
    function setQuoter(address newQuoter) external;

    /// @notice Sets the rebalancer
    function setRebalancer(address newRebalancer) external;

    /// @notice Adds a router
    function addRouter(address newRouter) external;

    /// @notice Removes a router
    function removeRouter(address oldRouter) external;

    /// @notice Allows routers to execute external calls
    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory);

    /// @notice Callback when a deposit request becomes claimable
    function onDepositClaimable(address controller, uint256 assets, uint256 shares) external;

    /// @notice Callback when a redeem request becomes claimable
    function onRedeemClaimable(address controller, uint256 assets, uint256 shares) external;

    /// @notice Returns the components of the node
    function getComponents() external view returns (address[] memory);

    /// @notice Returns whether the node has been initialized
    function isInitialized() external view returns (bool);

    /// @notice Returns the price per share in asset decimals
    function pricePerShare() external view returns (uint256);

    /// @notice Initializes the Node with escrow and manager contracts
    /// @param escrow_ The address of the escrow contract
    function initialize(address escrow_) external;

    /// @notice Adds a new component to the node
    /// @param component The address of the component to add
    /// @param allocation The allocation parameters for the component
    /// @dev Only callable by owner
    function addComponent(address component, ComponentAllocation memory allocation) external;

    /// @notice Removes a component from the node. Must have zero balance.
    /// @param component The address of the component to remove
    /// @dev Only callable by owner. Component must be rebalanced to zero before removal.
    function removeComponent(address component) external;

    /// @notice Updates the allocation for an existing component. Set to zero to rebalance out of component before removing.
    /// @param component The address of the component to update
    /// @param allocation The new allocation parameters
    /// @dev Only callable by owner
    function updateComponentAllocation(address component, ComponentAllocation memory allocation) external;

    /// @notice Updates the allocation for the reserve asset
    /// @param allocation The new allocation parameters
    /// @dev Only callable by owner
    function updateReserveAllocation(ComponentAllocation memory allocation) external;

    /// @notice Returns whether the given address is a component
    /// @param component The address to check
    /// @return bool True if the address is a component, false otherwise
    function isComponent(address component) external view returns (bool);

    /// @notice Fulfill a redeem request from the reserve
    /// @param user The address of the user to redeem for
    function fulfillRedeemFromReserve(address user) external;

    /// @notice Returns the pending redeem request for a user
    /// @param user The address of the user to check
    /// @return uint256 The pending redeem request
    function pendingRedeemRequest(uint256, address user) external view returns (uint256);

    /// @notice Enables swing pricing
    function enableSwingPricing(bool enabled) external;

    /// @notice Returns the target reserve ratio
    function targetReserveRatio() external view returns (uint256);
}
