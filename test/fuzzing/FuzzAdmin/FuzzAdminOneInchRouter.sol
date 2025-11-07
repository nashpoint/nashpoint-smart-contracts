// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/Preconditions/PreconditionsOneInch.sol";
import "../helpers/Postconditions/PostconditionsOneInch.sol";

contract FuzzAdminOneInchRouter is PreconditionsOneInch, PostconditionsOneInch {
    /**
     * @notice Fuzz handler for OneInch router swap
     * @dev Exercises:
     *      - src/routers/OneInchV6RouterV1.sol:111 swap function
     *      - src/routers/OneInchV6RouterV1.sol:151 _subtractExecutionFee
     *      - Validates incentive/executor whitelisting
     *      - Tests swap with proper calldata encoding
     * @param seed Used to generate test parameters
     */
    function fuzz_admin_oneinch_swap(uint256 seed) public {
        forceActor(rebalancer, seed);

        OneInchSwapParams memory params = oneInchSwapPreconditions(seed);

        if (!params.shouldSucceed) {
            return;
        }

        address[] memory actors = new address[](2);
        actors[0] = address(node);
        actors[1] = params.executor;
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerOneInch),
            abi.encodeWithSelector(
                routerOneInch.swap.selector,
                address(node),
                params.incentive,
                params.incentiveAmount,
                params.minAssetsOut,
                params.executor,
                params.swapCalldata
            ),
            currentActor
        );

        oneInchSwapPostconditions(success, returnData, actors, params);
    }
}
