// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";

contract Properties_Reward is Properties_ERR {
    // ==============================================================
    // REWARD ROUTER INVARIANTS (Fluid, Incentra, Merkl)
    // ==============================================================

    // Note: The reward router postconditions already use proper assertion patterns
    // with fl.eq and fl.t directly checking mock contract state.
    // These invariants serve as wrappers for consistency.

    function invariant_REWARD_FLUID_01(FluidClaimParams memory params, address recipient) internal {
        fl.eq(recipient, address(node), REWARD_FLUID_01);
    }

    function invariant_REWARD_FLUID_02(FluidClaimParams memory params, uint256 cumulativeAmount) internal {
        fl.eq(cumulativeAmount, params.cumulativeAmount, REWARD_FLUID_02);
    }

    function invariant_REWARD_FLUID_03(FluidClaimParams memory params, bytes32 positionId) internal {
        fl.t(positionId == params.positionId, REWARD_FLUID_03);
    }

    function invariant_REWARD_FLUID_04(FluidClaimParams memory params, uint256 cycle) internal {
        fl.eq(cycle, params.cycle, REWARD_FLUID_04);
    }

    function invariant_REWARD_FLUID_05(FluidClaimParams memory params, bytes32 proofHash) internal {
        fl.t(proofHash == params.proofHash, REWARD_FLUID_05);
    }

    function invariant_REWARD_INCENTRA_01(address lastEarner) internal {
        fl.eq(lastEarner, address(node), REWARD_INCENTRA_01);
    }

    function invariant_REWARD_INCENTRA_02(IncentraClaimParams memory params, bytes32 campaignAddrsHash) internal {
        fl.t(campaignAddrsHash == params.campaignAddrsHash, REWARD_INCENTRA_02);
    }

    function invariant_REWARD_INCENTRA_03(IncentraClaimParams memory params, bytes32 rewardsHash) internal {
        fl.t(rewardsHash == params.rewardsHash, REWARD_INCENTRA_03);
    }

    function invariant_REWARD_MERKL_01(MerklClaimParams memory params, bytes32 usersHash) internal {
        fl.t(usersHash == params.usersHash, REWARD_MERKL_01);
    }

    function invariant_REWARD_MERKL_02(MerklClaimParams memory params, bytes32 tokensHash) internal {
        fl.t(tokensHash == params.tokensHash, REWARD_MERKL_02);
    }

    function invariant_REWARD_MERKL_03(MerklClaimParams memory params, bytes32 amountsHash) internal {
        fl.t(amountsHash == params.amountsHash, REWARD_MERKL_03);
    }

    function invariant_REWARD_MERKL_04(MerklClaimParams memory params, bytes32 proofsHash) internal {
        fl.t(proofsHash == params.proofsHash, REWARD_MERKL_04);
    }
}
