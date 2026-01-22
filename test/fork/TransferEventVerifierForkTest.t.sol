// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";

contract TransferEventVerifierForkTest is Test {
    struct Vars {
        uint256 blockNumber;
        bytes header;
        bytes txIndex;
        bytes[] proof;
        bytes32 blockHash;
        address receiver;
        address token;
        address sender;
    }

    function _getArbitrumParams() internal pure returns (Vars memory vars) {
        vars.blockNumber = 424030086;
        vars.blockHash = 0x36542892adb7f1496c2ed68239c41bdca7e8e6a6f8ecd97ba2efc75da7bdbd8e;
        vars.receiver = 0x9bBb705ae096a2FD8eDc953fFb7C1b26b1024fF8;
        vars.token = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        vars.sender = 0x04c4B0e3c58a440Ec0C129A2705E7Be09bd85e31;

        // RLP-encoded block header containing the transaction
        vars.header =
            hex"f90224a052404e5e461844831b1555b7957c64e6ae75b81e73d9320a9189ecaab6498894a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794a4b000000000000000000073657175656e636572a0bdd0e2c0913b00f9c1abff00212d1903a615cdca17b8b1a599ac472095549d76a063d1523ea8301bce29485b82667e349a74d09663dc0d893418afbef655894f56a04d9864eb0fbf8a1300201208a9233f4df2bffaabb265616aa28a99bb891cb6b3b9010000002000000000000008000000000000000000100000000020000000000008000000000000c00002000000000002000008004001840000000000000004000000040000010042000000000008000000000000004404000000000000000000000000000000000200000000280400000000200000000000004000020010000000000000000001000000000000080000000800000000201000000000000000000000000080000000000000000000000000002000000000400000000000000000000000002022000000000000000000000000000000000000000000400000100000040000000248000000000000000000200000000000000040000000000000800000018419462f8687040000000000008307ecc1846972145da0c21abc2bc40d972a87ce75ca9df358e0cee4f999fca6664fc85a779783e1be06a000000000000265d5000000000172a3c50000000000000033000000000000000088000000000022f14e8401312d00";

        // RLP-encoded transaction index within the block
        vars.txIndex = hex"05";

        // Merkle proof path for transaction verification
        vars.proof = new bytes[](3);
        vars.proof[0] = bytes(
            hex"f851a032f9478a24e66b37e07075af187a4e88a94a896d254d323494888e1919396dfa80808080808080a0b0f51de7909653fadedb604e425c3ae1245d466325c8296662c289fa327eeeea8080808080808080"
        );
        vars.proof[1] = bytes(
            hex"f8b180a0530973c25b639c1d5a526974db88edebb4b0800c71701b875ae65a24b2a4ab80a05fdf2ca929dcce21251ea35e6e1422681b679b56b6bc7d8646b16466a59d6004a0f951882b0f101be0cb1302c9c4e786055a44120788ad59b6775cda4b59499340a0d996cab4135735494f933fb71ab4df19f919f72889171c392adeb8c6e6d8b180a0e296906ed8e298bca1f8a0f55da9084fbbb0981c15bfe7377bf9c4b547463c328080808080808080808080"
        );
        vars.proof[2] = bytes(
            hex"f901af20b901ab02f901a7018307ecc1b9010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000008000000000000004000000000000000000000000000000000000000000000200000000000000000000000000000000010000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000002022000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000f89df89b94af88d065e77c8cc2239327c5edb3a432268e5831f863a0ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3efa000000000000000000000000004c4b0e3c58a440ec0c129a2705e7be09bd85e31a00000000000000000000000009bbb705ae096a2fd8edc953ffb7c1b26b1024ff8a00000000000000000000000000000000000000000000000000000000001698e1e"
        );
    }

    /**
     * Reference transaction: https://arbiscan.io/tx/0x4210190de2097358e1d36150b945556bedcf56f9ade880d1a9c7d665b5d4454f
     */
    function test_transfer_event_verification_arbitrum() external {
        Vars memory vars = _getArbitrumParams();
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), vars.blockNumber + 16);
        vm.roll(vars.blockNumber + 16);

        // Set the specific block hash for deterministic testing
        vm.setBlockhash(vars.blockNumber, vars.blockHash);

        // Mock the owner function to return this contract
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));

        // Deploy the verifier contract
        TransferEventVerifier verifier = new TransferEventVerifier(address(this));

        verifier.setWhitelist(vars.receiver, true);

        bytes32 logHash = keccak256(abi.encode(vars.blockHash, vars.token, vars.txIndex, 0));

        // Verify that the log has not been used before
        assertFalse(verifier.usedLogs(logHash));

        // Impersonate the receiver to simulate the correct msg.sender
        vm.startPrank(vars.receiver);
        // Verify the settlement event using Merkle proof
        uint256 amount = verifier.verifyEvent(
            EventVerifierBase.OffchainArgs(
                vars.blockNumber, // Block number containing the transaction
                vars.header, // RLP-encoded block header
                vars.txIndex, // Transaction index within the block
                0, // Log index
                vars.proof, // Merkle proof
                ""
            ),
            TransferEventVerifier.OnchainArgs(vars.token, vars.sender)
        );

        // Verify the correct token amounts were extracted from the event
        assertEq(amount, 23694878); // 23.694878 USDC

        // Verify the log is now marked as used
        assertTrue(verifier.usedLogs(logHash));
    }

    function test_verifyEvent_notWhitelisted() external {
        Vars memory vars = _getArbitrumParams();
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), vars.blockNumber + 16);
        vm.roll(vars.blockNumber + 16);
        vm.setBlockhash(vars.blockNumber, vars.blockHash);
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));

        TransferEventVerifier verifier = new TransferEventVerifier(address(this));

        vm.startPrank(vars.receiver);
        vm.expectRevert(EventVerifierBase.NotWhitelisted.selector);
        verifier.verifyEvent(
            EventVerifierBase.OffchainArgs(vars.blockNumber, vars.header, vars.txIndex, 0, vars.proof, ""),
            TransferEventVerifier.OnchainArgs(vars.token, vars.sender)
        );
        vm.stopPrank();
    }

    function test_verifyEvent_badHeader() external {
        Vars memory vars = _getArbitrumParams();
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), vars.blockNumber + 16);
        vm.roll(vars.blockNumber + 16);
        vm.setBlockhash(vars.blockNumber, keccak256("wrong hash"));
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));

        TransferEventVerifier verifier = new TransferEventVerifier(address(this));
        verifier.setWhitelist(vars.receiver, true);

        vm.startPrank(vars.receiver);
        vm.expectRevert(EventVerifierBase.BadHeader.selector);
        verifier.verifyEvent(
            EventVerifierBase.OffchainArgs(vars.blockNumber, vars.header, vars.txIndex, 0, vars.proof, ""),
            TransferEventVerifier.OnchainArgs(vars.token, vars.sender)
        );
    }

    function test_verifyEvent_missedWindow() external {
        Vars memory vars = _getArbitrumParams();
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), vars.blockNumber + 16);
        vm.roll(vars.blockNumber + 300); // move far enough ahead to miss the blockhash window
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));

        TransferEventVerifier verifier = new TransferEventVerifier(address(this));
        verifier.setWhitelist(vars.receiver, true);

        vm.startPrank(vars.receiver);
        vm.expectRevert(EventVerifierBase.MissedWindow.selector);
        verifier.verifyEvent(
            EventVerifierBase.OffchainArgs(vars.blockNumber, vars.header, vars.txIndex, 0, vars.proof, ""),
            TransferEventVerifier.OnchainArgs(vars.token, vars.sender)
        );
    }

    function test_verifyEvent_noEvent_variants() external {
        Vars memory vars = _getArbitrumParams();
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), vars.blockNumber + 16);
        vm.roll(vars.blockNumber + 16);
        vm.setBlockhash(vars.blockNumber, vars.blockHash);
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));

        TransferEventVerifier verifier = new TransferEventVerifier(address(this));
        verifier.setWhitelist(vars.receiver, true);

        EventVerifierBase.OffchainArgs memory fargs =
            EventVerifierBase.OffchainArgs(vars.blockNumber, vars.header, vars.txIndex, 0, vars.proof, "");

        vm.startPrank(vars.receiver);
        vm.expectRevert(EventVerifierBase.NoEvent.selector);
        verifier.verifyEvent(fargs, TransferEventVerifier.OnchainArgs(address(0xdead), vars.sender));

        vm.expectRevert(EventVerifierBase.NoEvent.selector);
        verifier.verifyEvent(fargs, TransferEventVerifier.OnchainArgs(vars.token, address(0)));
        vm.stopPrank();

        address wrongReceiver = address(0x1234);
        verifier.setWhitelist(wrongReceiver, true);
        vm.startPrank(wrongReceiver);
        vm.expectRevert(EventVerifierBase.NoEvent.selector);
        verifier.verifyEvent(fargs, TransferEventVerifier.OnchainArgs(vars.token, vars.sender));
        vm.stopPrank();
    }

    function test_verifyEvent_logAlreadyUsed() external {
        Vars memory vars = _getArbitrumParams();
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), vars.blockNumber + 16);
        vm.roll(vars.blockNumber + 16);
        vm.setBlockhash(vars.blockNumber, vars.blockHash);
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));

        TransferEventVerifier verifier = new TransferEventVerifier(address(this));
        verifier.setWhitelist(vars.receiver, true);

        bytes32 logHash = keccak256(abi.encode(vars.blockHash, vars.token, vars.txIndex, 0));
        assertFalse(verifier.usedLogs(logHash));

        vm.startPrank(vars.receiver);
        verifier.verifyEvent(
            EventVerifierBase.OffchainArgs(vars.blockNumber, vars.header, vars.txIndex, 0, vars.proof, ""),
            TransferEventVerifier.OnchainArgs(vars.token, vars.sender)
        );
        assertTrue(verifier.usedLogs(logHash));

        vm.expectRevert(EventVerifierBase.LogAlreadyUsed.selector);
        verifier.verifyEvent(
            EventVerifierBase.OffchainArgs(vars.blockNumber, vars.header, vars.txIndex, 0, vars.proof, ""),
            TransferEventVerifier.OnchainArgs(vars.token, vars.sender)
        );
        vm.stopPrank();
    }
}
