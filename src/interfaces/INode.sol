// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC7575} from "./IERC7575.sol";
import {IERC7540} from "./IERC7540.sol";
import {IQueueManager} from "./IQueueManager.sol";
import {IQuoter} from "./IQuoter.sol";

struct ComponentAllocation {
    uint256 minimumWeight;
    uint256 maximumWeight;
    uint256 targetWeight;
}

/**
 * @title INode
 * @author ODND Studios
 */
interface INode is IERC20Metadata, IERC7540, IERC7575 {
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

    /// @notice Sets the manager
    function setManager(address newManager) external;

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

    /// @notice Function for the QueueManager to mint tokens
    function mint(address user, uint256 value) external;

    /// @notice Function for the QueueManager to burn tokens
    function burn(address user, uint256 value) external;

    /// @notice Returns the components of the node
    function getComponents() external view returns (address[] memory);

    /// @notice Returns the manager
    function manager() external view returns (IQueueManager);

    /// @notice Returns the price per share in asset decimals
    function pricePerShare() external view returns (uint256);

    /// @notice Initializes the node with escrow and manager contracts
    function initialize(address escrow_, address manager_) external;

    /// @notice Returns true if node is initialized
    function isInitialized() external view returns (bool);
}
