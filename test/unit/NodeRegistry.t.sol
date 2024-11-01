// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

contract NodeRegistryTest is BaseTest {
    address public factory;
    address public router;
    address public quoter_;
    address public node_;

    function setUp() public override {
        super.setUp();
        factory = makeAddr("factory");
        router = makeAddr("router");
        quoter_ = makeAddr("quoter");
        node_ = makeAddr("node");
    }

    function test_constructor() public {
        NodeRegistry newRegistry = new NodeRegistry(owner);
        assertEq(newRegistry.owner(), owner);
        assertFalse(newRegistry.isInitialized());
    }
}
