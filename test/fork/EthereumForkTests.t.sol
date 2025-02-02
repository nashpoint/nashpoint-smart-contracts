// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "test/BaseTest.sol";
import {ERC7540RouterHarness} from "test/unit/routers/ERC7540Router.t.sol";

import {Node} from "src/Node.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";

import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

import {console2} from "forge-std/console2.sol";

// CONTRACT & STATE:
// https://etherscan.io/address/0x1d01ef1997d44206d839b78ba6813f60f1b3a970
// taken from block 20591573
// evm version: cancun

interface ILiquidityPool is IERC7575, IERC7540Deposit, IERC7540Redeem {
    function manager() external view returns (address);
    function poolId() external view returns (uint64);
    function trancheId() external view returns (bytes16);
    function root() external view returns (address);
}

interface IRestrictionManager {
    function updateMember(address, address, uint64) external;
    function isMember(address token, address user) external view returns (bool isValid, uint64 validUntil);
}

interface IInvestmentManager {
    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;

    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
}

interface IPoolManager {
    function assetToId(address) external view returns (uint128 assetId);
}

contract EthereumForkTests is BaseTest {
    uint256 ethereumFork;
    uint256 blockNumber = 20591573;
    address cfgLiquidityPoolAddress = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
    address root;
    address share;
    IRestrictionManager restrictionManager;
    ILiquidityPool cfgLiquidityPool;
    IInvestmentManager investmentManager;
    IPoolManager poolManager_;

    ERC7540RouterHarness testRouter;

    ComponentAllocation allocation;

    function setUp() public override {
        string memory ETHEREUM_RPC_URL = vm.envString("ETHEREUM_RPC_URL");
        ethereumFork = vm.createFork(ETHEREUM_RPC_URL, blockNumber);
        vm.selectFork(ethereumFork);
        super.setUp();

        cfgLiquidityPool = ILiquidityPool(cfgLiquidityPoolAddress);
        root = cfgLiquidityPool.root();
        restrictionManager = IRestrictionManager(0x4737C3f62Cc265e786b280153fC666cEA2fBc0c0);
        investmentManager = IInvestmentManager(cfgLiquidityPool.manager());
        poolManager_ = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);
        share = cfgLiquidityPool.share();

        testRouter = new ERC7540RouterHarness(address(registry));

        allocation = ComponentAllocation({
            targetWeight: 0.9 ether,
            maxDelta: 0.03 ether,
            router: address(router7540),
            isComponent: true
        });

        // user approves and deposits to node
        vm.startPrank(user);
        IERC20(cfgLiquidityPool.asset()).approve(address(node), type(uint256).max);
        node.deposit(100 ether, address(user));
        vm.stopPrank();

        // warp forward to ensure not rebalancing
        vm.warp(block.timestamp + 1 days);

        // add centrifuge liquidity pool to protocol contracts
        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(cfgLiquidityPool), true);
        node.addComponent(address(cfgLiquidityPool), allocation.targetWeight, allocation.maxDelta, address(router7540));
        quoter.setErc7540(address(cfgLiquidityPool));
        vm.stopPrank();

        // add node to cfg whitelist
        vm.startPrank(address(root));
        restrictionManager.updateMember(share, address(node), type(uint64).max);
        vm.stopPrank();

        vm.prank(owner);
        node.updateComponentAllocation(address(vault), 0, 0, address(router7540));

        vm.prank(rebalancer);
        node.startRebalance();
    }

    function test_canSelectEthereum() public {
        vm.selectFork(ethereumFork);
        assertEq(vm.activeFork(), ethereumFork);
    }

    function test_usdcAddress_ethereum() public view {
        assertEq(IERC20Metadata(usdcEthereum).name(), "USD Coin");
        assertEq(IERC20Metadata(usdcEthereum).totalSupply(), 25385817571885697);
        assertEq(IERC20Metadata(usdcEthereum).decimals(), 6);
    }

    function test_centrifugeLiquidityPool_info() public view {
        // check all the liquidity pool data is correct
        assertEq(cfgLiquidityPool.asset(), usdcEthereum);
        assertEq(cfgLiquidityPool.share(), 0x8c213ee79581Ff4984583C6a801e5263418C4b86);
        assertEq(cfgLiquidityPool.totalAssets(), 7160331396067);
        assertEq(cfgLiquidityPool.manager(), 0xE79f06573d6aF1B66166A926483ba00924285d20);
        assertEq(cfgLiquidityPool.poolId(), 4139607887);
        assertEq(cfgLiquidityPool.trancheId(), bytes16(0x97aa65f23e7be09fcd62d0554d2e9273));
        assertEq(cfgLiquidityPool.root(), root);
        assertEq(poolManager_.assetToId(cfgLiquidityPool.asset()), 242333941209166991950178742833476896417);
    }

    function test_userInteractions() public {
        // as the root account, add user to whitelist
        vm.startPrank(address(root));
        restrictionManager.updateMember(share, user, type(uint64).max);
        vm.stopPrank();

        // assert users have been whitelisted successfully
        (bool isMember,) = restrictionManager.isMember(address(share), user);
        assertTrue(isMember);

        // user requests deposit to cfg pool
        vm.startPrank(user);
        IERC20(cfgLiquidityPool.asset()).approve(address(cfgLiquidityPool), type(uint256).max);
        cfgLiquidityPool.requestDeposit(100 ether, address(user), address(user));
        vm.stopPrank();

        // cfg root address uses manager to process the deposit request
        vm.startPrank(address(root));
        investmentManager.fulfillDepositRequest(
            cfgLiquidityPool.poolId(),
            cfgLiquidityPool.trancheId(),
            address(user),
            poolManager_.assetToId(cfgLiquidityPool.asset()),
            100 ether,
            100 ether
        );
        vm.stopPrank();

        // user mints
        vm.startPrank(address(user));
        cfgLiquidityPool.mint(100 ether, address(user));
        vm.stopPrank();

        // assert user has received correct shares
        assertEq(IERC20(share).balanceOf(address(user)), 100 ether);

        // user requests redeem
        vm.startPrank(address(user));
        IERC20(share).approve(address(cfgLiquidityPool), 100 ether);
        cfgLiquidityPool.requestRedeem(100 ether, address(user), address(user));
        vm.stopPrank();

        // cfg root address uses manager to process the redeem request
        vm.startPrank(address(root));
        investmentManager.fulfillRedeemRequest(
            cfgLiquidityPool.poolId(),
            cfgLiquidityPool.trancheId(),
            address(user),
            poolManager_.assetToId(cfgLiquidityPool.asset()),
            100 ether,
            100 ether
        );
        vm.stopPrank();

        // user withdraws available tokens
        vm.startPrank(user);
        uint256 balBefore = IERC20(cfgLiquidityPool.asset()).balanceOf(address(user));
        cfgLiquidityPool.withdraw(100 ether, address(user), address(user));
        vm.stopPrank();

        // assert user balance has increased by 100
        assertEq(IERC20(cfgLiquidityPool.asset()).balanceOf(address(user)), balBefore + 100 ether);
    }

    function test_cfgToNode_authorizedAddress() public view {
        // assert user has been whitelisted successfully
        (bool isMember,) = restrictionManager.isMember(address(share), address(node));
        assertTrue(isMember);
    }

    function test_cfgToNode_initialDeposit() public view {
        // assert node has issued correct shares to user for 100 deposit
        assertEq(node.convertToAssets(node.balanceOf(user)), 100 ether);
    }

    function test_cfgToNode_investInAsyncAsset() public {
        // rebalancer invests node in cfg vault
        vm.startPrank(rebalancer);
        router7540.investInAsyncComponent(address(node), address(cfgLiquidityPool));
        vm.stopPrank();

        // assert node totalAssets correctly including pendingDepositRequest
        assertEq(node.totalAssets(), 100 ether);

        // assert pendingDeposit on cfg == correct ratio of assets for node
        uint256 pendingDeposit = cfgLiquidityPool.pendingDepositRequest(0, address(node));
        uint256 expectedDeposit =
            100 ether * uint256(node.getComponentAllocation(address(cfgLiquidityPool)).targetWeight) / 1e18;
        assertEq(pendingDeposit, expectedDeposit);
    }

    function test_cfgToNode_mintClaimableShares() public {
        vm.startPrank(rebalancer);
        router7540.investInAsyncComponent(address(node), address(cfgLiquidityPool));
        vm.stopPrank();

        uint256 pendingDepositAssets = cfgLiquidityPool.pendingDepositRequest(0, address(node));
        uint256 sharesToMint = cfgLiquidityPool.convertToShares(pendingDepositAssets);

        // cfg root address uses manager to process the deposit request
        vm.startPrank(address(root));
        investmentManager.fulfillDepositRequest(
            cfgLiquidityPool.poolId(),
            cfgLiquidityPool.trancheId(),
            address(node),
            poolManager_.assetToId(cfgLiquidityPool.asset()),
            uint128(pendingDepositAssets),
            uint128(sharesToMint)
        );
        vm.stopPrank();

        assertEq(cfgLiquidityPool.maxMint(address(node)), sharesToMint);
        assertEq(cfgLiquidityPool.pendingDepositRequest(0, address(node)), 0);
        assertApproxEqAbs(cfgLiquidityPool.claimableDepositRequest(0, address(node)), 90 ether, 1);
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(cfgLiquidityPool));

        assertEq(IERC20(share).balanceOf(address(node)), sharesToMint);
        assertEq(cfgLiquidityPool.pendingDepositRequest(0, address(node)), 0);
        assertEq(cfgLiquidityPool.claimableDepositRequest(0, address(node)), 0);
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);
    }

    function test_cfgToNode_requestAsyncWithdrawal() public {
        test_cfgToNode_mintClaimableShares();

        uint256 shares = IERC20(share).balanceOf(address(node));

        vm.prank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), address(cfgLiquidityPool), shares);

        assertEq(IERC20(share).balanceOf(address(node)), 0);
        assertEq(cfgLiquidityPool.pendingRedeemRequest(0, address(node)), shares);
        assertApproxEqAbs(cfgLiquidityPool.convertToAssets(shares), 90 ether, 1);
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);

        // manager processes redeem request
        vm.startPrank(address(root));
        investmentManager.fulfillRedeemRequest(
            cfgLiquidityPool.poolId(),
            cfgLiquidityPool.trancheId(),
            address(node),
            poolManager_.assetToId(cfgLiquidityPool.asset()),
            uint128(cfgLiquidityPool.convertToAssets(shares)),
            uint128(shares)
        );
        vm.stopPrank();

        assertApproxEqAbs(cfgLiquidityPool.maxWithdraw(address(node)), 90 ether, 1);
        assertEq(cfgLiquidityPool.pendingRedeemRequest(0, address(node)), 0);

        // note: rounds up as totalAssets increased by 86 units
        assertApproxEqAbs(node.totalAssets(), 100 ether, 100);

        // note: rounds up as asset value of shares increased by 86 units
        uint256 redeemableShares = cfgLiquidityPool.claimableRedeemRequest(0, address(node));
        assertApproxEqAbs(cfgLiquidityPool.convertToAssets(redeemableShares), 90 ether, 100);
    }

    function test_cfgToNode_executeAsyncWithdrawal() public {
        test_cfgToNode_requestAsyncWithdrawal();

        // grab max amount of assets that can be withdrawn from cfg liquidityPool
        uint256 maxWithdraw = cfgLiquidityPool.maxWithdraw(address(node));

        // rebalancer executes the withdrawal on the node contract
        vm.prank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(cfgLiquidityPool), maxWithdraw);

        assertEq(testRouter.getErc7540Assets(address(node), address(cfgLiquidityPool)), 0);
        assertEq(cfgLiquidityPool.claimableRedeemRequest(0, address(node)), 0);
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);
    }
}
