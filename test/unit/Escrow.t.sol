// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {Escrow} from "src/Escrow.sol";
import {Node} from "src/Node.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowTest is BaseTest {
    Escrow public testEscrow;
    ERC20Mock public mockToken;
    ERC20Mock public mockTokenFailing;

    address public testSpender;

    function setUp() public override {
        super.setUp();

        testEscrow = new Escrow(address(node));
        mockToken = new ERC20Mock("Mock Token", "MOCK");
        vm.label(address(testEscrow), "TestEscrow");
    }

    function test_constructor() public view {
        assertEq(address(testEscrow.node()), address(node));
    }

    function test_constructor_revert_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Escrow(address(0));
    }
}
