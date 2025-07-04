// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IRouter} from "../interfaces/IRouter.sol";
import {INode} from "../interfaces/INode.sol";
import {INodeRegistry} from "../interfaces/INodeRegistry.sol";
import {MathLib} from "./MathLib.sol";
import {ErrorsLib} from "./ErrorsLib.sol";
import {EventsLib} from "./EventsLib.sol";

/**
 * @title BaseRouter
 * @author ODND Studios
 */
abstract contract BaseRouter is IRouter {
    /* IMMUTABLES */
    /// @notice The address of the NodeRegistry
    INodeRegistry public immutable registry;
    uint256 immutable WAD = 1e18;

    /* STORAGE */
    /// @notice Mapping of whitelisted component addresses
    /// @dev Whitelisted addresses can be added to nodes as valid components
    mapping(address => bool) public isWhitelisted;

    /// @notice Mapping of blacklisted component addresses
    /// @dev Blacklisted addresses can be force removed from nodes
    mapping(address => bool) public isBlacklisted;

    /// @notice tolerace is accepted deviation from the expected amount of tokens to be returned in a transaction
    uint256 public tolerance;

    /* CONSTRUCTOR */
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* MODIFIERS */
    /// @dev Reverts if the caller is not a rebalancer for the node
    modifier onlyNodeRebalancer(address node) {
        if (!registry.isNode(node)) revert ErrorsLib.InvalidNode();
        if (!INode(node).isRebalancer(msg.sender)) revert ErrorsLib.NotRebalancer();
        _;
    }

    /// @dev Reverts if the caller is not a valid node
    modifier onlyNode() {
        if (!registry.isNode(msg.sender)) revert ErrorsLib.InvalidNode();
        _;
    }

    /// @dev Reverts if the caller is not the registry owner
    modifier onlyRegistryOwner() {
        if (msg.sender != Ownable(address(registry)).owner()) revert ErrorsLib.NotRegistryOwner();
        _;
    }

    /// @dev Reverts if the component is not a valid component on the node
    modifier onlyNodeComponent(address node, address component) {
        // Validate component is part of the node
        if (!INode(node).isComponent(component)) {
            revert ErrorsLib.InvalidComponent();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         REGISTRY OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the whitelist status of a component
    /// @param component The address to update
    /// @param status The new whitelist status
    function setWhitelistStatus(address component, bool status) external onlyRegistryOwner {
        if (component == address(0)) revert ErrorsLib.ZeroAddress();
        isWhitelisted[component] = status;
        emit EventsLib.ComponentWhitelisted(component, status);
    }

    /// @notice Updates the blacklist status of a component
    /// @param component The address to update
    /// @param status The new blacklist status
    function setBlacklistStatus(address component, bool status) external onlyRegistryOwner {
        if (component == address(0)) revert ErrorsLib.ZeroAddress();
        isBlacklisted[component] = status;
        emit EventsLib.ComponentBlacklisted(component, status);
    }

    /// @notice Batch updates whitelist status of components
    /// @param components Array of addresses to update
    /// @param statuses Array of whitelist statuses
    function batchSetWhitelistStatus(address[] calldata components, bool[] calldata statuses)
        external
        onlyRegistryOwner
    {
        if (components.length != statuses.length) revert ErrorsLib.LengthMismatch();

        uint256 length = components.length;
        for (uint256 i = 0; i < length;) {
            if (components[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isWhitelisted[components[i]] = statuses[i];
            emit EventsLib.ComponentWhitelisted(components[i], statuses[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Updates the tolerance for the router
    /// @param newTolerance The new tolerance
    function setTolerance(uint256 newTolerance) external onlyRegistryOwner {
        tolerance = newTolerance;
        emit EventsLib.ToleranceUpdated(newTolerance);
    }

    /*//////////////////////////////////////////////////////////////
                    VIRTUAL / OVERRIDABLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the assets of a component held by the node.
    /// @param component The address of the component.
    /// @param claimableOnly Whether the assets are claimable.
    /// @dev This function is virtual and should be overridden by the router implementation
    ///      Use msg.sender as the node address in inherited contracts
    /// @return assets The amount of assets of the component.
    function getComponentAssets(address component, bool claimableOnly) public view virtual returns (uint256 assets) {}

    /// @notice Returns the investment size for a component.
    /// @dev This function is virtual and should be overridden by the router implementation
    /// @param node The address of the node.
    /// @param component The address of the component.
    /// @return depositAssets The amount of assets to deposit.
    function _getInvestmentSize(address node, address component)
        internal
        view
        virtual
        returns (uint256 depositAssets)
    {}

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _computeDepositAmount(address node, address component) internal returns (uint256 depositAmount) {
        // checks if excess reserve is available to invest
        (uint256 totalAssets, uint256 currentCash, uint256 idealCashReserve) = _getNodeCashStatus(node);
        _validateReserveAboveTargetRatio(currentCash, idealCashReserve);

        // gets units of asset required to set component to target ratio
        depositAmount = _getInvestmentSize(node, component);

        // Validate deposit amount exceeds minimum threshold
        if (depositAmount < MathLib.mulDiv(totalAssets, INode(node).getComponentAllocation(component).maxDelta, WAD)) {
            revert ErrorsLib.ComponentWithinTargetRange(node, component);
        }

        // limit deposit by reserve ratio requirements
        // _validateReserveAboveTargetRatio() ensures currentCash >= idealCashReserve
        depositAmount = MathLib.min(depositAmount, currentCash - idealCashReserve);

        // subtract execution fee for protocol
        depositAmount = _subtractExecutionFee(depositAmount, node);
    }

    /// @notice Validates that the reserve is above the target ratio.
    /// @param currentCash The current cash of the node.
    /// @param idealCashReserve The ideal cash reserve of the node.
    function _validateReserveAboveTargetRatio(uint256 currentCash, uint256 idealCashReserve) internal pure {
        // checks if available reserve exceeds target ratio

        if (currentCash < idealCashReserve) {
            revert ErrorsLib.ReserveBelowTargetRatio();
        }
    }

    /// @notice Calculates the partial fulfillment of a redemption request.
    /// @param sharesPending The pending shares of the redemption request.
    /// @param assetsReturned The amount of assets returned from the redemption.
    /// @param assetsRequested The amount of assets requested from the redemption.
    /// @param sharesAdjusted The adjusted shares of the redemption request.
    /// @return _sharesPending The downscaled shares pending.
    /// @return _sharesAdjusted The downscaled shares adjusted.
    function _calculatePartialFulfill(
        uint256 sharesPending,
        uint256 assetsReturned,
        uint256 assetsRequested,
        uint256 sharesAdjusted
    ) internal pure returns (uint256 _sharesPending, uint256 _sharesAdjusted) {
        _sharesPending = MathLib.min(
            sharesPending, MathLib.mulDiv(sharesPending, assetsReturned, assetsRequested, MathLib.Rounding.Up)
        );
        _sharesAdjusted = MathLib.min(
            sharesAdjusted, MathLib.mulDiv(sharesAdjusted, assetsReturned, assetsRequested, MathLib.Rounding.Up)
        );
    }

    /// @notice Returns the node's cash status.
    /// @param node The address of the node.
    /// @return totalAssets The total assets of the node.
    /// @return currentCash The current cash of the node.
    /// @return idealCashReserve The ideal cash reserve of the node.
    function _getNodeCashStatus(address node)
        internal
        view
        returns (uint256 totalAssets, uint256 currentCash, uint256 idealCashReserve)
    {
        totalAssets = INode(node).totalAssets();
        currentCash = INode(node).getCashAfterRedemptions();
        idealCashReserve = MathLib.mulDiv(totalAssets, INode(node).targetReserveRatio(), WAD);
    }

    /// @notice Subtracts the execution fee from the transaction amount.
    /// @dev This calls transfer function on the node's asset to subtract the fee
    ///      and send to protocol fee recipient address
    /// @param transactionAmount The amount of the transaction.
    /// @param node The address of the node.
    /// @return transactionAfterFee The amount of the transaction after the fee is subtracted.
    function _subtractExecutionFee(uint256 transactionAmount, address node) internal returns (uint256) {
        uint256 executionFee = transactionAmount * registry.protocolExecutionFee() / WAD;
        if (executionFee == 0) {
            return transactionAmount;
        }

        uint256 transactionAfterFee = transactionAmount - executionFee;
        INode(node).subtractProtocolExecutionFee(executionFee);
        return transactionAfterFee;
    }

    function _safeApprove(address node, address token, address spender, uint256 amount) internal {
        bytes memory data = INode(node).execute(token, abi.encodeCall(IERC20.approve, (spender, amount)));
        if (!(data.length == 0 || abi.decode(data, (bool)))) revert ErrorsLib.SafeApproveFailed();
    }
}
