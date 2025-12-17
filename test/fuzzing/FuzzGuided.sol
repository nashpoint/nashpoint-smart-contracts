// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzNode.sol";
import "./FuzzDonate.sol";
import "./FuzzDigiftAdapter.sol";
import "./FuzzNodeFactory.sol";
import "./FuzzAdmin/FuzzAdminNode.sol";
import "./FuzzAdmin/FuzzAdminDigiftAdapter.sol";
import "./FuzzRewardRouters.sol";
import {Node} from "../../src/Node.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FuzzGuided
 * @notice Provides composite flows that help the fuzzer reach deeper Node states
 * @dev Updated to only import remaining user-facing fuzz contracts
 *      Admin contracts moved to FuzzAdmin/ folder
 *      Router and other internal-only contracts deleted
 */
contract FuzzGuided is
    FuzzNode,
    FuzzAdminNode,
    FuzzDonate,
    FuzzDigiftAdapter,
    FuzzAdminDigiftAdapter,
    FuzzNodeFactory,
    FuzzRewardRouters
{
    /**
     * @notice Builds a full withdraw flow using only single-call handlers:
     *         deposit → requestRedeem → donate (if needed) → startRebalance → fulfillRedeemFromReserve → withdraw.
     */
    function fuzz_guided_node_withdraw(uint256 userSeed, uint256 depositSeed, uint256 redeemSeed, uint256 withdrawSeed)
        public
    {
        uint256 userIndex = userSeed % USERS.length;
        address controller = USERS[userIndex];
        uint256 fulfillSeed = userSeed;
        uint256 usersLen = USERS.length;
        if (usersLen == 0) {
            return;
        }
        while (fulfillSeed % 10 == 0) {
            fulfillSeed += usersLen;
        }

        // Use depositSeed as a configurable reserve top-up to guarantee fulfill succeeds.
        uint256 reserveTopUp = depositSeed > 0 ? depositSeed * 1_000 : 1_000_000e18;
        redeemSeed; // retained for signature compatibility
        assetToken.mint(address(node), reserveTopUp);

        // 1) Rebalancer prepares and fulfills a pending redeem for the chosen controller.
        setActor(rebalancer);
        fuzz_admin_node_fulfillRedeem(fulfillSeed);

        // 2) Controller withdraws newly claimable assets.
        setActor(controller);
        fuzz_withdraw(userIndex, withdrawSeed);
    }

    function _prepareRebalanceWindowForGuidedWithdraw() internal {
        uint256 last = uint256(Node(address(node)).lastRebalance());
        uint256 window = uint256(Node(address(node)).rebalanceWindow());
        uint256 cooldown = uint256(Node(address(node)).rebalanceCooldown());
        uint256 target = last + window + cooldown + 1;
        if (block.timestamp < target) {
            vm.warp(target);
        }
    }

    function _ensureNodeReserveForGuidedWithdraw(address controller) internal {
        (uint256 pending,,) = node.requests(controller);
        if (pending == 0) {
            uint256 shareBalance = node.balanceOf(controller);
            if (shareBalance == 0) {
                return;
            }
            pending = shareBalance;
        }

        uint256 assetsNeeded = node.convertToAssets(pending);
        if (assetsNeeded == 0) {
            assetsNeeded = pending;
        }
        uint256 reserveBalance = asset.balanceOf(address(node));
        if (reserveBalance >= assetsNeeded) {
            return;
        }

        uint256 shortfall = assetsNeeded - reserveBalance;
        assetToken.mint(address(node), shortfall);
    }

    function fuzz_guided_router7540_claimable(uint256 userSeed, uint256 depositSeed) public {
        if (USERS.length == 0) {
            return;
        }

        address controller = USERS[userSeed % USERS.length];
        setActor(controller);
        fuzz_deposit(depositSeed == 0 ? 1 : depositSeed);

        uint256 digiftSeed = _router7540ComponentSeed(address(digiftAdapter));
        if (digiftSeed == type(uint256).max) {
            return;
        }

        setActor(rebalancer);
        fuzz_admin_router7540_invest(digiftSeed);

        setActor(rebalancer);
        fuzz_admin_digift_forwardRequests(1);

        setActor(rebalancer);
        fuzz_admin_digift_settleDeposit(2);

        setActor(rebalancer);
        fuzz_admin_router7540_mintClaimable(digiftSeed);
    }

    function fuzz_guided_router7540_executeAsyncWithdrawal(uint256 userSeed, uint256 depositSeed, uint256 withdrawSeed)
        public
    {
        fuzz_guided_router7540_claimable(userSeed, depositSeed);

        uint256 digiftSeed = _router7540ComponentSeed(address(digiftAdapter));
        if (digiftSeed == type(uint256).max) {
            return;
        }
        uint256 shareBalance = IERC20(address(digiftAdapter)).balanceOf(address(node));
        if (shareBalance == 0) {
            return;
        }

        uint256 sharesSeed = shareBalance > 1 ? shareBalance - 1 : 1;

        setActor(rebalancer);
        fuzz_admin_router7540_requestAsyncWithdrawal(digiftSeed, sharesSeed);

        setActor(rebalancer);
        fuzz_admin_digift_forwardRequests(11);

        setActor(rebalancer);
        uint256 settleSeed = (withdrawSeed | 1) + 6;
        fuzz_admin_digift_settleRedeem(settleSeed);

        setActor(rebalancer);
        fuzz_admin_router7540_executeAsyncWithdrawal(digiftSeed, 0);
    }

    function fuzz_guided_router7540_fulfillRedeem(uint256 controllerSeed, uint256 depositSeed, uint256 redeemSeed)
        public
    {
        if (USERS.length == 0) {
            return;
        }

        address controller = USERS[controllerSeed % USERS.length];
        uint256 depositSeedValue = depositSeed == 0 ? 100e18 : depositSeed;

        setActor(controller);
        fuzz_deposit(depositSeedValue);

        uint256 poolSeed = _router7540ComponentSeed(address(liquidityPool));
        if (poolSeed == type(uint256).max) {
            return;
        }

        setActor(rebalancer);
        fuzz_admin_router7540_invest(poolSeed);

        // Don't setActor - let preconditions use default poolManager
        fuzz_admin_pool_processPendingDeposits(poolSeed);

        setActor(rebalancer);
        fuzz_admin_router7540_mintClaimable(poolSeed);

        setActor(controller);
        fuzz_requestRedeem(redeemSeed == 0 ? 1 : redeemSeed);

        uint256 poolShares = IERC20(address(liquidityPool)).balanceOf(address(node));
        if (poolShares == 0) {
            return;
        }

        uint256 sharesSeed = poolShares > 1 ? poolShares - 1 : 1;

        setActor(rebalancer);
        fuzz_admin_router7540_requestAsyncWithdrawal(poolSeed, sharesSeed);

        // Don't setActor - let preconditions use default poolManager
        fuzz_admin_pool_processPendingRedemptions(poolSeed);

        setActor(rebalancer);
        fuzz_admin_router7540_fulfillRedeemRequest(controllerSeed, poolSeed);
    }

    function fuzz_guided_router7540_partialFulfill(uint256 controllerSeed, uint256 depositSeed, uint256 redeemSeed)
        public
    {
        if (USERS.length == 0) {
            return;
        }

        address controller = USERS[controllerSeed % USERS.length];
        uint256 depositSeedValue = depositSeed == 0 ? 1 : depositSeed;

        setActor(controller);
        fuzz_deposit(depositSeedValue);

        uint256 poolSeed = _router7540ComponentSeed(address(liquidityPool));
        if (poolSeed == type(uint256).max) {
            return;
        }

        setActor(rebalancer);
        fuzz_admin_router7540_invest(poolSeed);

        fuzz_admin_pool_processPendingDeposits(poolSeed);

        setActor(rebalancer);
        fuzz_admin_router7540_mintClaimable(poolSeed);

        uint256 redeemSeedValue = redeemSeed == 0 ? depositSeedValue : redeemSeed;
        setActor(controller);
        fuzz_requestRedeem(redeemSeedValue);

        (uint256 pending,,) = node.requests(controller);
        if (pending <= 1) {
            return;
        }

        setActor(rebalancer);
        // Force a partial scenario by requesting the minimum async withdrawal
        fuzz_admin_router7540_requestAsyncWithdrawal(poolSeed, 0);

        fuzz_admin_pool_processPendingRedemptions(poolSeed);

        setActor(rebalancer);
        fuzz_admin_router7540_fulfillRedeemRequest(controllerSeed, poolSeed);
    }

    function _router7540ComponentSeed(address component) internal view returns (uint256) {
        address[] memory asyncComponents = componentsByRouterForTest(address(router7540));
        for (uint256 i = 0; i < asyncComponents.length; i++) {
            if (asyncComponents[i] == component) {
                return i;
            }
        }
        return type(uint256).max;
    }
}
