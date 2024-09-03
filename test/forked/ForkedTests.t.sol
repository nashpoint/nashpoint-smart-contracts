// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";

// CONTRACT & STATE:
// https://etherscan.io/address/0x1d01ef1997d44206d839b78ba6813f60f1b3a970
// taken from block 20591573
// evm version: shanghai

// TESTING COMMAND:
// forge test --match-test testGetPoolData --fork-url $ETHEREUM_RPC_URL --fork-block-number 20591573 --evm-version shanghai

contract ForkedTests is BaseTest {
    // setup test to confirm network config, block and smart contract
    // gets chainId and return as a pass if not ethereum
    function testGetPoolData() public view {
        uint256 currentChainId = block.chainid;
        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }

        // check all the liquidity pool data is correct
        assertEq(address(liquidityPool), 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970);
        assertEq(liquidityPool.asset(), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        assertEq(liquidityPool.share(), 0x8c213ee79581Ff4984583C6a801e5263418C4b86);
        assertEq(liquidityPool.totalAssets(), 7160331396067);
        assertEq(liquidityPool.manager(), 0xE79f06573d6aF1B66166A926483ba00924285d20);

        // check the share (ITranche) data is correct
        assertEq(share.totalSupply(), 6960019964044);
        assertEq(share.hook(), 0x4737C3f62Cc265e786b280153fC666cEA2fBc0c0);
        // console2.log(share.name()); // TODO: this is failing, check again after config finished
        console2.log(share.hook());
    }

    function testCanAddAddressToVault() public {
        uint256 currentChainId = block.chainid;
        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }

        root = address(root);
        vm.startPrank(root);
        RestrictionManager.updateMember(address(share), user1, type(uint64).max);
        vm.stopPrank();

        (bool isMember,) = RestrictionManager.isMember(address(share), user1);
        assertTrue(isMember);
    }
}
