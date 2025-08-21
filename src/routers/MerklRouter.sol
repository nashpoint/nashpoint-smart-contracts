// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {INode} from "src/interfaces/INode.sol";
import {IMerklDistributor} from "src/interfaces/external/IMerklDistributor.sol";
import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract MerklRouter is ReentrancyGuard, RegistryAccessControl {
    /* IMMUTABLES */
    /// @notice The address of the Merkl Distributor
    address public constant distributor = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    /* EVENTS */
    /// @notice Emitted when tokens are claimed from Merkl
    event MerklRewardsClaimed(address indexed node, address[] tokens, uint256[] amounts);

    /* CONSTRUCTOR */
    constructor(address registry_) RegistryAccessControl(registry_) {}

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
