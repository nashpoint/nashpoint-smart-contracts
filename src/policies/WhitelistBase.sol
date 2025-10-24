// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {PolicyBase} from "src/policies/PolicyBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

abstract contract WhitelistBase is PolicyBase {
    mapping(address node => bytes32 root) public roots;
    mapping(address node => mapping(address actor => bytes32[] proof)) public proofs;

    mapping(address node => mapping(address actor => bool whitelisted)) public whitelist;

    event NodeRootUpdated(address indexed node, bytes32 root);
    event ProofUpdated(address indexed node, address indexed actor, bytes32[] proof);

    event WhitelistAdded(address indexed node, address[] actors);
    event WhitelistRemoved(address indexed node, address[] actors);

    constructor(address registry_) PolicyBase(registry_) {}

    function setRoot(address node, bytes32 root) external onlyNodeOwner(node) {
        roots[node] = root;
        emit NodeRootUpdated(node, root);
    }

    function add(address node, address[] calldata actors) external onlyNodeOwner(node) {
        for (uint256 i; i < actors.length; i++) {
            whitelist[node][actors[i]] = true;
        }
        emit WhitelistAdded(node, actors);
    }

    function remove(address node, address[] calldata actors) external onlyNodeOwner(node) {
        for (uint256 i; i < actors.length; i++) {
            whitelist[node][actors[i]] = false;
        }
        emit WhitelistRemoved(node, actors);
    }

    modifier onlyWhitelisted(address node, address actor) {
        _isWhitelisted(node, actor);
        _;
    }

    function _isWhitelisted(address node, address actor) internal view {
        if (whitelist[node][actor]) return;
        bytes32[] memory proof = proofs[node][actor];
        if (proof.length == 0) revert ErrorsLib.NotWhitelisted();
        if (!MerkleProof.verify(proof, roots[node], _getLeaf(actor))) revert ErrorsLib.NotWhitelisted();
    }

    function _getLeaf(address actor) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(actor))));
    }

    function _processCallerData(address caller, bytes calldata data) internal virtual override {
        (bytes32[] memory proof) = abi.decode(data, (bytes32[]));
        proofs[msg.sender][caller] = proof;
        emit ProofUpdated(msg.sender, caller, proof);
    }
}
