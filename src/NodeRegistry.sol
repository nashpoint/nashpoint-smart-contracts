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
    bool public isInitialized;

    /* CONSTRUCTOR */
    constructor(address owner_) Ownable(owner_) {}

    /* EXTERNAL */
    /// @inheritdoc INodeRegistry
    function initialize(
        address[] calldata factories_,
        address[] calldata routers_,
        address[] calldata quoters_
    ) external onlyOwner {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();

        for (uint256 i = 0; i < factories_.length; i++) {
            if (factories_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isFactory[factories_[i]] = true;
            emit EventsLib.FactoryAdded(factories_[i]);
        }

        for (uint256 i = 0; i < routers_.length; i++) {
            if (routers_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isRouter[routers_[i]] = true;
            emit EventsLib.RouterAdded(routers_[i]);
        }

        for (uint256 i = 0; i < quoters_.length; i++) {
            if (quoters_[i] == address(0)) revert ErrorsLib.ZeroAddress();
            isQuoter[quoters_[i]] = true;
            emit EventsLib.QuoterAdded(quoters_[i]);
        }

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

    /* VIEW */
    /// @inheritdoc INodeRegistry
    function isSystemContract(address contract_) external view returns (bool) {
        return (
            isNode[contract_] ||
            isFactory[contract_] ||
            isRouter[contract_] ||
            isQuoter[contract_] ||
            contract_ == address(this)
        );
    }
}
