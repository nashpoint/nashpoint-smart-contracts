// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";

import {Bytes} from "@openzeppelin/contracts/utils/Bytes.sol";

/**
 * @title EventVerifierBase
 * @author ODND Studios
 */
abstract contract EventVerifierBase is RegistryAccessControl {
    /// @notice Tracks Adapter addresses authorized to verify events
    mapping(address node => bool status) whitelist;

    /// @notice Mapping to track used log hashes to prevent double-spending
    mapping(bytes32 logHash => bool used) public usedLogs;

    /// @notice Mapping to store block hashes for historical block verification
    mapping(uint256 blockNumber => bytes32 blockHash) public blockHashes;

    // ============ Errors ============

    /// @notice Thrown when block hash verification fails
    error BadHeader();

    /// @notice Thrown when log has already been used (double-spending)
    error LogAlreadyUsed();

    /// @notice Thrown when block hash is not available
    error MissedWindow();

    /// @notice Thrown when no matching event is found
    error NoEvent();

    /// @notice Thrown when input bytes are empty
    error ZeroBytes();

    /// @notice Thrown when an unapproved Adapter calls a whitelisted function
    error NotWhitelisted();

    // ============ Events ============

    /// @notice Emitted when a Adapter address gains or loses verification rights
    /// @param adapter Adapter contract whose status changed
    /// @param status Whether the adapter is approved (`true`) or revoked (`false`)
    event WhitelistChange(address indexed adapter, bool status);

    /**
     * @notice Emitted when a block hash is set for historical block verification
     * @param blockNumber The block number for which the hash was set
     * @param blockHash The hash of the block that was stored
     */
    event BlockHashSet(uint256 indexed blockNumber, bytes32 blockHash);

    // ============ Structs ============

    /**
     * @notice Offchain parameters for verifying a settlement event
     * @param blockNumber The block number containing the settlement event
     * @param headerRlp RLP-encoded block header for verification
     * @param txIndex Transaction index path in the Merkle trie
     * @param logIndex The index of the log
     * @param proof Merkle proof for the transaction receipt
     * @param customData Abi encoded custom data
     */
    struct OffchainArgs {
        uint256 blockNumber;
        bytes headerRlp;
        bytes txIndex;
        uint256 logIndex;
        bytes[] proof;
        bytes customData;
    }

    // ============ Constructor ============

    /**
     * @notice Initializes the EventVerifier contract
     * @param registry_ The address of the registry contract for access control
     */
    constructor(address registry_) RegistryAccessControl(registry_) {}

    // ============ External Functions ============

    /**
     * @notice Adds or removes an adapter from the verification whitelist
     * @param adapter Adapter contract to update
     * @param status Pass `true` to grant access or `false` to revoke it
     * @dev Restricted to the registry owner
     */
    function setWhitelist(address adapter, bool status) external onlyRegistryOwner {
        whitelist[adapter] = status;
        emit WhitelistChange(adapter, status);
    }

    /**
     * @notice Sets a block hash for historical block verification
     * @dev This function allows setting block hashes for blocks that are no longer
     *      available through the blockhash() opcode (older than 256 blocks)
     * @param blockNumber The block number corresponding to the hash
     * @param blockHash The hash of the block to store
     * @dev Only callable by the registry owner
     */
    function setBlockHash(uint256 blockNumber, bytes32 blockHash) external onlyRegistryOwner {
        blockHashes[blockNumber] = blockHash;
        emit BlockHashSet(blockNumber, blockHash);
    }

    // ============ Internal Functions ============

    /**
     * @notice Retrieves a block hash, falling back to stored hashes for historical blocks
     * @dev Tries `Blockhash.blockHash(blockNumber)` first (BLOCKHASH for <=256 blocks,
     *      or EIP-2935 history storage up to ~8191 blocks when available), then falls
     *      back to the `blockHashes` mapping if the onchain lookup returns zero.
     * @param blockNumber The block number to get the hash for
     * @return blockHash The hash of the specified block
     * @dev Reverts if the block hash is not available and not stored
     */
    function _getBlockHash(uint256 blockNumber) internal returns (bytes32) {
        bytes32 blockHash = blockhash(blockNumber);
        if (blockHash == 0) {
            blockHash = blockHashes[blockNumber];
        }
        if (blockHash == 0) revert MissedWindow();
        return blockHash;
    }

    /**
     * @notice Removes the typed transaction prefix from receipt data
     * @dev Handles EIP-2718 typed transactions by stripping the transaction type prefix
     * @param b The receipt data that may contain a typed transaction prefix
     * @return out The receipt data with the prefix removed (if present)
     * @dev Supports EIP-2930 (0x01), EIP-1559 (0x02), and EIP-4844 (0x03) transaction types
     */
    function _stripTypedPrefix(bytes memory b) internal pure returns (bytes memory out) {
        if (b.length == 0) revert ZeroBytes();
        uint8 t = uint8(b[0]);
        // EIP-2718 typed receipts: 0x01 (EIP-2930), 0x02 (EIP-1559), 0x03 (EIP-4844), etc.
        // TransactionType only goes up to 0x7f: https://eips.ethereum.org/EIPS/eip-2718#rationale
        if (t < 0x80) {
            out = Bytes.slice(b, 1);
        } else {
            out = b;
        }
    }
}
