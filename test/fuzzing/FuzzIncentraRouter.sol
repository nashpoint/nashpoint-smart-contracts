// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsIncentraRouter.sol";
import "./helpers/postconditions/PostconditionsIncentraRouter.sol";

import {IncentraRouter} from "../../src/routers/IncentraRouter.sol";

contract FuzzIncentraRouter is PreconditionsIncentraRouter, PostconditionsIncentraRouter {
    function fuzz_incentra_claim(uint256 amountSeed, uint256 epochSeed, uint256 proofSeed) public {
        _forceActor(rebalancer, amountSeed);
        IncentraClaimParams memory params = incentraClaimPreconditions(amountSeed, epochSeed, proofSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerIncentra),
            abi.encodeWithSelector(IncentraRouter.claim.selector, address(node), params.campaignAddrs, params.rewards),
            currentActor
        );

        incentraClaimPostconditions(success, returnData, params);
    }
}
