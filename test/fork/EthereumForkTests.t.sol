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
    }

    function test_canSelectEthereum() public {
        vm.selectFork(ethereumFork);
        assertEq(vm.activeFork(), ethereumFork);
    }

    function test_usdcAddress_ethereum() public view {
        string memory name = IERC20Metadata(usdcEthereum).name();
        uint256 totalSupply = IERC20Metadata(usdcEthereum).totalSupply();
        assertEq(name, "USD Coin");
        assertEq(totalSupply, 25385817571885697);
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

    function test_cfgToNode_fullFlow() public {
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.03 ether});

        vm.startPrank(owner);
        router7540.setWhitelistStatus(address(cfgLiquidityPool), true);
        node.addComponent(address(cfgLiquidityPool), allocation);
        quoter.setErc7540(address(cfgLiquidityPool), true);
        vm.stopPrank();

        // user approves and deposits to node
        vm.startPrank(user);
        IERC20(cfgLiquidityPool.asset()).approve(address(node), type(uint256).max);
        node.deposit(100 ether, address(user));
        vm.stopPrank();

        // assert node has issued correct shares to user for 100 deposit
        assertEq(node.convertToAssets(node.balanceOf(user)), 100 ether);

        // add node to cfg whitelist
        vm.startPrank(address(root));
        restrictionManager.updateMember(share, address(node), type(uint64).max);
        vm.stopPrank();

        // assert user has been whitelisted successfully
        (bool isMember,) = restrictionManager.isMember(address(share), address(node));
        assertTrue(isMember);

        // rebalancer invests node in cfg vault
        vm.startPrank(rebalancer);
        router7540.investInAsyncVault(address(node), address(cfgLiquidityPool));
        vm.stopPrank();

        // assert node totalAssets correctly including pendingDepositRequest
        assertEq(node.totalAssets(), 100 ether);

        // assert pendingDeposit on cfg == correct ratio of assets for node
        uint256 pendingDeposit = cfgLiquidityPool.pendingDepositRequest(0, address(node));
        uint256 expectedDeposit = 100 ether * node.getComponentRatio(address(cfgLiquidityPool)) / 1e18;
        assertEq(pendingDeposit, expectedDeposit);

        // estimate the shares cfg will mint based on current share price
        uint256 sharesToMint = cfgLiquidityPool.convertToShares(pendingDeposit);

        // cfg root address uses manager to process the deposit request
        vm.startPrank(address(root));
        investmentManager.fulfillDepositRequest(
            cfgLiquidityPool.poolId(),
            cfgLiquidityPool.trancheId(),
            address(node),
            poolManager_.assetToId(cfgLiquidityPool.asset()),
            uint128(pendingDeposit),
            uint128(sharesToMint)
        );
        vm.stopPrank();

        uint256 claimableDepositValue = cfgLiquidityPool.claimableDepositRequest(0, address(node));
        assertApproxEqAbs(claimableDepositValue, expectedDeposit, 1);
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);

        // rebalancer mints claimable shares for node
        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(cfgLiquidityPool));
        vm.stopPrank();

        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);
        assertEq(cfgLiquidityPool.pendingDepositRequest(0, address(node)), 0);
        assertApproxEqAbs(cfgLiquidityPool.claimableDepositRequest(0, address(node)), 0, 1);

        uint256 mintedShares = IERC20(share).balanceOf(address(node));
        assertApproxEqAbs(cfgLiquidityPool.convertToAssets(mintedShares), expectedDeposit, 2);

        // START WITHDRAWAL FLOW

        // rebalancer calls request asyncWithdrawal on Node
        vm.startPrank(rebalancer);
        router7540.requestAsyncWithdrawal(address(node), address(cfgLiquidityPool), mintedShares);
        vm.stopPrank();

        // assert all of Node's shares have been returned to Centrifuge
        assertEq(IERC20(share).balanceOf(address(node)), 0);

        // assert pendingRedeemRequest == all shares minted to node
        assertEq(mintedShares, cfgLiquidityPool.pendingRedeemRequest(0, address(node)));

        // assert getAsyncAssets gets full value of Node holding in CFG LiquidityPool
        // subtract cash reserve from initial deposit to Node
        // assume some rounding down
        uint256 cashReserve = asset.balanceOf(address(node));
        assertApproxEqAbs(
            testRouter.getErc7540Assets(address(node), address(cfgLiquidityPool)), 100 ether - cashReserve, 1
        );

        // assert totalAssets == initial deposit minus rounding
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);

        uint128 pendingRedeem = uint128(cfgLiquidityPool.pendingRedeemRequest(0, address(node)));
        uint128 redeemableAssets =
            uint128(cfgLiquidityPool.convertToAssets(cfgLiquidityPool.pendingRedeemRequest(0, address(node))));

        // manager processes redeem request
        vm.startPrank(address(root));
        investmentManager.fulfillRedeemRequest(
            cfgLiquidityPool.poolId(),
            cfgLiquidityPool.trancheId(),
            address(node),
            poolManager_.assetToId(cfgLiquidityPool.asset()),
            redeemableAssets,
            pendingRedeem
        );
        vm.stopPrank();

        // grab assets due from redemption
        uint256 claimableRedeem =
            cfgLiquidityPool.convertToAssets(cfgLiquidityPool.claimableRedeemRequest(0, address(node)));

        // assert correct assets are now available for redemption
        assertEq(redeemableAssets, claimableRedeem);

        // assert getAsyncAssets grabbing correct value for claimableRedeem
        assertApproxEqAbs(claimableRedeem, testRouter.getErc7540Assets(address(node), address(cfgLiquidityPool)), 1);

        // assert totalAssets == initial deposit minus rounding
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);

        // grab max amount of assets that can be withdrawn from cfg liquidityPool
        uint256 maxWithdraw = cfgLiquidityPool.maxWithdraw(address(node));

        // rebalancer executes the withdrawal on the node contract
        vm.startPrank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(cfgLiquidityPool), maxWithdraw);
        vm.stopPrank();

        // assert no more claimable withdraw from cfg lp
        assertEq(cfgLiquidityPool.maxWithdraw(address(node)), 0);

        // assert no shares still in claimable redeem state
        assertEq(cfgLiquidityPool.claimableRedeemRequest(0, address(node)), 0);

        // assert node not tracking and more async assets
        assertEq(testRouter.getErc7540Assets(address(node), address(cfgLiquidityPool)), 0);

        // assert node now has total assets == initial deposit after rounding
        assertApproxEqAbs(node.totalAssets(), 100 ether, 1);
    }
}
