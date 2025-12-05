// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Properties_ERR.sol";

contract Properties_Digift is Properties_ERR {
    // ==============================================================
    // DIGIFT ADAPTER INVARIANTS
    // ==============================================================

    function invariant_DIGIFT_01(uint256 globalPendingDeposit, uint256 forwardedDeposits) internal {
        fl.eq(globalPendingDeposit, forwardedDeposits, DIGIFT_01);
    }

    function invariant_DIGIFT_02(uint256 globalPendingRedeem, uint256 forwardedRedemptions) internal {
        fl.eq(globalPendingRedeem, forwardedRedemptions, DIGIFT_02);
    }

    function invariant_DIGIFT_03(uint256 remainingPending) internal {
        // Settle deposit flow: no mintable shares remains unprocessed
        fl.eq(remainingPending, 0, DIGIFT_03);
    }

    function invariant_DIGIFT_04(uint256 remainingPending) internal {
        // Settle redeem flow: no pending remains unprocessed
        fl.eq(remainingPending, 0, DIGIFT_04);
    }

}
