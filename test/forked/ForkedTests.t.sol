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
    address public whale = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;
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

        // assert correct whale address
        assertEq(asset.balanceOf(whale), 1000000000016900);
        uint256 user1Balance = asset.balanceOf(address(user1));

        vm.startPrank(whale);

        // test can transfer usdc
        asset.transfer(address(user1), 100);
        assertEq(user1Balance + 100, asset.balanceOf(user1));

        // test can approve usdc
        asset.approve(address(node), MAX_ALLOWANCE);
        assertEq(asset.allowance(whale, address(node)), MAX_ALLOWANCE);

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

    function testCfgToNodeInteractions() public {
        uint256 currentChainId = block.chainid;
        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }

        uint256 initialDeposit = DEPOSIT_100;
        console2.log(address(node));
        console2.log(asset.balanceOf(address(node)));

        // empty user balance of asset token
        vm.startPrank(user1);
        asset.transfer(0x000000000000000000000000000000000000dEaD, asset.balanceOf(user1));
        vm.stopPrank();

        assertEq(asset.balanceOf(address(user1)), 0);

        vm.startPrank(whale);
        asset.transfer(address(user1), START_BALANCE_1000);
        vm.stopPrank();

        // assert node and cfg vault have usdc deposit asset
        assertEq(node.asset(), address(asset));
        assertEq(liquidityPool.asset(), address(asset));
        console2.log(asset.balanceOf(address(node)));

        // add liquidityPool as component to Node with 90% allocation (10% is reserve cash)
        node.addComponent(address(liquidityPool), 90e16, true, liquidityPool.share());

        // user approves and deposits to node
        vm.startPrank(user1);
        asset.approve(address(node), MAX_ALLOWANCE);
        node.deposit(initialDeposit, address(user1)); // note: this is the part failing
        vm.stopPrank();

        // assert node has issued correct shares to user for 100 deposit
        assertEq(node.convertToAssets(node.balanceOf(user1)), initialDeposit);

        // add node to cfg whitelist
        vm.startPrank(address(root));
        restrictionManager.updateMember(address(share), address(node), type(uint64).max);
        vm.stopPrank();

        // assert user has been whitelisted successfully
        (bool isMember,) = restrictionManager.isMember(address(share), address(node));
        assertTrue(isMember);

        // rebalancer invests node in cfg vault
        vm.startPrank(rebalancer);
        node.investInAsyncVault(address(liquidityPool));
        vm.stopPrank();

        // assert node totalAssets correctly including pendingDepositRequest
        assertEq(node.totalAssets(), initialDeposit);

        uint256 pendingDeposit = liquidityPool.pendingDepositRequest(0, address(node));
        uint256 expectedDeposit = initialDeposit * node.getComponentRatio(address(liquidityPool)) / 1e18;

        // assert pendingDeposit on cfg == correct ratio of assets for node
        assertEq(pendingDeposit, expectedDeposit);

        // estimate the shares cfg will mint based on current share price
        uint256 sharesToMint = liquidityPool.convertToShares(pendingDeposit);

        // cfg root address uses manager to process the deposit request
        vm.startPrank(address(root));
        investmentManager.fulfillDepositRequest(
            liquidityPool.poolId(),
            liquidityPool.trancheId(),
            address(node),
            poolManager.assetToId(liquidityPool.asset()),
            uint128(pendingDeposit),
            uint128(sharesToMint)
        );
        vm.stopPrank();

        // assert claimable deposit == expected deposit after rounding
        uint256 claimableDepositValue = liquidityPool.claimableDepositRequest(0, address(node));
        assertApproxEqAbs(claimableDepositValue, expectedDeposit, 1);

        // assert node is calculating claimableDepositRequest in totalAssets correctly after rounding
        assertApproxEqAbs(node.totalAssets(), initialDeposit, 1);

        // rebalancer mints claimable shares for node
        vm.startPrank(rebalancer);
        node.mintClaimableShares(address(liquidityPool));
        vm.stopPrank();

        // assert totalAssets is correct
        assertApproxEqAbs(node.totalAssets(), initialDeposit, 1);

        // assert pendingDeposits == 0
        assertEq(liquidityPool.pendingDepositRequest(0, address(node)), 0);

        // assert claimableDeposits == 0
        // note: rounding leaves 000001 behind, so only approxEq
        // todo: get feedback on best approach and fix this
        assertApproxEqAbs(liquidityPool.claimableDepositRequest(0, address(node)), 0, 1);

        // assert share balance = correct ratio of assets for node
        uint256 mintedShares = share.balanceOf(address(node));

        // assert minted shares match deposit value after rounding
        assertApproxEqAbs(liquidityPool.convertToAssets(mintedShares), expectedDeposit, 2);

        // START WITHDRAWAL FLOW

        // rebalancer calls request asyncWithdrawal on Node
        vm.startPrank(rebalancer);
        node.requestAsyncWithdrawal(address(liquidityPool), mintedShares);
        vm.stopPrank();

        // assert all of Node's shares have been returned to Centrifuge
        assertEq(share.balanceOf(address(node)), 0);

        // assert pendingRedeemRequest == all shares minted to node
        assertEq(mintedShares, liquidityPool.pendingRedeemRequest(0, address(node)));

        // assert getAsyncAssets gets full value of Node holding in CFG LiquidityPool
        // subtract cash reserve from initial deposit to Node
        // assume some rounding down
        uint256 cashReserve = asset.balanceOf(address(node));
        assertApproxEqAbs(node.getAsyncAssets(address(liquidityPool)), initialDeposit - cashReserve, 1);

        // assert totalAssets == initial deposit minus rounding
        assertApproxEqAbs(node.totalAssets(), initialDeposit, 1);

        uint128 pendingRedeem = uint128(liquidityPool.pendingRedeemRequest(0, address(node)));
        uint128 redeemableAssets =
            uint128(liquidityPool.convertToAssets(liquidityPool.pendingRedeemRequest(0, address(node))));

        // manager processes redeem request
        vm.startPrank(address(root));
        investmentManager.fulfillRedeemRequest(
            liquidityPool.poolId(),
            liquidityPool.trancheId(),
            address(node),
            poolManager.assetToId(liquidityPool.asset()),
            redeemableAssets,
            pendingRedeem
        );
        vm.stopPrank();

        // grab assets due from redemption
        uint256 claimableRedeem = liquidityPool.convertToAssets(liquidityPool.claimableRedeemRequest(0, address(node)));

        // assert correct assets are now available for redemption
        assertEq(redeemableAssets, claimableRedeem);

        // assert getAsyncAssets grabbing correct value for claimableRedeem
        assertApproxEqAbs(claimableRedeem, node.getAsyncAssets(address(liquidityPool)), 1);

        // assert totalAssets == initial deposit minus rounding
        assertApproxEqAbs(node.totalAssets(), initialDeposit, 1);

        // grab max amount of assets that can be withdrawn from cfg liquidityPool
        uint256 maxWithdraw = liquidityPool.maxWithdraw(address(node));

        // rebalancer executes the withdrawal on the node contract
        vm.startPrank(rebalancer);
        node.executeAsyncWithdrawal(address(liquidityPool), maxWithdraw);
        vm.stopPrank();

        // assert no more claimable withdraw from cfg lp
        assertEq(liquidityPool.maxWithdraw(address(node)), 0);

        // assert no shares still in claimable redeem state
        assertEq(liquidityPool.claimableRedeemRequest(0, address(node)), 0);

        // assert node not tracking and more async assets
        assertEq(node.getAsyncAssets(address(liquidityPool)), 0);

        // assert node now has total assets == initial deposit after rounding
        assertApproxEqAbs(node.totalAssets(), initialDeposit, 1);
    }
}
