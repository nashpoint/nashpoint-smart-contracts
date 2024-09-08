// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";

// CONTRACT & STATE:
// https://etherscan.io/address/0x1d01ef1997d44206d839b78ba6813f60f1b3a970
// taken from block 20591573
// evm version: cancun

// TESTING COMMAND:
// forge test --match-contract ForkedTests --fork-url $ETHEREUM_RPC_URL --fork-block-number 20591573 --evm-version cancun

// ASSET TOKEN FOR VAULT
// temporarily using "asset" instead of "usdc" for testing so as not to break unit test
// TODO: config later to make this just work with usdc

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
        assertEq(poolManager.assetToId(address(asset)), 242333941209166991950178742833476896417);

        // assert correct usdc balance for user1
        assertEq(asset.balanceOf(address(user1)), 27413316046);

        // assert gateway is active and other config
        assertEq(gateway.activeSessionId(), 0);
        assertEq(address(root), 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);
        assertEq(investmentManager.priceLastUpdated(address(liquidityPool)), 1722268992);
    }

    function testUsdcFork() public {
        uint256 currentChainId = block.chainid;
        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }

        address whale = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;

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

        vm.stopPrank();
    }

    function testVaultUserCanDepositWithdrawTransfer() public {
        uint256 currentChainId = block.chainid;
        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }

        // as the root account, add user to whitelist
        vm.startPrank(address(root));
        restrictionManager.updateMember(address(share), user1, type(uint64).max);
        restrictionManager.updateMember(address(share), user2, type(uint64).max);
        vm.stopPrank();

        // assert user has been whitelisted successfully
        (bool isMember,) = restrictionManager.isMember(address(share), user1);
        assertTrue(isMember);

        // user requests deposit to cfg pool
        vm.startPrank(user1);
        asset.approve(address(liquidityPool), MAX_ALLOWANCE);
        liquidityPool.requestDeposit(100, address(user1), address(user1));
        vm.stopPrank();

        // cfg root address uses manager to process the deposit request
        vm.startPrank(address(root));
        investmentManager.fulfillDepositRequest(
            liquidityPool.poolId(),
            liquidityPool.trancheId(),
            address(user1),
            poolManager.assetToId(liquidityPool.asset()),
            100,
            100
        );
        vm.stopPrank();

        // user mints
        vm.startPrank(address(user1));
        liquidityPool.mint(100, address(user1));
        vm.stopPrank();

        // assert user has received correct shares
        assertEq(share.balanceOf(address(user1)), 100);

        // assert user can transfer share to whitelisted user
        vm.startPrank(user1);
        share.transfer(address(user2), 50);
        assertEq(share.balanceOf(address(user2)), 50);

        // user1 requests redeem
        share.approve(address(liquidityPool), MAX_ALLOWANCE);
        liquidityPool.requestRedeem(50, address(user1), address(user1));
        vm.stopPrank();

        // cfg root address uses manager to process the redeem request
        vm.startPrank(address(root));
        investmentManager.fulfillRedeemRequest(
            liquidityPool.poolId(),
            liquidityPool.trancheId(),
            address(user1),
            poolManager.assetToId(liquidityPool.asset()),
            50,
            50
        );
        vm.stopPrank();

        // user withdraws available tokens
        vm.startPrank(user1);
        uint256 balBefore = asset.balanceOf(address(user1));
        liquidityPool.withdraw(50, address(user1), address(user1));
        vm.stopPrank();

        // assert user balance has increased by 50
        assertEq(asset.balanceOf(address(user1)), balBefore + 50);
    }

    function testAddCfgToBestia() public {
        uint256 currentChainId = block.chainid;
        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }

        // assert bestia and cfg vault have usdc deposit asset
        assertEq(bestia.asset(), address(asset));
        assertEq(liquidityPool.asset(), address(asset));

        // add liquidityPool as component to Bestia with 90% allocation (10% is reserve cash)
        bestia.addComponent(address(liquidityPool), 90, true, liquidityPool.share());

        // user approves and deposits to bestia
        vm.startPrank(user1);
        asset.approve(address(bestia), MAX_ALLOWANCE);
        bestia.deposit(100, address(user1));
        vm.stopPrank();

        // assert bestia has issued correct shares to user for 100 deposit
        assertEq(bestia.convertToAssets(bestia.balanceOf(user1)), 100);

        vm.startPrank(address(root));
        restrictionManager.updateMember(address(share), address(bestia), type(uint64).max);

        vm.stopPrank();

        // assert user has been whitelisted successfully
        (bool isMember,) = restrictionManager.isMember(address(share), address(bestia));
        assertTrue(isMember);

        vm.startPrank(banker);
        bestia.investInAsyncVault(address(liquidityPool));
        vm.stopPrank();
    }
}
