// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title INodeRegistry
 * @author ODND Studios
 * @notice Interface for the NodeRegistry contract
 */
enum RegistryType {
    NODE,
    FACTORY,
    ROUTER,
    QUOTER,
    REBALANCER
}

interface INodeRegistry {
    /**
     * @notice Initializes the registry with initial contracts
     * @param factories_ Array of factory addresses to initialize
     * @param routers_ Array of router addresses to initialize
     * @param quoters_ Array of quoter addresses to initialize
     * @param rebalancers_ Array of rebalancer addresses to initialize
     */
    function initialize(
        address[] calldata factories_,
        address[] calldata routers_,
        address[] calldata quoters_,
        address[] calldata rebalancers_
    ) external;

    /**
     * @notice Sets the role of an address
     * @param addr Address to set the role for
     * @param role Role to set
     * @param status Status to set
     */
    function setRole(address addr, RegistryType role, bool status) external;

    /**
     * @notice Adds a node to the registry
     * @param node_ Address of the node to add
     */
    function addNode(address node_) external;

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
     * @notice Returns whether an address is a registered rebalancer
     * @param rebalancer_ Address to check
     * @return bool True if address is a registered rebalancer
     */
    function isRebalancer(address rebalancer_) external view returns (bool);

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

    /**
     * @notice Returns the address of the protocol fee address
     * @return address Address of the protocol fee address
     */
    function protocolFeeAddress() external view returns (address);

    /**
     * @notice Sets the address of the protocol fee address
     * @param newProtocolFeeAddress Address of the protocol fee address
     */
    function setProtocolFeeAddress(address newProtocolFeeAddress) external;

    /**
     * @notice Returns the protocol management fee
     * @return uint256 Protocol management fee
     */
    function protocolManagementFee() external view returns (uint64);

    /**
     * @notice Sets the protocol management fee
     * @param newProtocolManagementFee Protocol management fee
     */
    function setProtocolManagementFee(uint64 newProtocolManagementFee) external;

    /**
     * @notice Returns the protocol execution fee
     * @return uint256 Protocol execution fee
     */
    function protocolExecutionFee() external view returns (uint64);

    /**
     * @notice Sets the protocol execution fee
     * @param newProtocolExecutionFee Protocol execution fee
     */
    function setProtocolExecutionFee(uint64 newProtocolExecutionFee) external;
}
