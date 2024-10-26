// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC7575} from "./IERC7575.sol";
import "./IERC7540.sol";

/**
 * @title INode
 * @author ODND Studios
 */
interface INode is 
    IERC20Metadata,
    IERC7540Deposit,
    IERC7540Redeem,
    IERC7540CancelDeposit,
    IERC7540CancelRedeem,
    IERC7575
{
    event DepositClaimable(address indexed controller, uint256 indexed requestId, uint256 assets, uint256 shares);
    event RedeemClaimable(address indexed controller, uint256 indexed requestId, uint256 assets, uint256 shares);

    /// @notice The address of the escrow.
    function escrow() external view returns (address);

    /// @notice Sets the escrow.
    /// @param newEscrow The address of the new escrow.
    function setEscrow(address newEscrow) external;

    /// @notice Adds a rebalancer.
    /// @param newRebalancer The address of the new rebalancer.
    function addRebalancer(address newRebalancer) external;

    /// @notice Removes a rebalancer.
    /// @param oldRebalancer The address of the rebalancer to remove.
    function removeRebalancer(address oldRebalancer) external;

    /// @notice Allows authorized rebalancers to execute external calls.
    /// @param target The address of the contract to interact with.
    /// @param value The amount of Ether to send with the call.
    /// @param data The calldata for the function to be called.
    /// @return result The data returned by the external call.
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory result);
}
