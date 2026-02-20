// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RLP} from "@openzeppelin/contracts/utils/RLP.sol";

import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";

contract TransferEventVerifierTest is Test {
    function test_verifyEvent_receiptWithMoreThan32Logs() external {
        vm.roll(1000);

        address adapter = makeAddr("adapter");
        address token = makeAddr("token");
        address sender = makeAddr("sender");

        TransferEventVerifier verifier = new TransferEventVerifier(address(this));
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));
        verifier.setWhitelist(adapter, true);

        (EventVerifierBase.OffchainArgs memory fargs, bytes32 blockHash, uint256 expectedAmount) =
            _buildProofArgs(adapter, token, sender);
        verifier.setBlockHash(fargs.blockNumber, blockHash);

        bytes32 logHash = keccak256(abi.encode(blockHash, token, fargs.txIndex, fargs.logIndex));
        assertFalse(verifier.usedLogs(logHash));

        vm.prank(adapter);
        uint256 amount = verifier.verifyEvent(fargs, TransferEventVerifier.OnchainArgs(token, sender));

        assertEq(amount, expectedAmount);
        assertTrue(verifier.usedLogs(logHash));
    }

    function _buildProofArgs(address adapter, address token, address sender)
        internal
        pure
        returns (EventVerifierBase.OffchainArgs memory fargs, bytes32 blockHash, uint256 expectedAmount)
    {
        uint256 totalLogs = 40;
        uint256 targetLogIndex = 35;
        expectedAmount = 777_777;
        bytes memory txIndex = hex"05";

        bytes[] memory logs = _buildLogs(totalLogs, targetLogIndex, token, sender, adapter, expectedAmount);
        bytes memory receiptRlp = _buildReceipt(logs);
        (bytes32 receiptsRoot, bytes[] memory proof) = _buildSingleLeafTrieProof(txIndex, receiptRlp);
        bytes memory headerRlp = _buildHeaderWithReceiptsRoot(receiptsRoot);

        blockHash = keccak256(headerRlp);
        fargs = EventVerifierBase.OffchainArgs({
            blockNumber: 111,
            headerRlp: headerRlp,
            txIndex: txIndex,
            logIndex: targetLogIndex,
            proof: proof,
            customData: ""
        });
    }

    function _buildLogs(
        uint256 totalLogs,
        uint256 targetLogIndex,
        address token,
        address sender,
        address adapter,
        uint256 expectedAmount
    ) internal pure returns (bytes[] memory logs) {
        logs = new bytes[](totalLogs);
        for (uint256 i = 0; i < totalLogs; ++i) {
            address logToken = i == targetLogIndex ? token : address(uint160(10_000 + i));
            address logFrom = i == targetLogIndex ? sender : address(uint160(20_000 + i));
            address logTo = i == targetLogIndex ? adapter : address(uint160(30_000 + i));
            uint256 logAmount = i == targetLogIndex ? expectedAmount : i + 1;
            logs[i] = _buildTransferLog(logToken, logFrom, logTo, logAmount);
        }
    }

    function _buildTransferLog(address token, address from, address to, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        bytes[] memory topics = new bytes[](3);
        topics[0] = RLP.encode(abi.encodePacked(keccak256("Transfer(address,address,uint256)")));
        topics[1] = RLP.encode(abi.encodePacked(bytes32(uint256(uint160(from)))));
        topics[2] = RLP.encode(abi.encodePacked(bytes32(uint256(uint160(to)))));

        bytes[] memory fields = new bytes[](3);
        fields[0] = RLP.encode(abi.encodePacked(token));
        fields[1] = RLP.encode(topics);
        fields[2] = RLP.encode(abi.encode(amount));

        return RLP.encode(fields);
    }

    function _buildReceipt(bytes[] memory logs) internal pure returns (bytes memory) {
        bytes[] memory receipt = new bytes[](4);
        receipt[0] = RLP.encode(uint256(1)); // status
        receipt[1] = RLP.encode(uint256(21_000)); // cumulative gas used
        receipt[2] = RLP.encode(new bytes(256)); // bloom
        receipt[3] = RLP.encode(logs); // logs
        return RLP.encode(receipt);
    }

    function _buildSingleLeafTrieProof(bytes memory key, bytes memory value)
        internal
        pure
        returns (bytes32 root, bytes[] memory proof)
    {
        // Leaf path for an even-length nibble key: 0x20 || key
        bytes memory encodedPath = bytes.concat(hex"20", key);

        bytes[] memory leaf = new bytes[](2);
        leaf[0] = RLP.encode(encodedPath);
        leaf[1] = RLP.encode(value);

        bytes memory leafNode = RLP.encode(leaf);
        root = keccak256(leafNode);
        proof = new bytes[](1);
        proof[0] = leafNode;
    }

    function _buildHeaderWithReceiptsRoot(bytes32 receiptsRoot) internal pure returns (bytes memory) {
        bytes[] memory header = new bytes[](6);
        header[0] = RLP.encode(bytes("parentHash"));
        header[1] = RLP.encode(bytes("ommersHash"));
        header[2] = RLP.encode(bytes("beneficiary"));
        header[3] = RLP.encode(bytes("stateRoot"));
        header[4] = RLP.encode(bytes("txRoot"));
        header[5] = RLP.encode(abi.encodePacked(receiptsRoot));
        return RLP.encode(header);
    }
}
