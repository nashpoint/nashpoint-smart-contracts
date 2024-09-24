// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Bestia} from "src/bestia.sol"; // Ensure you're importing Bestia contract

contract FactoryTest is BaseTest {
    function testCreateNode() public {
        vm.startPrank(user1);

        // Call the factory to create a new Bestia contract and cast the returned address to Bestia
        address bestiaAddress = nodeFactory.create(
            address(usdcMock), // deposit asset (mocked USDC)
            "Pilot Node", // Name of the node
            "PNODE", // Symbol for the node
            address(banker), // Banker's address
            2e16, // max discount
            10e16, // target reserve ratio
            1e16, // max delta
            3e16, // async max delta
            address(user1) // Owner's address
        );

        // Stop the prank
        vm.stopPrank();

        // Cast the returned address to the Bestia contract type to interact with it
        Bestia pilotNode = Bestia(bestiaAddress);

        // Ensure that the owner of the newly created node is user1
        assertEq(pilotNode.owner(), user1);
    }
}
