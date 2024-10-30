// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {Quoter} from "src/Quoter.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract QuoterTest is BaseTest {
    address mockErc4626;
    address mockErc7540;

    function setUp() public override {
        super.setUp();
        
        mockErc4626 = makeAddr("mockErc4626");
        mockErc7540 = makeAddr("mockErc7540");
    }

    function test_deployment() public {
        Quoter newQuoter = new Quoter(
            address(node),
            owner
        );

        assertEq(address(newQuoter.node()), address(node));
        assertEq(Ownable(address(newQuoter)).owner(), owner);
        
        assertFalse(newQuoter.isErc4626(mockErc4626));
        assertFalse(newQuoter.isErc7540(mockErc7540));
    }

    function test_deployment_RevertIf_ZeroNode() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new Quoter(
            address(0),
            owner
        );
    }

    function test_setErc4626() public {
        vm.prank(owner);
        quoter.setErc4626(mockErc4626, true);
        assertTrue(quoter.isErc4626(mockErc4626));

        vm.prank(owner);
        quoter.setErc4626(mockErc4626, false);
        assertFalse(quoter.isErc4626(mockErc4626));
    }

    function test_setErc4626_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        quoter.setErc4626(mockErc4626, true);
    }

    function test_setErc7540() public {
        vm.prank(owner);
        quoter.setErc7540(mockErc7540, true);
        assertTrue(quoter.isErc7540(mockErc7540));

        vm.prank(owner);
        quoter.setErc7540(mockErc7540, false);
        assertFalse(quoter.isErc7540(mockErc7540));
    }

    function test_setErc7540_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        quoter.setErc7540(mockErc7540, true);
    }

    function test_setMultipleComponents() public {
        address[] memory erc4626Components = new address[](3);
        address[] memory erc7540Components = new address[](3);
        
        for(uint i = 0; i < 3; i++) {
            erc4626Components[i] = makeAddr(string.concat("erc4626_", vm.toString(i)));
            erc7540Components[i] = makeAddr(string.concat("erc7540_", vm.toString(i)));
        }

        vm.startPrank(owner);
        
        // Set multiple ERC4626 components
        for(uint i = 0; i < erc4626Components.length; i++) {
            quoter.setErc4626(erc4626Components[i], true);
            assertTrue(quoter.isErc4626(erc4626Components[i]));
        }

        // Set multiple ERC7540 components
        for(uint i = 0; i < erc7540Components.length; i++) {
            quoter.setErc7540(erc7540Components[i], true);
            assertTrue(quoter.isErc7540(erc7540Components[i]));
        }

        vm.stopPrank();
    }
}
