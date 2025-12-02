// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {PolicyBase} from "src/policies/abstract/PolicyBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

/**
 * @title ListBase
 * @notice Abstract helper for policies that require per-node allow / forbid lists
 * Can be used for whitelisting or blacklisting (but not both simultaneously!) users/operators etc.
 */
abstract contract ListBase is PolicyBase {
    /// @notice Merkle root that defines the whitelist for each node
    mapping(address node => bytes32 root) public roots;
    /// @notice Cached Merkle proofs submitted by actors per node
    mapping(address node => mapping(address actor => bytes32[] proof)) public proofs;
    /// @notice Direct storage allow/deny list per node (true-flagged)
    mapping(address node => mapping(address actor => bool present)) public list;

    /// @notice Emitted when a node's Merkle root is set or updated
    event NodeRootUpdated(address indexed node, bytes32 root);
    /// @notice Emitted when an actor submits a new Merkle proof for a node
    event ProofUpdated(address indexed node, address indexed actor, bytes32[] proof);
    /// @notice Emitted when actors are directly added to a node's list
    event ListAdded(address indexed node, address[] actors);
    /// @notice Emitted when actors are directly removed from a node's list
    event ListRemoved(address indexed node, address[] actors);

    /// @param registry_ Address of the shared policy registry
    constructor(address registry_) PolicyBase(registry_) {}

    /// @notice Sets the Merkle root used to validate actors for a node
    /// @param node Node whose list root is updated
    /// @param root Merkle root encoding authorized actors
    function setRoot(address node, bytes32 root) external onlyNodeOwner(node) {
        roots[node] = root;
        emit NodeRootUpdated(node, root);
    }

    /// @notice Whitelists actors directly for a node
    /// @param node Node whose list is updated
    /// @param actors Addresses granted access
    function add(address node, address[] calldata actors) external onlyNodeOwner(node) {
        for (uint256 i; i < actors.length; i++) {
            list[node][actors[i]] = true;
        }
        emit ListAdded(node, actors);
    }

    /// @notice Removes actors from a node's direct list
    /// @param node Node whose list is updated
    /// @param actors Addresses to revoke
    function remove(address node, address[] calldata actors) external onlyNodeOwner(node) {
        for (uint256 i; i < actors.length; i++) {
            list[node][actors[i]] = false;
        }
        emit ListRemoved(node, actors);
    }

    /// @notice Restricts access to actors that pass the whitelist validation
    modifier onlyWhitelisted(address node, address actor) {
        _isWhitelisted(node, actor);
        _;
    }

    /// @notice Blocks actors that are blacklisted for the given node
    modifier notBlacklisted(address node, address actor) {
        _notBlacklisted(node, actor);
        _;
    }

    /// @notice Checks whether an actor is either directly listed or included in the Merkle tree
    /// @dev Reverts with `ErrorsLib.NotWhitelisted` if the actor fails both checks
    function _isWhitelisted(address node, address actor) internal view {
        if (list[node][actor]) return;
        bytes32[] memory proof = proofs[node][actor];
        if (proof.length == 0) revert ErrorsLib.NotWhitelisted();
        if (!MerkleProof.verify(proof, roots[node], _getLeaf(actor))) revert ErrorsLib.NotWhitelisted();
    }

    /// @notice Reverts if an actor is explicitly flagged in the direct list
    function _notBlacklisted(address node, address actor) internal view {
        if (list[node][actor]) revert ErrorsLib.Blacklisted();
    }

    /// @notice Computes the canonical Merkle leaf used for actor verification
    /// @param actor Address whose leaf is requested
    /// @return Leaf hash compliant with the tree generated off-chain
    function _getLeaf(address actor) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(actor))));
    }

    /// @inheritdoc PolicyBase
    /// @dev Persists the caller-provided Merkle proof for later validation
    function _processCallerData(address caller, bytes calldata data) internal virtual override {
        (bytes32[] memory proof) = abi.decode(data, (bytes32[]));
        proofs[msg.sender][caller] = proof;
        emit ProofUpdated(msg.sender, caller, proof);
    }
}
