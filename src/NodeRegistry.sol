// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {INodeRegistry, RegistryType} from "./interfaces/INodeRegistry.sol";

/**
 * @title NodeRegistry
 * @author ODND Studios
 */
contract NodeRegistry is INodeRegistry, Ownable {
    /* MODIFIERS */
    modifier onlyFactory() {
        if (!roles[msg.sender][RegistryType.FACTORY]) revert ErrorsLib.NotFactory();
        _;
    }

    modifier onlyInitialized() {
        if (!isInitialized) revert ErrorsLib.NotInitialized();
        _;
    }

    mapping(address => mapping(RegistryType => bool)) public roles;

    bool public isInitialized;
    address public protocolFeeAddress;
    uint64 public protocolManagementFee;
    uint64 public protocolExecutionFee;

    /* CONSTRUCTOR */
    constructor(address owner_) Ownable(owner_) {}

    /* EXTERNAL */
    /// @inheritdoc INodeRegistry
    function initialize(
        address[] calldata factories_,
        address[] calldata routers_,
        address[] calldata quoters_,
        address[] calldata rebalancers_
    ) external onlyOwner {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();

        _initalizeFactories(factories_);
        _initalizeRouters(routers_);
        _initalizeQuoters(quoters_);
        _initalizeRebalancers(rebalancers_);
        isInitialized = true;
    }

    function setRole(address addr, RegistryType role, bool status) external onlyInitialized onlyOwner {
        if (role == RegistryType.NODE) revert ErrorsLib.NotFactory();
        if (roles[addr][role] == status) revert ErrorsLib.AlreadySet();
        roles[addr][role] = status;
        emit EventsLib.RoleSet(addr, role, status);
    }

    function addNode(address node) external onlyInitialized onlyFactory {
        if (roles[node][RegistryType.NODE]) revert ErrorsLib.AlreadySet();
        roles[node][RegistryType.NODE] = true;
        emit EventsLib.NodeAdded(node);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolFeeAddress(address newProtocolFeeAddress) external onlyOwner {
        if (newProtocolFeeAddress == address(0)) revert ErrorsLib.ZeroAddress();
        protocolFeeAddress = newProtocolFeeAddress;
        emit EventsLib.ProtocolFeeAddressSet(newProtocolFeeAddress);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolManagementFee(uint64 newProtocolManagementFee) external onlyOwner {
        protocolManagementFee = newProtocolManagementFee;
        emit EventsLib.ProtocolManagementFeeSet(newProtocolManagementFee);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolExecutionFee(uint64 newProtocolExecutionFee) external onlyOwner {
        protocolExecutionFee = newProtocolExecutionFee;
        emit EventsLib.ProtocolExecutionFeeSet(newProtocolExecutionFee);
    }

    /* VIEW */
    /// @inheritdoc INodeRegistry
    function isSystemContract(address contract_) external view returns (bool) {
        return (
            roles[contract_][RegistryType.NODE] || roles[contract_][RegistryType.FACTORY]
                || roles[contract_][RegistryType.ROUTER] || roles[contract_][RegistryType.QUOTER]
                || roles[contract_][RegistryType.REBALANCER] || contract_ == address(this)
        );
    }

    function isNode(address node_) external view returns (bool) {
        return roles[node_][RegistryType.NODE];
    }

    function isFactory(address factory_) external view returns (bool) {
        return roles[factory_][RegistryType.FACTORY];
    }

    function isRouter(address router_) external view returns (bool) {
        return roles[router_][RegistryType.ROUTER];
    }

    function isQuoter(address quoter_) external view returns (bool) {
        return roles[quoter_][RegistryType.QUOTER];
    }

    function isRebalancer(address rebalancer_) external view returns (bool) {
        return roles[rebalancer_][RegistryType.REBALANCER];
    }

    function _initalizeFactories(address[] calldata factories_) internal {
        for (uint256 i = 0; i < factories_.length; i++) {
            if (factories_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            roles[factories_[i]][RegistryType.FACTORY] = true;
            emit EventsLib.RoleSet(factories_[i], RegistryType.FACTORY, true);
        }
    }

    function _initalizeRouters(address[] calldata routers_) internal {
        for (uint256 i = 0; i < routers_.length; i++) {
            if (routers_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            roles[routers_[i]][RegistryType.ROUTER] = true;
            emit EventsLib.RoleSet(routers_[i], RegistryType.ROUTER, true);
        }
    }

    function _initalizeQuoters(address[] calldata quoters_) internal {
        for (uint256 i = 0; i < quoters_.length; i++) {
            if (quoters_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            roles[quoters_[i]][RegistryType.QUOTER] = true;
            emit EventsLib.RoleSet(quoters_[i], RegistryType.QUOTER, true);
        }
    }

    function _initalizeRebalancers(address[] calldata rebalancers_) internal {
        for (uint256 i = 0; i < rebalancers_.length; i++) {
            if (rebalancers_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            roles[rebalancers_[i]][RegistryType.REBALANCER] = true;
            emit EventsLib.RoleSet(rebalancers_[i], RegistryType.REBALANCER, true);
        }
    }
}
