// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzNodeAdmin.sol";
import "./FuzzDonate.sol";
import "./FuzzDigiftAdapter.sol";
import "./FuzzDigiftAdapterFactory.sol";
import "./FuzzDigiftEventVerifier.sol";
import "./FuzzERC4626Router.sol";
import "./FuzzERC7540Router.sol";
import "./FuzzFluidRewardsRouter.sol";
import "./FuzzIncentraRouter.sol";
import "./FuzzMerklRouter.sol";
import "./FuzzOneInchRouter.sol";
import "./FuzzNodeFactory.sol";
import "./FuzzNodeRegistry.sol";

/**
 * @title FuzzGuided
 * @notice Provides composite flows that help the fuzzer reach deeper Node states
 */
contract FuzzGuided is
    FuzzNodeAdmin,
    FuzzDonate,
    FuzzDigiftAdapter,
    FuzzDigiftAdapterFactory,
    FuzzDigiftEventVerifier,
    FuzzERC4626Router,
    FuzzERC7540Router,
    FuzzFluidRewardsRouter,
    FuzzIncentraRouter,
    FuzzMerklRouter,
    FuzzOneInchRouter,
    FuzzNodeFactory,
    FuzzNodeRegistry
{
    function fuzz_guided_deposit_then_request(uint256 depositSeed, uint256 redeemSeed) public {
        fuzz_deposit(depositSeed);
        fuzz_requestRedeem(redeemSeed);
    }

    function fuzz_guided_request_then_fulfill(uint256 userSeed, uint256 redeemSeed) public {
        fuzz_requestRedeem(redeemSeed);
        fuzz_fulfillRedeem(userSeed);
    }

    function fuzz_guided_full_withdraw_cycle(
        uint256 depositSeed,
        uint256 redeemSeed,
        uint256 fulfillSeed,
        uint256 withdrawSeed
    ) public {
        fuzz_deposit(depositSeed);
        fuzz_requestRedeem(redeemSeed);
        fuzz_fulfillRedeem(fulfillSeed);
        fuzz_withdraw(fulfillSeed, withdrawSeed);
    }
}
