// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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

        testSpender = makeAddr("testSpender");
        
        testEscrow = new Escrow(address(node));
        
        mockToken = new ERC20Mock("Mock Token", "MOCK");
        mockTokenFailing = new ERC20Mock("Failing Token", "FAIL");
        mockTokenFailing.setFailApprovals(true);

        vm.label(address(testEscrow), "TestEscrow");
        vm.label(address(mockToken), "MockToken");
        vm.label(address(mockTokenFailing), "MockTokenFailing");
        vm.label(testSpender, "TestSpender");
    }

    function test_constructor() public {
        assertEq(address(testEscrow.node()), address(node));
    }

    function test_constructor_revert_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Escrow(address(0));
    }

    function test_approveMax() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit EventsLib.Approve(address(mockToken), testSpender, type(uint256).max);
        testEscrow.approveMax(address(mockToken), testSpender);
        assertEq(mockToken.allowance(address(testEscrow), testSpender), type(uint256).max);
    }

    function test_approveMax_revert_NotNodeOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        testEscrow.approveMax(address(mockToken), testSpender);
    }

    function test_approveMax_revert_SafeApproveFailed() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.SafeApproveFailed.selector);
        testEscrow.approveMax(address(mockTokenFailing), testSpender);
    }

    function test_unapprove() public {
        vm.prank(owner);
        testEscrow.approveMax(address(mockToken), testSpender);
        assertEq(mockToken.allowance(address(testEscrow), testSpender), type(uint256).max);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit EventsLib.Approve(address(mockToken), testSpender, 0);
        testEscrow.unapprove(address(mockToken), testSpender);
        assertEq(mockToken.allowance(address(testEscrow), testSpender), 0);
    }

    function test_unapprove_revert_NotNodeOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        testEscrow.unapprove(address(mockToken), testSpender);
    }

    function test_unapprove_revert_SafeApproveFailed() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.SafeApproveFailed.selector);
        testEscrow.unapprove(address(mockTokenFailing), testSpender);
    }

    function test_onlyNodeOwner() public {
        vm.prank(owner);
        testEscrow.approveMax(address(mockToken), testSpender);
    }

    function test_onlyNodeOwner_revert_NotNodeOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        testEscrow.approveMax(address(mockToken), testSpender);
    }
}
