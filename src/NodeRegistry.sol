// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

import {INodeRegistry, RegistryType} from "./interfaces/INodeRegistry.sol";

/**
 * @title NodeRegistry
 * @author ODND Studios
 */
contract NodeRegistry is INodeRegistry, OwnableUpgradeable, UUPSUpgradeable {
    /* STATE */
    uint64 public constant WAD = 1e18;
    address public protocolFeeAddress;
    uint64 public protocolManagementFee;
    uint64 public protocolExecutionFee;
    uint64 public protocolMaxSwingFactor;
    mapping(address => mapping(RegistryType => bool)) internal roles;
    bytes32 public policiesRoot;

    /* CONSTRUCTOR */
    constructor() {
        _disableInitializers();
    }

    /* MODIFIERS */
    modifier onlyFactory() {
        if (!roles[msg.sender][RegistryType.FACTORY]) revert ErrorsLib.NotFactory();
        _;
    }

    /* EXTERNAL */
    function initialize(
        address owner,
        address feeAddress_,
        uint64 managementFee_,
        uint64 executionFee_,
        uint64 maxSwingFactor_
    ) external initializer {
        __Ownable_init(owner);
        __UUPSUpgradeable_init();

        _setProtocolFeeAddress(feeAddress_);
        _setProtocolManagementFee(managementFee_);
        _setProtocolExecutionFee(executionFee_);
        _setProtocolMaxSwingFactor(maxSwingFactor_);
    }

    function setPoliciesRoot(bytes32 newRoot) external onlyOwner {
        policiesRoot = newRoot;
        emit EventsLib.PoliciesRootUpdate(newRoot);
    }

    /// @inheritdoc INodeRegistry
    function setRegistryType(address addr, RegistryType type_, bool status) external onlyOwner {
        if (type_ == RegistryType.UNUSED) revert ErrorsLib.InvalidRole();
        if (type_ == RegistryType.NODE) revert ErrorsLib.NotFactory();
        if (roles[addr][type_] == status) revert ErrorsLib.AlreadySet();
        roles[addr][type_] = status;
        emit EventsLib.RoleSet(addr, type_, status);
    }

    /// @inheritdoc INodeRegistry
    function addNode(address node) external onlyFactory {
        if (roles[node][RegistryType.NODE]) revert ErrorsLib.AlreadySet();
        roles[node][RegistryType.NODE] = true;
        emit EventsLib.NodeAdded(node);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolFeeAddress(address newProtocolFeeAddress) external onlyOwner {
        _setProtocolFeeAddress(newProtocolFeeAddress);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolManagementFee(uint64 newProtocolManagementFee) external onlyOwner {
        _setProtocolManagementFee(newProtocolManagementFee);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolExecutionFee(uint64 newProtocolExecutionFee) external onlyOwner {
        _setProtocolExecutionFee(newProtocolExecutionFee);
    }

    /// @inheritdoc INodeRegistry
    function setProtocolMaxSwingFactor(uint64 newProtocolMaxSwingFactor) external onlyOwner {
        _setProtocolMaxSwingFactor(newProtocolMaxSwingFactor);
    }

    /* VIEW */

    /// @inheritdoc INodeRegistry
    function isNode(address node_) external view returns (bool) {
        return roles[node_][RegistryType.NODE];
    }

    /// @inheritdoc INodeRegistry
    function isRegistryType(address addr, RegistryType type_) external view returns (bool) {
        return roles[addr][type_];
    }

    function verifyPolicies(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes4[] calldata sigs,
        address[] calldata policies
    ) external view returns (bool) {
        if (sigs.length != policies.length) revert ErrorsLib.LengthMismatch();
        bytes32[] memory leaves = new bytes32[](policies.length);
        for (uint256 i; i < policies.length; i++) {
            leaves[i] = _getLeaf(sigs[i], policies[i]);
        }
        return MerkleProof.multiProofVerify(proof, proofFlags, policiesRoot, leaves);
    }

    /* INTERNAL */

    function _setProtocolFeeAddress(address newProtocolFeeAddress) internal {
        if (newProtocolFeeAddress == address(0)) revert ErrorsLib.ZeroAddress();
        if (newProtocolFeeAddress == protocolFeeAddress) revert ErrorsLib.AlreadySet();
        protocolFeeAddress = newProtocolFeeAddress;
        emit EventsLib.ProtocolFeeAddressSet(newProtocolFeeAddress);
    }

    function _setProtocolManagementFee(uint64 newProtocolManagementFee) internal {
        if (newProtocolManagementFee >= WAD) revert ErrorsLib.InvalidFee();
        protocolManagementFee = newProtocolManagementFee;
        emit EventsLib.ProtocolManagementFeeSet(newProtocolManagementFee);
    }

    function _setProtocolExecutionFee(uint64 newProtocolExecutionFee) internal {
        if (newProtocolExecutionFee >= WAD) revert ErrorsLib.InvalidFee();
        protocolExecutionFee = newProtocolExecutionFee;
        emit EventsLib.ProtocolExecutionFeeSet(newProtocolExecutionFee);
    }

    function _setProtocolMaxSwingFactor(uint64 newProtocolMaxSwingFactor) internal {
        if (newProtocolMaxSwingFactor >= WAD) revert ErrorsLib.InvalidSwingFactor();
        protocolMaxSwingFactor = newProtocolMaxSwingFactor;
        emit EventsLib.ProtocolMaxSwingFactorSet(newProtocolMaxSwingFactor);
    }

    function _getLeaf(bytes4 sig, address policy) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(sig, policy))));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
