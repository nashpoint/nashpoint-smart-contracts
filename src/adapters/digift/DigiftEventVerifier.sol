// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";

import {MerkleTrie} from "optimism/libraries/trie/MerkleTrie.sol";
import {RLPReader} from "src/libraries/rlp/RLPReader.sol";

/**
 * @title DigiftEventVerifier
 * @author ODND Studios
 * @notice Verifies settlement events from DigiFT protocol using Merkle proofs
 * @dev This contract allows nodes to verify and decode settlement events (redemptions and subscriptions)
 *      by providing cryptographic proofs of events that occurred on the DigiFT protocol.
 *      It prevents double-spending by tracking used log hashes and validates event authenticity
 *      through Merkle Patricia trie proofs against block headers.
 */
contract DigiftEventVerifier is EventVerifierBase {
    // ============ Constants ============

    /// @notice Event signature for SettleSubscriber from DigiFT protocol
    bytes32 public constant SETTLE_SUBSCRIBER_TOPIC =
        keccak256("SettleSubscriber(address,address,address[],uint256[],address[],uint256[],uint256[])");

    /// @notice Event signature for SettleRedemption from DigiFT protocol
    bytes32 public constant SETTLE_REDEMPTION_TOPIC =
        keccak256("SettleRedemption(address,address,address[],uint256[],address[],uint256[],uint256[])");

    // ============ Events ============

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

    // ============ Structs ============

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
     * @param topics Array of log topics
     */
    struct Vars {
        bytes32 blockHash;
        bytes32 eventSignature;
        bytes32 receiptsRoot;
        bytes32 logHash;
        uint256 investorIndex;
        RLPReader.RLPItem[] logs;
        RLPReader.RLPItem[] log;
        RLPReader.RLPItem[] topics;
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
    constructor(address registry_) EventVerifierBase(registry_) {}

    // ============ External Functions ============

    /**
     * @notice Verifies a settlement event from DigiFT protocol using Merkle proofs
     * @dev This function allows nodes to claim settlement events by providing cryptographic
     *      proofs that the event occurred on the DigiFT protocol. It validates the event
     *      against the block header and prevents double-spending by tracking used log hashes.
     * @param fargs Offchain verification parameters including block data, proofs, and event details
     * @param nargs Onchain verification parameters including emitting address, event type and tokens
     * @return stTokenAmount The amount of security tokens in the settlement
     * @return currencyTokenAmount The amount of currency tokens in the settlement
     * @dev Only callable by whitelisted DigiftAdapter
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

        vars.investorIndex = abi.decode(fargs.customData, (uint256));

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
        require(address(bytes20(RLPReader.readBytes(vars.log[0]))) == nargs.emittingAddress, NoEvent());

        // Extract and validate the log topics (indexed parameters)
        vars.topics = RLPReader.readList(vars.log[1]);
        require(bytes32(RLPReader.readBytes(vars.topics[0])) == vars.eventSignature, NoEvent());

        // Decode the log data (non-indexed parameters)
        // Structure: (stToken, investorList, quantityList, currencyTokenList, amountList, feeList)
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
        require(stToken == nargs.securityToken, NoEvent());
        // Verify that investor index is correct
        require(investorList[vars.investorIndex] == msg.sender, NoEvent());
        // Verify the currency token matches for this investor
        require(currencyTokenList[vars.investorIndex] == nargs.currencyToken, NoEvent());

        // Generate unique log hash to prevent double-spending
        vars.logHash = _hashLog(vars.blockHash, stToken, nargs.currencyToken, fargs.txIndex, fargs.logIndex);
        require(usedLogs[vars.logHash] == false, LogAlreadyUsed());
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

    // ============ Internal Functions ============

    /**
     * @notice Generates a unique hash for a log entry to prevent double-spending
     * @dev Creates a deterministic hash from block hash, receipts root, transaction index path, and log index
     * @param blockHash The hash of the block containing the log
     * @param stToken The address of security token
     * @param currencyToken The address of currency token
     * @param txIndexPath The transaction index path in the Merkle trie
     * @param logIndex The index of the log within the transaction receipt
     * @return A unique hash identifying this specific log entry
     */
    function _hashLog(
        bytes32 blockHash,
        address stToken,
        address currencyToken,
        bytes memory txIndexPath,
        uint256 logIndex
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(blockHash, stToken, currencyToken, txIndexPath, logIndex));
    }
}
