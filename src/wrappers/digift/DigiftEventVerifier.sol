// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";

import {MerkleTrie} from "optimism/libraries/trie/MerkleTrie.sol";
import {RLPReader} from "optimism/libraries/rlp/RLPReader.sol";
import {Bytes} from "optimism/libraries/Bytes.sol";

/**
 * @title DigiftEventVerifier
 * @author ODND Studios
 * @notice Verifies settlement events from DigiFT protocol using Merkle proofs
 * @dev This contract allows nodes to verify and decode settlement events (redemptions and subscriptions)
 *      by providing cryptographic proofs of events that occurred on the DigiFT protocol.
 *      It prevents double-spending by tracking used log hashes and validates event authenticity
 *      through Merkle Patricia trie proofs against block headers.
 */
contract DigiftEventVerifier is RegistryAccessControl {
    // ============ Constants ============

    /// @notice Event signature for SettleSubscriber from DigiFT protocol
    bytes32 public constant SETTLE_SUBSCRIBER_TOPIC =
        keccak256("SettleSubscriber(address,address,address[],uint256[],address[],uint256[],uint256[])");

    /// @notice Event signature for SettleRedemption from DigiFT protocol
    bytes32 public constant SETTLE_REDEMPTION_TOPIC =
        keccak256("SettleRedemption(address,address,address[],uint256[],address[],uint256[],uint256[])");

    // ============ State Variables ============

    /// @notice Tracks DigiftWrapper addresses authorised to call `verifySettlementEvent`
    mapping(address => bool) whitelist;

    /// @notice Mapping to track used log hashes to prevent double-spending
    mapping(bytes32 => bool) public usedLogs;

    /// @notice Mapping to store block hashes for historical block verification
    mapping(uint256 => bytes32) public blockHashes;

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

    /// @notice Thrown when an unapproved DigiftWrapper calls a whitelisted function
    error NotWhitelisted();

    // ============ Events ============

    /// @notice Emitted when a DigiftWrapper address gains or loses verification rights
    /// @param digiftWrapper DigiftWrapper contract whose status changed
    /// @param status Whether the wrapper is approved (`true`) or revoked (`false`)
    event WhitelistChange(address indexed digiftWrapper, bool status);

    /**
     * @notice Emitted when a settlement event is successfully verified
     * @param investor The node address which claimed the settlement
     * @param stToken The security token address from the settlement event
     * @param currencyToken The currency token address from the settlement event
     * @param stTokenAmount The amount of security tokens in the settlement
     * @param currencyTokenAmount The amount of currency tokens in the settlement
     * @param blockHash The hash of the block containing the original event
     * @param logHash The unique hash of the log entry to prevent double-spending
     */
    event Verified(
        address indexed investor,
        address indexed stToken,
        address indexed currencyToken,
        uint256 stTokenAmount,
        uint256 currencyTokenAmount,
        bytes32 blockHash,
        bytes32 logHash
    );

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
     * @param proof Merkle proof for the transaction receipt
     */
    struct OffchainArgs {
        uint256 blockNumber;
        bytes headerRlp;
        bytes txIndex;
        bytes[] proof;
    }

    /**
     * @notice Onchain parameters for verifying a settlement event
     * @param eventType Subscribe or Redeem
     * @param emittingAddress The contract address that emitted the event
     * @param securityToken The security token address to match in the event
     * @param currencyToken The currency token address to match in the event
     */
    struct OnchainArgs {
        EventType eventType;
        address emittingAddress;
        address securityToken;
        address currencyToken;
    }

    /**
     * @notice Internal variables used during event verification
     * @param blockHash The hash of the block containing the event
     * @param eventSignature The event signature to match (SettleSubscriber or SettleRedemption)
     * @param receiptsRoot The receipts root from the block header
     * @param logHash Unique hash of the log entry to prevent double-spending
     * @param investorIndex Index of the investor in the event data arrays
     * @param logs Array of all logs in the transaction receipt
     * @param log Current log being processed
     */
    struct Vars {
        bytes32 blockHash;
        bytes32 eventSignature;
        bytes32 receiptsRoot;
        bytes32 logHash;
        uint256 investorIndex;
        RLPReader.RLPItem[] logs;
        RLPReader.RLPItem[] log;
    }

    enum EventType {
        SUBSCRIBE,
        REDEEM
    }

    // ============ Constructor ============

    /**
     * @notice Initializes the DigiftEventVerifier contract
     * @param registry_ The address of the registry contract for access control
     */
    constructor(address registry_) RegistryAccessControl(registry_) {}

    // ============ External Functions ============

    /**
     * @notice Adds or removes a Digift wrapper from the verification whitelist
     * @param digiftWrapper Digift wrapper contract to update
     * @param status Pass `true` to grant access or `false` to revoke it
     * @dev Restricted to the registry owner
     */
    function setWhitelist(address digiftWrapper, bool status) external onlyRegistryOwner {
        whitelist[digiftWrapper] = status;
        emit WhitelistChange(digiftWrapper, status);
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

    /**
     * @notice Verifies a settlement event from DigiFT protocol using Merkle proofs
     * @dev This function allows nodes to claim settlement events by providing cryptographic
     *      proofs that the event occurred on the DigiFT protocol. It validates the event
     *      against the block header and prevents double-spending by tracking used log hashes.
     * @param fargs Offchain verification parameters including block data, proofs, and event details
     * @param nargs Onchain verification parameters including emitting address, event type and tokens
     * @return stTokenAmount The amount of security tokens in the settlement
     * @return currencyTokenAmount The amount of currency tokens in the settlement
     * @dev Only callable by whitelisted DigiftWrapper
     * @dev Reverts if the event signature is invalid, block header doesn't match,
     *      or if the log has already been used (double-spending protection)
     */
    function verifySettlementEvent(OffchainArgs calldata fargs, OnchainArgs calldata nargs)
        external
        returns (uint256, uint256)
    {
        require(whitelist[msg.sender], NotWhitelisted());

        Vars memory vars;

        // Calculate the block hash from the provided header RLP
        vars.blockHash = keccak256(fargs.headerRlp);
        vars.eventSignature = nargs.eventType == EventType.SUBSCRIBE ? SETTLE_SUBSCRIBER_TOPIC : SETTLE_REDEMPTION_TOPIC;

        // Verify the block hash matches the stored or current block hash
        if (_getBlockHash(fargs.blockNumber) != vars.blockHash) revert BadHeader();

        // Extract the receipts root from the block header (index 5 in RLP-encoded header)
        vars.receiptsRoot = bytes32(RLPReader.readBytes(RLPReader.readList(fargs.headerRlp)[5]));

        // Get the transaction receipt using Merkle proof and extract logs
        // The receipt structure is: [status, cumulativeGasUsed, logsBloom, logs]
        // We need index 3 which contains the logs array
        vars.logs = RLPReader.readList(
            RLPReader.readList(_stripTypedPrefix(MerkleTrie.get(fargs.txIndex, fargs.proof, vars.receiptsRoot)))[3]
        );

        // Iterate through all logs in the transaction receipt
        for (uint256 i = 0; i < vars.logs.length; i++) {
            vars.log = RLPReader.readList(vars.logs[i]);

            // Check if this log was emitted by the expected contract address
            if (address(bytes20(RLPReader.readBytes(vars.log[0]))) != nargs.emittingAddress) continue;

            // Extract and validate the log topics (indexed parameters)
            RLPReader.RLPItem[] memory topics = RLPReader.readList(vars.log[1]);
            if (bytes32(RLPReader.readBytes(topics[0])) != vars.eventSignature) continue;

            // Decode the log data (non-indexed parameters)
            // Structure: (stToken, investorList, quantityList, currencyTokenList, amountList, timestamp)
            (
                address stToken,
                address[] memory investorList,
                uint256[] memory quantityList,
                address[] memory currencyTokenList,
                uint256[] memory amountList,
            ) = abi.decode(
                RLPReader.readBytes(vars.log[2]), (address, address[], uint256[], address[], uint256[], uint256[])
            );

            // Verify the security token matches
            if (stToken != nargs.securityToken) continue;

            // Find the caller's index in the investor list
            vars.investorIndex = type(uint256).max;
            for (uint256 j; j < investorList.length; j++) {
                if (investorList[j] == msg.sender) {
                    vars.investorIndex = j;
                    break;
                }
            }
            if (vars.investorIndex == type(uint256).max) continue; // Caller not in investor list

            // Verify the currency token matches for this investor
            if (currencyTokenList[vars.investorIndex] != nargs.currencyToken) continue;

            // Generate unique log hash to prevent double-spending
            vars.logHash = _hashLog(vars.blockHash, vars.receiptsRoot, fargs.txIndex, i);
            if (usedLogs[vars.logHash]) revert LogAlreadyUsed();
            usedLogs[vars.logHash] = true;

            // Emit verification event with settlement details
            emit Verified(
                msg.sender,
                nargs.securityToken,
                nargs.currencyToken,
                quantityList[vars.investorIndex],
                amountList[vars.investorIndex],
                vars.blockHash,
                vars.logHash
            );

            // Return the settlement amounts for this investor
            return (quantityList[vars.investorIndex], amountList[vars.investorIndex]);
        }

        // No matching event found
        revert NoEvent();
    }

    // ============ Internal Functions ============

    /**
     * @notice Retrieves a block hash, falling back to stored hashes for historical blocks
     * @dev First tries to get the block hash using blockhash() opcode, then falls back
     *      to the stored blockHashes mapping for blocks older than 256 blocks
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
     * @notice Generates a unique hash for a log entry to prevent double-spending
     * @dev Creates a deterministic hash from block hash, receipts root, transaction index path, and log index
     * @param blockHash The hash of the block containing the log
     * @param receiptsRoot The receipts root from the block header
     * @param txIndexPath The transaction index path in the Merkle trie
     * @param logIndex The index of the log within the transaction receipt
     * @return A unique hash identifying this specific log entry
     */
    function _hashLog(bytes32 blockHash, bytes32 receiptsRoot, bytes memory txIndexPath, uint256 logIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(blockHash, receiptsRoot, txIndexPath, logIndex));
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
