// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MerkleTrie} from "optimism/libraries/trie/MerkleTrie.sol";
import {RLPReader} from "optimism/libraries/rlp/RLPReader.sol";
import {Bytes} from "optimism/libraries/Bytes.sol";

library MPTLib {
    bytes32 constant SETTLE_SUBSCRIBER_TOPIC =
        keccak256("SettleSubscriber(address,address,address[],uint256[],address[],uint256[],uint256[])");
    bytes32 constant SETTLE_REDEMPTION_TOPIC =
        keccak256("SettleRedemption(address,address,address[],uint256[],address[],uint256[],uint256[])");

    struct Args {
        uint256 blockNumber;
        bytes headerRlp;
        bytes txIndex;
        bytes[] proof;
        bytes32 eventSignature;
        address emittingAddress;
        address investor;
        address securityToken;
        address currencyToken;
    }

    struct Vars {
        bytes32 blockHash;
        bytes32 receiptsRoot;
        bytes32 logHash;
        uint256 stTokenAmount;
        uint256 assetAmount;
        uint256 investorIndex;
        RLPReader.RLPItem[] logs;
        RLPReader.RLPItem[] log;
    }

    function verifySettlementEvent(Args memory args, mapping(bytes32 => bool) storage usedLogs)
        internal
        returns (uint256, uint256)
    {
        Vars memory vars;
        vars.blockHash = keccak256(args.headerRlp);
        require(blockhash(args.blockNumber) != 0, "missed window");
        require(blockhash(args.blockNumber) == vars.blockHash, "bad header");
        require(
            args.eventSignature == SETTLE_REDEMPTION_TOPIC || args.eventSignature == SETTLE_SUBSCRIBER_TOPIC,
            "Incorrect eventSignature"
        );

        vars.receiptsRoot = bytes32(RLPReader.readBytes(RLPReader.readList(args.headerRlp)[5]));

        vars.logs = RLPReader.readList(
            RLPReader.readList(_stripTypedPrefix(MerkleTrie.get(args.txIndex, args.proof, vars.receiptsRoot)))[3]
        );

        for (uint256 i = 0; i < vars.logs.length; i++) {
            vars.log = RLPReader.readList(vars.logs[i]);
            if (address(bytes20(RLPReader.readBytes(vars.log[0]))) != args.emittingAddress) continue;

            RLPReader.RLPItem[] memory topics = RLPReader.readList(vars.log[1]);
            if (topics.length != 2) continue;
            if (bytes32(RLPReader.readBytes(topics[0])) != args.eventSignature) continue;
            (
                address stToken,
                address[] memory investorList,
                uint256[] memory quantityList,
                address[] memory currencyTokenList,
                uint256[] memory amountList,
            ) = abi.decode(
                RLPReader.readBytes(vars.log[2]), (address, address[], uint256[], address[], uint256[], uint256[])
            );

            if (stToken != args.securityToken) continue;

            vars.investorIndex = type(uint256).max;
            for (uint256 i; i < investorList.length; i++) {
                if (investorList[i] == args.investor) {
                    vars.investorIndex = i;
                    break;
                }
            }
            if (vars.investorIndex == type(uint256).max) continue;
            if (currencyTokenList[vars.investorIndex] != args.currencyToken) continue;

            vars.logHash = _hashLog(vars.blockHash, vars.receiptsRoot, args.txIndex, i);
            require(!usedLogs[vars.logHash], "log already used");
            usedLogs[vars.logHash] = true;

            vars.stTokenAmount += quantityList[vars.investorIndex];
            vars.assetAmount += amountList[vars.investorIndex];
        }
        return (vars.stTokenAmount, vars.assetAmount);
    }

    function _hashLog(bytes32 blockHash, bytes32 receiptsRoot, bytes memory txIndexPath, uint256 logIndex)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(blockHash, receiptsRoot, txIndexPath, logIndex));
    }

    function _stripTypedPrefix(bytes memory b) private pure returns (bytes memory out) {
        uint8 t = uint8(b[0]);
        // EIP-2718 typed receipts: 0x01 (EIP-2930), 0x02 (EIP-1559), 0x03 (EIP-4844), etc.
        if (t == 0x01 || t == 0x02 || t == 0x03) {
            out = Bytes.slice(b, 1);
        } else {
            out = b;
        }
    }
}
