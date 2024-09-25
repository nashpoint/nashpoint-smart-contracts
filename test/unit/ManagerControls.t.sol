// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";

contract ManagerControls is BaseTest {
    function testEnableSwingPricing() public {
        // target swing factor == 10e16
        // anything less than that will return a value
        // all tests start with swing pricing disabled

        // assert returns 0
        assertEq(bestia.getSwingFactor(9e16), 0);

        // owner enables swing pricing
        bestia.enableSwingPricing(true);

        // assert that returns a value
        assertGt(bestia.getSwingFactor(9e16), 0);
    }
}
