// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {INode} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {IMerklDistributor} from "src/interfaces/IMerklDistributor.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract MerklRouter is ReentrancyGuard {
    /* IMMUTABLES */

    /// @notice The address of the Merkl Distributor
    address public constant distributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    /// @notice The address of the NodeRegistry
    INodeRegistry public immutable registry;

    /* EVENTS */
    /// @notice Emitted when tokens are claimed from Merkl
    event MerklRewardsClaimed(address indexed node, address[] tokens, uint256[] amounts);

    /* CONSTRUCTOR */
    constructor(address registry_) {
        if (registry_ == address(0)) revert ErrorsLib.ZeroAddress();
        registry = INodeRegistry(registry_);
    }

    /* MODIFIERS */
    /// @dev Reverts if the caller is not a rebalancer for the node
    modifier onlyNodeRebalancer(address node) {
        if (!registry.isNode(node)) revert ErrorsLib.InvalidNode();
        if (!INode(node).isRebalancer(msg.sender)) revert ErrorsLib.NotRebalancer();
        _;
    }

    /* FUNCTIONS */
    /// @notice Claims rewards from Merkl
    /// @param tokens ERC20 token addresses
    /// @param amounts Amount of tokens that will be claimed
    /// @param proofs Array of hashes bridging from a leaf `(hash of user | token | amount)` to the Merkle root
    function claim(address node, address[] calldata tokens, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external
        nonReentrant
        onlyNodeRebalancer(node)
    {
        address[] memory users = new address[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            users[i] = node;
        }
        INode(node).execute(distributor, abi.encodeCall(IMerklDistributor.claim, (users, tokens, amounts, proofs)));

        emit MerklRewardsClaimed(node, tokens, amounts);
    }
}
