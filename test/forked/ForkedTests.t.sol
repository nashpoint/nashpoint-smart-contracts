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

// ASSET TOKEN FOR VAULT
// temporarily using "asset" instead of "usdc" for testing so as not to break unit test
// TODO: config later to have easier

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

        // replace this check later when using not hard-coded asset (USDC) address
        assertEq(
            poolManager.assetToId(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), 242333941209166991950178742833476896417
        );

        // assert correct usdc balance for user1
        assertEq(asset.balanceOf(address(user1)), 27413316046);

        // assert gateway is active and other config
        assertEq(gateway.activeSessionId(), 0);
        assertEq(address(root), 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);
        assertEq(investmentManager.priceLastUpdated(address(liquidityPool)), 1722268992);
    }

    function testUsdcFork() public {
        address whale = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;
        uint256 currentChainId = block.chainid;
        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }

        // assert correct whale address
        assertEq(asset.balanceOf(whale), 1000000000016900);
        uint256 user1Balance = asset.balanceOf(address(user1));

        vm.startPrank(whale);

        // test can transfer usdc
        asset.transfer(address(user1), 100);
        assertEq(user1Balance + 100, asset.balanceOf(user1));

        // test can approve usdc
        asset.approve(address(bestia), MAX_ALLOWANCE);
        assertEq(asset.allowance(whale, address(bestia)), MAX_ALLOWANCE);
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

        vm.startPrank(address(root));
        restrictionManager.updateMember(address(share), user1, type(uint64).max);
        vm.stopPrank();

        (bool isMember,) = restrictionManager.isMember(address(share), user1);
        assertTrue(isMember);

        vm.startPrank(user1);
        asset.approve(address(liquidityPool), MAX_ALLOWANCE);
        liquidityPool.requestDeposit(100, address(user1), address(user1));
        vm.stopPrank();
    }
}
