// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.sol";

contract DepositFlow is BaseTest {

    function test_depositFlow_totalAssets() public {
        vm.startPrank(user);
        asset.approve(address(node), 1 ether);
        node.requestDeposit(1 ether, user, user);
        vm.stopPrank();

        assertEq(node.totalAssets(), 0);

        vm.prank(rebalancer);




    }
    
}