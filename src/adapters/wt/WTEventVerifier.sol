// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";

import {MerkleTrie} from "optimism/libraries/trie/MerkleTrie.sol";
import {RLPReader} from "src/libraries/rlp/RLPReader.sol";

/**
 * @title WTEventVerifier
 * @author ODND Studios
 */
contract WTEventVerifier is EventVerifierBase {
    // ============ Constants ============
    /// @notice Event signature for Transfer event
    bytes32 public constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");

    // ============ Events ============

    /**
     * @notice Emitted when a settlement event is successfully verified
     */
    event Verified(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 blockHash,
        bytes32 logHash
    );

    // ============ Structs ============

    /**
     * @notice Onchain parameters for verifying a settlement event
     */
    struct OnchainArgs {
        address token;
        address sender;
    }

    /**
     * @notice Internal variables used during event verification
     * @param blockHash The hash of the block containing the event
     * @param receiptsRoot The receipts root from the block header
     * @param logHash Unique hash of the log entry to prevent double-spending
     * @param logs Array of all logs in the transaction receipt
     * @param log Current log being processed
     * @param topics Array of log topics
     */
    struct Vars {
        bytes32 blockHash;
        bytes32 receiptsRoot;
        bytes32 logHash;
        RLPReader.RLPItem[] logs;
        RLPReader.RLPItem[] log;
        RLPReader.RLPItem[] topics;
        address from;
        address to;
    }

    // ============ Constructor ============

    /**
     * @notice Initializes the WTEventVerifier contract
     * @param registry_ The address of the registry contract for access control
     */
    constructor(address registry_) EventVerifierBase(registry_) {}

    // ============ External Functions ============

    function verifySettlementEvent(OffchainArgs calldata fargs, OnchainArgs calldata nargs)
        external
        returns (uint256)
    {
        require(whitelist[msg.sender], NotWhitelisted());

        Vars memory vars;

        // Calculate the block hash from the provided header RLP
        vars.blockHash = keccak256(fargs.headerRlp);

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

        vars.log = RLPReader.readList(vars.logs[fargs.logIndex]);

        // Check if this log was emitted by the expected contract address
        require(address(bytes20(RLPReader.readBytes(vars.log[0]))) == nargs.token, NoEvent());

        // Extract and validate the log topics (indexed parameters)
        vars.topics = RLPReader.readList(vars.log[1]);
        require(bytes32(RLPReader.readBytes(vars.topics[0])) == TRANSFER_TOPIC, NoEvent());
        // decode indexed params
        vars.from = address(uint160(uint256(bytes32(RLPReader.readBytes(vars.topics[1])))));
        vars.to = address(uint160(uint256(bytes32(RLPReader.readBytes(vars.topics[2])))));

        // from should match whom adapter expects to be a sender - might be address(0) in case of mint
        require(vars.from == nargs.sender, NoEvent());
        // to should be actual adapter contract
        require(vars.to == msg.sender, NoEvent());

        // Decode the log data (non-indexed parameters)
        (uint256 amount) = abi.decode(RLPReader.readBytes(vars.log[2]), (uint256));

        // Generate unique log hash to prevent double-spending
        vars.logHash = _hashLog(vars.blockHash, nargs.token, fargs.txIndex, fargs.logIndex);
        require(usedLogs[vars.logHash] == false, LogAlreadyUsed());
        usedLogs[vars.logHash] = true;

        // Emit verification event with settlement details
        emit Verified(nargs.token, vars.from, vars.to, amount, vars.blockHash, vars.logHash);

        return amount;
    }

    // ============ Internal Functions ============

    /**
     * @notice Generates a unique hash for a log entry to prevent double-spending
     * @param blockHash The hash of the block containing the log
     * @param token The address of token
     * @param txIndexPath The transaction index path in the Merkle trie
     * @param logIndex The index of the log within the transaction receipt
     * @return A unique hash identifying this specific log entry
     */
    function _hashLog(bytes32 blockHash, address token, bytes memory txIndexPath, uint256 logIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(blockHash, token, txIndexPath, logIndex));
    }
}
