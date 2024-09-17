// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";


contract LiquidationsTest is BaseTest {
    function testLiquidateSynchVault() public {
        seedBestia();
        // seed vault with 100e6 cash
        // rebalanced into:
            // Cash Reserve: 10%
            // 3 ERC-4626 vaults: 18%, 20%, 22%
            // 1 ERC-7540 vault: 30%

        // user withhdraws 10e6 cash
        vm.startPrank(user1);
        bestia.withdraw(DEPOSIT_10, address(user1), (address(user1)));
        vm.stopPrank();        

        // assert reserve cash == zero
        assertEq(usdcMock.balanceOf(address(bestia)), 0);

        
    }
}