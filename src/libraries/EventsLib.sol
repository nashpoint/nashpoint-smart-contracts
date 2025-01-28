// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ComponentAllocation} from "../interfaces/INode.sol";
import {RegistryType} from "../interfaces/INodeRegistry.sol";

/// @title EventsLib
/// @author ODND Studios
library EventsLib {
    /// @notice Emitted when a node is created by the factory.
    event CreateNode(address indexed node, address asset, string name, string symbol, address owner, bytes32 salt);

    /// @notice Emitted when `node` is added to the registry.
    event NodeAdded(address indexed node);

    /// @notice Emitted when a role is set on the registry
    event RoleSet(address indexed addr, RegistryType role, bool status);

    /// @notice Emitted when protocol fee address is set on the registry
    event ProtocolFeeAddressSet(address protocolFeeAddress);

    /// @notice Emitted when protocol management fee is set on the registry
    event ProtocolManagementFeeSet(uint256 protocolManagementFee);

    /// @notice Emitted when protocol execution fee is set on the registry
    event ProtocolExecutionFeeSet(uint256 protocolExecutionFee);

    /// @notice Emitted when protocol max swing factor is set on the registry
    event ProtocolMaxSwingFactorSet(uint256 protocolMaxSwingFactor);

    /// @notice Emitted when `escrow` is updated on the node.
    event EscrowSet(address indexed newEscrow);

    /// @notice Emitted when a quoter is set for the node.
    event QuoterSet(address indexed quoter);

    /// @notice Emitted when `newRouter` is added to the node.
    event RouterAdded(address indexed newRouter);

    /// @notice Emitted when `oldRouter` is removed from the node.
    event RouterRemoved(address indexed oldRouter);

    /// @notice Emitted when a rebalancer is added to the node.
    event RebalancerAdded(address indexed rebalancer);

    /// @notice Emitted when a rebalancer is removed from the node.
    event RebalancerRemoved(address indexed rebalancer);

    /// @notice Emitted when a component is added to a node
    event ComponentAdded(address indexed component, ComponentAllocation allocation);

    /// @notice Emitted when a component is removed from a node
    event ComponentRemoved(address indexed component);

    /// @notice Emitted when a component's allocation is updated on the node
    event ComponentAllocationUpdated(address indexed component, ComponentAllocation allocation);

    /// @notice Emitted when the liquidation queue is updated on the node
    event LiquidationQueueUpdated(address[] newQueue);

    /// @notice Emitted when the reserve allocation is updated on the node
    event ReserveAllocationUpdated(ComponentAllocation allocation);

    /// @notice Emitted when swing pricing is enabled or disabled on the node
    event SwingPricingStatusUpdated(bool status, uint256 newSwingPricing);

    /// @notice Emitted when rebalance is started on the node
    event RebalanceStarted(uint256 blockStarted, uint256 duration);

    /// @notice Emitted when cooldown duration is updated on the node
    event CooldownDurationUpdated(uint256 newCooldownDuration);

    /// @notice Emitted when rebalance window is updated on the node
    event RebalanceWindowUpdated(uint256 newRebalanceWindow);

    /// @notice Emitted when a Rebalancer executes an external call on behalf of the node.
    event Execute(address indexed target, bytes data, bytes result);

    /// @notice Emitted when a node is initialized.
    event Initialize(address escrow, address manager);

    /// @notice Emitted when a component is whitelisted on the router
    event ComponentWhitelisted(address indexed component, bool status);

    /// @notice Emitted when approval is granted on the escrow
    event Approve(address token, address spender, uint256 amount);

    /// @notice Emitted when a redeem is claimable on the node
    event RedeemClaimable(address indexed controller, uint256 requestId, uint256 assets, uint256 shares);

    /// @notice Emitted when max deposit size is set on the node
    event MaxDepositSizeSet(uint256 maxDepositSize);

    /// @notice Emitted when annual management fee is set on the node
    event AnnualManagementFeeSet(uint256 annualManagementFee);

    /// @notice Emitted when node owner fee address is set on the node
    event NodeOwnerFeeAddressSet(address nodeOwnerFeeAddress);
}
