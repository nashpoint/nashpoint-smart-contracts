// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract RebalancingTests is BaseTest {
    function testRebalance() public {
        // SET THE STRATEGY
        // add the 4626 Vaults
        bestia.addComponent(address(vaultA), 20e16);
        bestia.addComponent(address(vaultB), 20e16);
        bestia.addComponent(address(vaultC), 20e16);

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(tempRWA), 30e16); // temp delete

        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        console2.log("Reserve before rebalance :", usdc.balanceOf(address(bestia)));

        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
        bankerInvestsCash(address(tempRWA));

        console2.log("Reserve After Rebalance:", usdc.balanceOf(address(bestia)));
        console2.log("vaultA.balanceOf(address(bestia)) :", vaultA.balanceOf(address(bestia)));
        console2.log("vaultB.balanceOf(address(bestia)) :", vaultB.balanceOf(address(bestia)));
        console2.log("vaultC.balanceOf(address(bestia)) :", vaultC.balanceOf(address(bestia)));
        console2.log("tempRWA.balanceOf(address(bestia)) :", tempRWA.balanceOf(address(bestia)));
        
    }

    function bankerInvestsCash(address _component) public {
        vm.startPrank(banker);
        bestia.investCash(_component);
        vm.stopPrank();
    }
}
