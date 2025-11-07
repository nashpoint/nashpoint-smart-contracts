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

        // 1) User deposits to obtain shares.
        setActor(controller);
        fuzz_deposit(depositSeed);

        // 2) User requests redeem so shares become pending.
        setActor(controller);
        fuzz_requestRedeem(redeemSeed);

        // // 3) Ensure the node has enough reserve to fulfill the redeem.
        // _ensureNodeReserveForGuidedWithdraw(controller);

        // 4) Rebalancer opens a new rebalance window (cooldown + cache expiry).
        _prepareRebalanceWindowForGuidedWithdraw();
        setActor(rebalancer);
        fuzz_admin_node_startRebalance(1); // seed=1 → caller is rebalancer

        // 5) Rebalancer fulfills the pending redeem from reserves, producing claimable assets.
        setActor(rebalancer);
        fuzz_admin_node_fulfillRedeem(userSeed);

        // 6) Controller withdraws the claimable assets.
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
        (,,, uint256 sharesAdjusted) = node.requests(controller);
        if (sharesAdjusted == 0) {
            return;
        }

        uint256 assetsNeeded = node.convertToAssets(sharesAdjusted);
        uint256 reserveBalance = asset.balanceOf(address(node));
        if (reserveBalance >= assetsNeeded) {
            return;
        }

        uint256 donationAmount = assetsNeeded - reserveBalance;
        setActor(owner);
        fuzz_donate(0, _donateeIndexForNode(address(node)), donationAmount);
    }
}
