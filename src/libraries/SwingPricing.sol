// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

// temp
import {console2} from "forge-std/Test.sol";

/// @title SwingPricing
/// @notice Library for calculating swing pricing.
library SwingPricing {
    // Constants
    int256 public constant SCALING_FACTOR = -5e18;
    uint256 public constant WAD = 1e18;

    function calculateReserveImpact(
        uint256 targetReserveRatio,
        uint256 reserveCash,
        uint256 totalAssets,
        uint256 deposit
    ) internal pure returns (int256) {
        // note: do happy path first then edge cases at each step

        console2.log("targetReserveRatio: ", targetReserveRatio / 1e16);
        console2.log("reserveCash: ", reserveCash / 1e18);
        console2.log("totalAssets: ", totalAssets / 1e18);
        console2.log("deposit: ", deposit / 1e18);

        // get current reserve ratio
        uint256 currentReserveRatio = Math.mulDiv(reserveCash, WAD, totalAssets);
        console2.log("currentReserveRatio: ", currentReserveRatio / 1e16);

        // returns zero if targetReserveRatio is already reached
        if (currentReserveRatio >= targetReserveRatio) {
            return 0;
        }

        // get delta between current and target in percentage terms
        // note might not need this one
        // uint256 reserveDeltaPct = targetReserveRatio - currentReserveRatio;
        // console2.log("reserveDelta: ", reserveDeltaPct / 1e16);

        // get investedAssets by subtracting reserve cash balance
        uint256 investedAssets = totalAssets - reserveCash;
        console2.log("investedAssets: ", investedAssets / 1e18);

        // get targetTotalAssets (investedAssets + 100% reserve)
        uint256 targetTotalAssets = Math.mulDiv(investedAssets, WAD, WAD - targetReserveRatio);
        console2.log("targetTotalAssets: ", targetTotalAssets / 1e18);

        // get target reserve holdings where reserve ratio = 100%
        uint256 targetReserve = targetTotalAssets - investedAssets;
        console2.log("maxPossibleDelta: ", targetReserve / 1e18);

        // get delta between current and ideal reserve in unit terms
        uint256 reserveDelta = 0;
        if (reserveCash < targetReserve) {
            reserveDelta = targetReserve - reserveCash;
        }
        console2.log("reserveDelta: ", reserveDelta / 1e18);

        // get what the reserve delta will be after the deposit
        // if deposit will exceed the delta this returns 0
        uint256 deltaAfter = 0;
        if (reserveDelta > deposit) {
            deltaAfter = reserveDelta - deposit;
        }
        console2.log("deltaAfter: ", deltaAfter / 1e18);

        // get the units of the delta closed by by subtracting delta after deposit from delta before deposit
        uint256 deltaClosed = reserveDelta - deltaAfter;
        console2.log("deltaClosed :", deltaClosed / 1e18);

        // get this is percentage terms by dividing delta closed (units) by the target reserve (units)
        uint256 deltaClosedPct = Math.mulDiv(deltaClosed, WAD, targetReserve);
        console2.log("deltaClosdPct :", deltaClosedPct / 1e16, "%");

        // Reserve Impact
        // reserveImpact is the inverse of the percentage of the reserve delta closed by the deposit
        // As deltaClosedPct increases to 100% this number reaches zero
        // It is multiplied by the targetReserveRatio to cancel out this in the denominator in the swing factor equation
        // todo: find a way to create the same number in less steps and simpler

        uint256 reserveImpact = Math.mulDiv(WAD - deltaClosedPct, targetReserveRatio, WAD);
        console2.log("reserveImpact : ", reserveImpact / 1e16);

        return int256(reserveImpact);
    }
}
