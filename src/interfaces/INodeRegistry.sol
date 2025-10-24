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
     * @notice Updates the Merkle root that whitelists node policies
     * @param newRoot New Merkle root value
     */
    function setPoliciesRoot(bytes32 newRoot) external;

    /**
     * @notice Verifies that a set of policy contracts is contained in the registry Merkle root
     * @param proof Merkle proof sibling nodes
     * @param proofFlags Flags describing the Merkle multi-proof structure
     * @param sigs Function selectors tied to the policies
     * @param policies Policy contract addresses that must be authorized
     * @return valid True when the proof is valid for the supplied selectors and policies
     */
    function verifyPolicies(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes4[] calldata sigs,
        address[] calldata policies
    ) external view returns (bool valid);

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
