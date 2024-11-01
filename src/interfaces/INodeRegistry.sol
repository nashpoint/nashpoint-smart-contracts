// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title INodeRegistry
 * @author ODND Studios
 * @notice Interface for the NodeRegistry contract
 */
interface INodeRegistry {
    /**
     * @notice Initializes the registry with initial contracts
     * @param factories_ Array of factory addresses to initialize
     * @param routers_ Array of router addresses to initialize
     * @param quoters_ Array of quoter addresses to initialize
     */
    function initialize(address[] calldata factories_, address[] calldata routers_, address[] calldata quoters_)
        external;

    /**
     * @notice Adds a new node to the registry (only callable by factory)
     * @param node_ Address of node to add
     */
    function addNode(address node_) external;

    /**
     * @notice Adds a new factory to the registry
     * @param factory_ Address of factory to add
     */
    function addFactory(address factory_) external;

    /**
     * @notice Removes a factory from the registry
     * @param factory_ Address of factory to remove
     */
    function removeFactory(address factory_) external;

    /**
     * @notice Adds a new router to the registry
     * @param router_ Address of router to add
     */
    function addRouter(address router_) external;

    /**
     * @notice Removes a router from the registry
     * @param router_ Address of router to remove
     */
    function removeRouter(address router_) external;

    /**
     * @notice Adds a new quoter to the registry
     * @param quoter_ Address of quoter to add
     */
    function addQuoter(address quoter_) external;

    /**
     * @notice Removes a quoter from the registry
     * @param quoter_ Address of quoter to remove
     */
    function removeQuoter(address quoter_) external;

    /**
     * @notice Returns whether an address is a registered node
     * @param node_ Address to check
     * @return bool True if address is a registered node
     */
    function isNode(address node_) external view returns (bool);

    /**
     * @notice Returns whether an address is a registered factory
     * @param factory_ Address to check
     * @return bool True if address is a registered factory
     */
    function isFactory(address factory_) external view returns (bool);

    /**
     * @notice Returns whether an address is a registered router
     * @param router_ Address to check
     * @return bool True if address is a registered router
     */
    function isRouter(address router_) external view returns (bool);

    /**
     * @notice Returns whether an address is a registered quoter
     * @param quoter_ Address to check
     * @return bool True if address is a registered quoter
     */
    function isQuoter(address quoter_) external view returns (bool);

    /**
     * @notice Returns whether the registry has been initialized
     * @return bool True if registry is initialized
     */
    function isInitialized() external view returns (bool);

    /**
     * @notice Returns whether an address is a system contract
     * @param contract_ Address to check
     * @return bool True if address is a system contract
     */
    function isSystemContract(address contract_) external view returns (bool);
}
