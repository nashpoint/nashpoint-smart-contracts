// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsMerklRouter.sol";
import "./helpers/postconditions/PostconditionsMerklRouter.sol";

import {MerklRouter} from "../../src/routers/MerklRouter.sol";

contract FuzzMerklRouter is PreconditionsMerklRouter, PostconditionsMerklRouter {
    function fuzz_merkl_claim(uint256 amountSeed, uint256 proofSeed) public {
        _forceActor(rebalancer, amountSeed);
        MerklClaimParams memory params = merklClaimPreconditions(amountSeed, proofSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerMerkl),
            abi.encodeWithSelector(
                MerklRouter.claim.selector, address(node), params.tokens, params.amounts, params.proofs
            ),
            currentActor
        );

        merklClaimPostconditions(success, returnData, params);
    }
}
