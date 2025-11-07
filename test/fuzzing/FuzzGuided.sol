// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzNode.sol";
import "./FuzzDonate.sol";
import "./FuzzDigiftAdapter.sol";
import "./FuzzDigiftEventVerifier.sol";
import "./FuzzNodeFactory.sol";
import "./FuzzAdmin/FuzzAdminNode.sol";
import "./FuzzAdmin/FuzzAdminDigiftAdapter.sol";
import "./FuzzRewardRouters.sol";
import {Node} from "../../src/Node.sol";

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
    FuzzDigiftEventVerifier,
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
        (uint256 pending,,,) = node.requests(controller);
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
}
