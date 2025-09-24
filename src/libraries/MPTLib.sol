// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {MerkleTrie} from "optimism/libraries/trie/MerkleTrie.sol";

import {RLPReader} from "optimism/libraries/rlp/RLPReader.sol";

library MPTLib {
    bytes32 constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");
    address constant RWAFI_ADDRESS = 0x6ca200319A0D4127a7a473d6891B86f34e312F42;
    address constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function verifyTransferEvent(
        uint256 blockNumber,
        bytes memory headerRlp,
        bytes memory rlpTxIndex,
        bytes[] memory proofNodes
    ) internal {
        require(blockhash(blockNumber) != 0, "missed window");
        require(blockhash(blockNumber) == keccak256(headerRlp), "bad header");

        RLPReader.RLPItem[] memory header = RLPReader.readList(headerRlp);
        bytes32 receiptsRoot = bytes32(RLPReader.readBytes(header[5]));

        bytes memory receiptRlp = MerkleTrie.get(rlpTxIndex, proofNodes, receiptsRoot);

        RLPReader.RLPItem[] memory receipt = RLPReader.readList(receiptRlp);
        RLPReader.RLPItem[] memory logs = RLPReader.readList(receipt[3]);

        for (uint256 i = 0; i < logs.length; i++) {
            RLPReader.RLPItem[] memory e = RLPReader.readList(logs[i]);
            address a = address(uint160(bytes20(RLPReader.readBytes(e[0]))));
            if (a != USDC_ADDRESS) continue;

            RLPReader.RLPItem[] memory topics = RLPReader.readList(e[1]);
            if (topics.length == 0) continue;

            if (bytes32(RLPReader.readBytes(topics[0])) != TRANSFER_TOPIC) continue;

            address to = address(uint160(uint256(bytes32(RLPReader.readBytes(topics[2])))));
            if (to != RWAFI_ADDRESS) continue;

            address from = address(uint160(uint256(bytes32(RLPReader.readBytes(topics[1])))));
            (uint256 amount) = abi.decode(RLPReader.readBytes(e[2]), (uint256));

            console.log(from);
            console.log(to);
            console.log(amount);
        }
    }
}
