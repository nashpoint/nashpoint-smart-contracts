// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {INodeRegistry} from "./interfaces/INodeRegistry.sol";

/**
 * @title NodeRegistry
 * @author ODND Studios
 */
contract NodeRegistry is INodeRegistry, Ownable {
    /* MODIFIERS */
    modifier onlyFactory() {
        if (!isFactory[msg.sender]) revert ErrorsLib.NotFactory();
        _;
    }

    modifier onlyInitialized() {
        if (!isInitialized) revert ErrorsLib.NotInitialized();
        _;
    }

    /* STORAGE */
    /// @inheritdoc INodeRegistry
    mapping(address => bool) public isNode;
    /// @inheritdoc INodeRegistry
    mapping(address => bool) public isFactory;
    /// @inheritdoc INodeRegistry
    mapping(address => bool) public isRouter;
    /// @inheritdoc INodeRegistry
    mapping(address => bool) public isQuoter;
    /// @inheritdoc INodeRegistry
    mapping(address => bool) public isRebalancer;
    /// @inheritdoc INodeRegistry
    mapping(address => bool) public isPricer;
    /// @inheritdoc INodeRegistry
    bool public isInitialized;

    // todo: add arbitry module mapping

    address public protocolFeeAddress;
    uint256 public protocolManagementFee;
    uint256 public protocolExecutionFee;

    /* CONSTRUCTOR */
    constructor(address owner_) Ownable(owner_) {}

    /* EXTERNAL */
    /// @inheritdoc INodeRegistry
    function initialize(
        address[] calldata factories_,
        address[] calldata routers_,
        address[] calldata quoters_,
        address[] calldata rebalancers_,
        address[] calldata pricers_
    ) external onlyOwner {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();

        _initalizeFactories(factories_);
        _initalizeRouters(routers_);
        _initalizeQuoters(quoters_);
        _initalizeRebalancers(rebalancers_);
        _initalizePricers(pricers_);
        isInitialized = true;
    }

    /* FACTORY */
    /// @inheritdoc INodeRegistry
    function addNode(address node_) external onlyInitialized onlyFactory {
        if (isNode[node_]) revert ErrorsLib.AlreadySet();

        isNode[node_] = true;
        emit EventsLib.NodeAdded(node_);
    }

    /* OWNER */
    /// @inheritdoc INodeRegistry
    function addFactory(address factory_) external onlyInitialized onlyOwner {
        if (isFactory[factory_]) revert ErrorsLib.AlreadySet();

        isFactory[factory_] = true;
        emit EventsLib.FactoryAdded(factory_);
    }

    /// @inheritdoc INodeRegistry
    function removeFactory(address factory_) external onlyInitialized onlyOwner {
        if (!isFactory[factory_]) revert ErrorsLib.NotSet();

        isFactory[factory_] = false;
        emit EventsLib.FactoryRemoved(factory_);
    }

    /// @inheritdoc INodeRegistry
    function addRouter(address router_) external onlyInitialized onlyOwner {
        if (isRouter[router_]) revert ErrorsLib.AlreadySet();

        isRouter[router_] = true;
        emit EventsLib.RouterAdded(router_);
    }

    /// @inheritdoc INodeRegistry
    function removeRouter(address router_) external onlyInitialized onlyOwner {
        if (!isRouter[router_]) revert ErrorsLib.NotSet();

        isRouter[router_] = false;
        emit EventsLib.RouterRemoved(router_);
    }

    /// @inheritdoc INodeRegistry
    function addQuoter(address quoter_) external onlyInitialized onlyOwner {
        if (isQuoter[quoter_]) revert ErrorsLib.AlreadySet();

        isQuoter[quoter_] = true;
        emit EventsLib.QuoterAdded(quoter_);
    }

    /// @inheritdoc INodeRegistry
    function removeQuoter(address quoter_) external onlyInitialized onlyOwner {
        if (!isQuoter[quoter_]) revert ErrorsLib.NotSet();

        isQuoter[quoter_] = false;
        emit EventsLib.QuoterRemoved(quoter_);
    }

    /// @inheritdoc INodeRegistry
    function addRebalancer(address rebalancer_) external onlyInitialized onlyOwner {
        if (isRebalancer[rebalancer_]) revert ErrorsLib.AlreadySet();

        isRebalancer[rebalancer_] = true;
        emit EventsLib.RebalancerAdded(rebalancer_);
    }

    /// @inheritdoc INodeRegistry
    function removeRebalancer(address rebalancer_) external onlyInitialized onlyOwner {
        if (!isRebalancer[rebalancer_]) revert ErrorsLib.NotSet();

        isRebalancer[rebalancer_] = false;
        emit EventsLib.RebalancerRemoved(rebalancer_);
    }

    /// @inheritdoc INodeRegistry
    function addPricer(address pricer_) external onlyInitialized onlyOwner {
        if (isPricer[pricer_]) revert ErrorsLib.AlreadySet();

        isPricer[pricer_] = true;
        emit EventsLib.PricerAdded(pricer_);
    }

    /// @inheritdoc INodeRegistry
    function removePricer(address pricer_) external onlyInitialized onlyOwner {
        if (!isPricer[pricer_]) revert ErrorsLib.NotSet();

        isPricer[pricer_] = false;
        emit EventsLib.PricerRemoved(pricer_);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolFeeAddress(address newProtocolFeeAddress) external onlyOwner {
        protocolFeeAddress = newProtocolFeeAddress;
        emit EventsLib.ProtocolFeeAddressSet(newProtocolFeeAddress);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolManagementFee(uint256 newProtocolManagementFee) external onlyOwner {
        protocolManagementFee = newProtocolManagementFee;
        emit EventsLib.ProtocolManagementFeeSet(newProtocolManagementFee);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolExecutionFee(uint256 newProtocolExecutionFee) external onlyOwner {
        protocolExecutionFee = newProtocolExecutionFee;
        emit EventsLib.ProtocolExecutionFeeSet(newProtocolExecutionFee);
    }

    /* VIEW */
    /// @inheritdoc INodeRegistry
    function isSystemContract(address contract_) external view returns (bool) {
        return (
            isNode[contract_] || isFactory[contract_] || isRouter[contract_] || isQuoter[contract_]
                || isRebalancer[contract_] || contract_ == address(this)
        );
    }

    function _initalizeFactories(address[] calldata factories_) internal {
        for (uint256 i = 0; i < factories_.length; i++) {
            if (factories_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isFactory[factories_[i]] = true;
            emit EventsLib.FactoryAdded(factories_[i]);
        }
    }

    function _initalizeRouters(address[] calldata routers_) internal {
        for (uint256 i = 0; i < routers_.length; i++) {
            if (routers_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isRouter[routers_[i]] = true;
            emit EventsLib.RouterAdded(routers_[i]);
        }
    }

    function _initalizeQuoters(address[] calldata quoters_) internal {
        for (uint256 i = 0; i < quoters_.length; i++) {
            if (quoters_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isQuoter[quoters_[i]] = true;
            emit EventsLib.QuoterAdded(quoters_[i]);
        }
    }

    function _initalizeRebalancers(address[] calldata rebalancers_) internal {
        for (uint256 i = 0; i < rebalancers_.length; i++) {
            if (rebalancers_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isRebalancer[rebalancers_[i]] = true;
            emit EventsLib.RebalancerAdded(rebalancers_[i]);
        }
    }

    function _initalizePricers(address[] calldata pricers_) internal {
        for (uint256 i = 0; i < pricers_.length; i++) {
            if (pricers_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isPricer[pricers_[i]] = true;
            emit EventsLib.PricerAdded(pricers_[i]);
        }
    }
}
