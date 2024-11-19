// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ComponentAllocation} from "../interfaces/INode.sol";

/// @title EventsLib
/// @author ODND Studios
library EventsLib {
    /// @notice Emitted when `escrow` is set to `newEscrow`.
    event SetEscrow(address indexed newEscrow);

    /// @notice Emitted when `newRouter` is added to the routers.
    event AddRouter(address indexed newRouter);

    /// @notice Emitted when `oldRouter` is removed from the routers.
    event RemoveRouter(address indexed oldRouter);

    /// @notice Emitted when a node is created
    event CreateNode(
        address indexed node, address asset, string name, string symbol, address owner, address rebalancer, bytes32 salt
    );

    /// @notice Emitted when a Rebalancer executes an external call.
    event Execute(address indexed target, uint256 value, bytes data, bytes result);

    /// @notice Emitted when `operator` is added.
    event AddOperator(address indexed operator);

    /// @notice Emitted when `operator` is removed.
    event RemoveOperator(address indexed operator);

    /// @notice Emitted when `newManager` is set.
    event SetManager(address indexed newManager);

    /// @notice Emitted when `factory` is added.
    event FactoryAdded(address indexed factory);

    /// @notice Emitted when `factory` is removed.
    event FactoryRemoved(address indexed factory);

    /// @notice Emitted when `router` is added.
    event RouterAdded(address indexed router);

    /// @notice Emitted when `router` is removed.
    event RouterRemoved(address indexed router);

    /// @notice Emitted when `quoter` is added.
    event QuoterAdded(address indexed quoter);

    /// @notice Emitted when `quoter` is removed.
    event QuoterRemoved(address indexed quoter);

    /// @notice Emitted when `node` is added.
    event NodeAdded(address indexed node);

    /// @notice Emitted when `node` is removed.
    event NodeRemoved(address indexed node);

    /// @notice Emitted when a rebalancer is set on a node
    event SetRebalancer(address indexed rebalancer);

    /// @notice Emitted when a rebalancer is added to node registry
    event RebalancerAdded(address indexed rebalancer);

    /// @notice Emitted when a rebalancer is removed from node registry
    event RebalancerRemoved(address indexed rebalancer);

    /// @notice Emitted when a quoter is set.
    event SetQuoter(address indexed quoter);

    /// @notice Emitted when a node is initialized.
    event Initialize(address escrow, address manager);

    /// @notice Emitted when a component is added to a node
    event ComponentAdded(address indexed node, address indexed component, ComponentAllocation allocation);

    /// @notice Emitted when a component is removed from a node
    event ComponentRemoved(address indexed node, address indexed component);

    /// @notice Emitted when a component's allocation is updated
    event ComponentAllocationUpdated(address indexed node, address indexed component, ComponentAllocation allocation);

    /// @notice Emitted when the reserve allocation is updated
    event ReserveAllocationUpdated(address indexed node, ComponentAllocation allocation);

    /// @notice Emitted when a target is whitelisted
    event TargetWhitelisted(address indexed target, bool status);

    /// @notice Emitted when approval is granted on the escrow
    event Approve(address token, address spender, uint256 amount);

    /// @notice Emitted when a deposit is claimable
    event DepositClaimable(address indexed controller, uint256 requestId, uint256 assets, uint256 shares);

    /// @notice Emitted when a redeem is claimable
    event RedeemClaimable(address indexed controller, uint256 requestId, uint256 assets, uint256 shares);

    /// @notice Emitted when swing pricing is enabled or disabled
    event SwingPricingStatusUpdated(bool status);
}
