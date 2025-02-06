// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title INodeRegistry
 * @author ODND Studios
 * @notice Interface for the NodeRegistry contract
 */
enum RegistryType {
    UNUSED,
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
        address[] calldata rebalancers_,
        address feeAddress_,
        uint64 managementFee_,
        uint64 executionFee_,
        uint64 maxSwingFactor_
    ) external;

    /**
     * @notice Sets the type of an address
     * @param addr Address to set the type for
     * @param type_ Type to set
     * @param status Status to set
     * @dev This function is used to set the type of an address
     *      Set to true to add, false to remove
     */
    function setRegistryType(address addr, RegistryType type_, bool status) external;

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
     * @notice Returns whether an address has a role
     * @param addr Address to check
     * @param type_ RegistryType to check
     * @return bool True if address has role
     */
    function isRegistryType(address addr, RegistryType type_) external view returns (bool);

    /**
     * @notice Returns whether the registry has been initialized
     * @return bool True if registry is initialized
     */
    function isInitialized() external view returns (bool);

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

    /**
     * @notice Returns the protocol max swing factor
     * @return uint64 Protocol max swing factor
     */
    function protocolMaxSwingFactor() external view returns (uint64);

    /**
     * @notice Sets the protocol max swing factor
     * @param newProtocolMaxSwingFactor Protocol max swing factor
     */
    function setProtocolMaxSwingFactor(uint64 newProtocolMaxSwingFactor) external;
}
