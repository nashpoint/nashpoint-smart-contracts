// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract RebalancingTests is BaseTest {
    function testSimpleRebalance() public {
        // SET THE STRATEGY
        // add the 4626 Vaults
        bestia.addComponent(address(vaultA), 18e16);
        bestia.addComponent(address(vaultB), 20e16);
        bestia.addComponent(address(vaultC), 22e16);

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(tempRWA), 30e16); // temp delete

        // initial deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // banker rebalances bestia
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
        bankerInvestsCash(address(tempRWA));

        // second deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_10, address(user1));
        vm.stopPrank();

        // banker rebalances bestia
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
        bankerInvestsCash(address(tempRWA));

        // assert the components are in the right proportion
        assertEq(
            vaultA.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(vaultA))
        );
        assertEq(
            vaultB.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(vaultB))
        );
        assertEq(
            vaultC.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(vaultC))
        );
        assertEq(
            tempRWA.balanceOf(address(bestia)) * 1e18 / bestia.totalAssets(), bestia.getComponentRatio(address(tempRWA))
        );

        // third deposit
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_1 * 6, address(user1));
        vm.stopPrank();

        // banker rebalances bestia
        // expect revert as asset within range
        vm.expectRevert();
        bankerInvestsCash(address(vaultA));   

        // rebalances succeed as outside range
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
        bankerInvestsCash(address(tempRWA));
    }

    function bankerInvestsCash(address _component) public {
        vm.startPrank(banker);
        bestia.investCash(_component);
        vm.stopPrank();
    }
}
