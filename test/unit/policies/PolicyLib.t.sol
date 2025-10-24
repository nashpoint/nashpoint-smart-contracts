// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {PolicyLib} from "src/libraries/PolicyLib.sol";

contract PolicyLibHarness {
    function decodeDeposit(bytes calldata payload) external view returns (uint256 assets, address receiver) {
        return PolicyLib.decodeDeposit(payload);
    }

    function decodeMint(bytes calldata payload) external view returns (uint256 shares, address receiver) {
        return PolicyLib.decodeMint(payload);
    }

    function decodeRequestRedeem(bytes calldata payload)
        external
        view
        returns (uint256 shares, address controller, address owner)
    {
        return PolicyLib.decodeRequestRedeem(payload);
    }

    function decodeTransfer(bytes calldata payload) external view returns (address to, uint256 value) {
        return PolicyLib.decodeTransfer(payload);
    }

    function decodeApprove(bytes calldata payload) external view returns (address spender, uint256 value) {
        return PolicyLib.decodeApprove(payload);
    }

    function decodeTransferFrom(bytes calldata payload)
        external
        view
        returns (address from, address to, uint256 value)
    {
        return PolicyLib.decodeTransferFrom(payload);
    }

    function decodeExecute(bytes calldata payload) external view returns (address target, bytes memory data) {
        return PolicyLib.decodeExecute(payload);
    }

    function decodeSubtractProtocolExecutionFee(bytes calldata payload) external view returns (uint256 executionFee) {
        return PolicyLib.decodeSubtractProtocolExecutionFee(payload);
    }

    function decodeFulfillRedeemFromReserve(bytes calldata payload) external view returns (address controller) {
        return PolicyLib.decodeFulfillRedeemFromReserve(payload);
    }

    function decodeFinalizeRedemption(bytes calldata payload)
        external
        view
        returns (address controller, uint256 assetsToReturn, uint256 sharesPending, uint256 sharesAdjusted)
    {
        return PolicyLib.decodeFinalizeRedemption(payload);
    }

    function decodeSetOperator(bytes calldata payload) external view returns (address operator, bool approved) {
        return PolicyLib.decodeSetOperator(payload);
    }

    function decodeWithdraw(bytes calldata payload)
        external
        view
        returns (uint256 assets, address receiver, address controller)
    {
        return PolicyLib.decodeWithdraw(payload);
    }

    function decodeRedeem(bytes calldata payload)
        external
        view
        returns (uint256 shares, address receiver, address controller)
    {
        return PolicyLib.decodeRedeem(payload);
    }
}

contract PolicyLibTest is Test {
    PolicyLibHarness internal harness;

    function setUp() external {
        harness = new PolicyLibHarness();
    }

    function test_decodeDeposit() external {
        bytes memory payload = abi.encode(uint256(123), address(0xBEEF));
        (uint256 assets, address receiver) = harness.decodeDeposit(payload);
        assertEq(assets, 123);
        assertEq(receiver, address(0xBEEF));
    }

    function test_decodeMint() external {
        bytes memory payload = abi.encode(uint256(321), address(0xFACE));
        (uint256 shares, address receiver) = harness.decodeMint(payload);
        assertEq(shares, 321);
        assertEq(receiver, address(0xFACE));
    }

    function test_decodeRequestRedeem() external {
        bytes memory payload = abi.encode(uint256(111), address(0x1), address(0x2));
        (uint256 shares, address controller, address owner) = harness.decodeRequestRedeem(payload);
        assertEq(shares, 111);
        assertEq(controller, address(0x1));
        assertEq(owner, address(0x2));
    }

    function test_decodeTransfer() external {
        bytes memory payload = abi.encode(address(0xABCD), uint256(999));
        (address to, uint256 value) = harness.decodeTransfer(payload);
        assertEq(to, address(0xABCD));
        assertEq(value, 999);
    }

    function test_decodeApprove() external {
        bytes memory payload = abi.encode(address(0xCAFE), uint256(777));
        (address spender, uint256 value) = harness.decodeApprove(payload);
        assertEq(spender, address(0xCAFE));
        assertEq(value, 777);
    }

    function test_decodeTransferFrom() external {
        bytes memory payload = abi.encode(address(0xAA), address(0xBB), uint256(555));
        (address from, address to, uint256 value) = harness.decodeTransferFrom(payload);
        assertEq(from, address(0xAA));
        assertEq(to, address(0xBB));
        assertEq(value, 555);
    }

    function test_decodeExecute() external {
        bytes memory nested = abi.encodeWithSelector(bytes4(uint32(0xDEADBEEF)), uint256(42));
        bytes memory payload = abi.encode(address(0x1234), nested);
        (address target, bytes memory data) = harness.decodeExecute(payload);
        assertEq(target, address(0x1234));
        assertEq(data, nested);
    }

    function test_decodeSubtractProtocolExecutionFee() external {
        bytes memory payload = abi.encode(uint256(12));
        uint256 executionFee = harness.decodeSubtractProtocolExecutionFee(payload);
        assertEq(executionFee, 12);
    }

    function test_decodeFulfillRedeemFromReserve() external {
        bytes memory payload = abi.encode(address(0x99));
        address controller = harness.decodeFulfillRedeemFromReserve(payload);
        assertEq(controller, address(0x99));
    }

    function test_decodeFinalizeRedemption() external {
        bytes memory payload = abi.encode(address(0x10), uint256(200), uint256(300), uint256(400));
        (address controller, uint256 assetsToReturn, uint256 sharesPending, uint256 sharesAdjusted) =
            harness.decodeFinalizeRedemption(payload);
        assertEq(controller, address(0x10));
        assertEq(assetsToReturn, 200);
        assertEq(sharesPending, 300);
        assertEq(sharesAdjusted, 400);
    }

    function test_decodeSetOperator() external {
        bytes memory payload = abi.encode(address(0x77), true);
        (address operator, bool approved) = harness.decodeSetOperator(payload);
        assertEq(operator, address(0x77));
        assertTrue(approved);
    }

    function test_decodeWithdraw() external {
        bytes memory payload = abi.encode(uint256(9999), address(0x33), address(0x44));
        (uint256 assets, address receiver, address controller) = harness.decodeWithdraw(payload);
        assertEq(assets, 9999);
        assertEq(receiver, address(0x33));
        assertEq(controller, address(0x44));
    }

    function test_decodeRedeem() external {
        bytes memory payload = abi.encode(uint256(8888), address(0x55), address(0x66));
        (uint256 shares, address receiver, address controller) = harness.decodeRedeem(payload);
        assertEq(shares, 8888);
        assertEq(receiver, address(0x55));
        assertEq(controller, address(0x66));
    }
}
