pragma solidity 0.8.26;
// SPDX-License-Identifier: AGPL-3.0-only

import {Escrow} from "src/Escrow.sol";
import "test/BaseTest.sol";

contract EscrowTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testApproveMax() public {
        address spender = address(0x2);
        assertEq(erc20.allowance(address(escrow), spender), 0);

        vm.prank(randomUser);
        vm.expectRevert();
        escrow.approveMax(address(erc20), spender);

        vm.prank(owner);
        escrow.approveMax(address(erc20), spender);
        assertEq(erc20.allowance(address(escrow), spender), type(uint256).max);
    }

    function testUnapprove() public {
        address spender = address(0x2);

        vm.prank(owner);
        escrow.approveMax(address(erc20), spender);
        assertEq(erc20.allowance(address(escrow), spender), type(uint256).max);

        vm.prank(randomUser);
        vm.expectRevert();
        escrow.unapprove(address(erc20), spender);

        vm.prank(owner);
        escrow.unapprove(address(erc20), spender);
        assertEq(erc20.allowance(address(escrow), spender), 0);
    }
}
