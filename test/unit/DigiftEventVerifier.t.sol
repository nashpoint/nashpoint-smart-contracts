// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";

contract DigiftEventVerifierHarness is DigiftEventVerifier {
    constructor(address registry_) DigiftEventVerifier(registry_) {}

    function stripTypedPrefix(bytes memory b) external pure returns (bytes memory) {
        return _stripTypedPrefix(b);
    }
}

contract DigiftEventVerifierTest is Test {
    DigiftEventVerifierHarness harness;

    function setUp() public {
        // Mock the owner function to return this contract
        vm.mockCall(address(this), abi.encodeWithSignature("owner()"), abi.encode(address(this)));

        // Deploy the harness contract
        harness = new DigiftEventVerifierHarness(address(this));
    }

    function test_stripTypedPrefix_EIP2930() external view {
        bytes memory input = hex"01deadbeef";
        bytes memory expected = hex"deadbeef";
        bytes memory result = harness.stripTypedPrefix(input);
        assertEq(result, expected);
    }

    function test_stripTypedPrefix_EIP1559() external view {
        bytes memory input = hex"02cafebabe";
        bytes memory expected = hex"cafebabe";
        bytes memory result = harness.stripTypedPrefix(input);
        assertEq(result, expected);
    }

    function test_stripTypedPrefix_EIP4844() external view {
        bytes memory input = hex"03f00dface";
        bytes memory expected = hex"f00dface";
        bytes memory result = harness.stripTypedPrefix(input);
        assertEq(result, expected);
    }

    function test_stripTypedPrefix_nonTyped() external view {
        bytes memory input = hex"deadbeefcafebabe";
        bytes memory result = harness.stripTypedPrefix(input);
        assertEq(result, input);
    }

    function test_stripTypedPrefix_ZeroBytes() external {
        vm.expectRevert(DigiftEventVerifier.ZeroBytes.selector);
        harness.stripTypedPrefix("");
    }
}
