// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IERC7540} from "../interfaces/IERC7540.sol";
import {IERC7575} from "../interfaces/IERC7575.sol";
import {INode} from "../interfaces/INode.sol";
import {IQuoterV1} from "../interfaces/IQuoterV1.sol";
import {IRouter} from "../interfaces/IRouter.sol";

import {BaseQuoter} from "../libraries/BaseQuoter.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

/// @title QuoterV1
/// @author ODND Studios
contract QuoterV1 is IQuoterV1, BaseQuoter {
    using MathLib for uint256;

    /* CONSTANTS */
    int256 internal constant SCALING_FACTOR = -5e18;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant REQUEST_ID = 0;
    uint64 internal constant SWING_FACTOR_DENOMINATOR = 2;

    /* STATE */
    mapping(address => bool) public isErc4626;
    mapping(address => bool) public isErc7540;
    bool public isInitialized;

    /* CONSTRUCTOR */
    constructor(address registry_) BaseQuoter(registry_) {}

    /*//////////////////////////////////////////////////////////////
                        SWING PRICING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by Node Contract to calculate the deposit bonus
    /// reserveImpact is the inverse of the percentage of the reserve assets shortfall closed by the deposit
    /// The majority of logic is in _calculateReserveImpact and _getSwingFactor

    /// @param assets The amount of assets being deposited
    /// @param reserveCash The reserve cash of the Node
    /// @param totalAssets The total assets of the Node
    /// @param maxSwingFactor The maximum swing factor to apply
    /// @param targetReserveRatio The target reserve ratio to calculate the swing factor against
    /// @return shares The shares to mint after applying the deposit bonus
    function calculateDepositBonus(
        uint256 assets,
        uint256 reserveCash,
        uint256 totalAssets,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external view onlyValidNode(msg.sender) onlyValidQuoter(msg.sender) returns (uint256 shares) {
        int256 reserveImpact = int256(_calculateReserveImpact(targetReserveRatio, reserveCash, totalAssets, assets));

        // reduce maxSwingFactor by half
        maxSwingFactor = maxSwingFactor / SWING_FACTOR_DENOMINATOR;

        // Adjust the deposited assets based on the swing pricing factor.
        uint256 adjustedAssets =
            MathLib.mulDiv(assets, (WAD + _getSwingFactor(reserveImpact, maxSwingFactor, targetReserveRatio)), WAD);

        // Calculate the number of shares to mint based on the adjusted assets.
        shares = IERC7575(msg.sender).convertToShares(adjustedAssets);
        return shares;
    }

    /// @dev Called by Node Contract to calculate the withdrawal penalty for redeem requests
    /// reserveImpact is the cash balance of the node after the redeem request is processed
    /// adjustedAssets is the value of the redeem request with withdrawal penalty applied based on impact on cash reserve
    /// Uses sharesExiting to track redeem request currently pending for redemption and subtracts them from cash balance
    /// This is to prevent a situation where requests are pending for withdrawal but no swing pricing penalty is being applied
    /// to new requests
    /// @param shares The shares being redeemed
    /// @param reserveCash The reserve cash of the Node
    /// @param totalAssets The total assets of the Node
    /// @param maxSwingFactor The maximum swing factor to apply
    /// @param targetReserveRatio The target reserve ratio to calculate the swing factor against
    /// @return assets The assets to redeem after applying the redeem penalty
    function calculateRedeemPenalty(
        uint256 shares,
        uint256 reserveCash,
        uint256 totalAssets,
        uint64 maxSwingFactor,
        uint64 targetReserveRatio
    ) external view onlyValidNode(msg.sender) onlyValidQuoter(msg.sender) returns (uint256 assets) {
        // get the asset value of the redeem request
        assets = IERC7575(msg.sender).convertToAssets(shares);

        // gets the expected reserve ratio after tx
        // check redemption (assets) exceed current cash balance
        // if not get reserve ratio
        int256 reserveImpact;
        if (assets >= reserveCash) {
            reserveImpact = 0;
        } else {
            reserveImpact = int256(MathLib.mulDiv(reserveCash - assets, WAD, totalAssets - assets));
        }

        assets = MathLib.mulDiv(assets, (WAD - _getSwingFactor(reserveImpact, maxSwingFactor, targetReserveRatio)), WAD);
        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Reserve Impact is used to calculate the swing factor (bonus) for deposits
    /// It is the inverse of the percentage of the reserve assets shortfall closed by the deposit
    /// The inverse is used because the lower the value returned here, the greater the applied bonus
    /// @param targetReserveRatio The target reserve ratio to calculate the swing factor against
    /// @param reserveCash The current cash balance of the node
    /// @param totalAssets The total assets of the node
    /// @param deposit The amount of assets being deposited
    /// @return reserveImpact The reserve impact of the deposit
    function _calculateReserveImpact(
        uint64 targetReserveRatio,
        uint256 reserveCash,
        uint256 totalAssets,
        uint256 deposit
    ) internal pure returns (int256) {
        // get the required assets in unit terms where actual reserve ratio = target reserve ratio
        uint256 investedAssets = totalAssets - reserveCash;
        uint256 targetReserveAssets = MathLib.mulDiv(investedAssets, targetReserveRatio, WAD - targetReserveRatio);

        // get size of reserve delta closed in unit terms by returning the min of deposit and asset shortfall
        // if we don't take the min then we could overpay the deposit bonus
        uint256 deltaClosed;
        if (reserveCash >= targetReserveAssets) {
            deltaClosed = 0;
        } else {
            uint256 shortfall = targetReserveAssets - reserveCash;
            deltaClosed = MathLib.min(deposit, shortfall);
        }

        // get delta closed in percentage terms by dividing delta closed by target reserve assets
        uint256 deltaClosedPct = MathLib.mulDiv(deltaClosed, WAD, targetReserveAssets);

        // Get reserveImpact as a measure of how much the deposit helps to close any asset shortfall
        // As deltaClosedPct increases to 100% this number reaches zero
        // It is multiplied by the targetReserveRatio to cancel out this in the denominator in the swing factor equation
        uint256 reserveImpact = MathLib.mulDiv(WAD - deltaClosedPct, targetReserveRatio, WAD);
        return int256(reserveImpact);
    }

    /// @dev Calculates the swing factor based on the reserve impact, max swing factor, and target reserve ratio
    /// uses PRB Math to calculate the swing factor
    /// Equation: swingFactor = maxSwingFactor * exp(SCALING_FACTOR * reserveImpact / targetReserveRatio)
    /// @param reserveImpact The reserve impact of the deposit
    /// @param maxSwingFactor The maximum swing factor to apply
    /// @param targetReserveRatio The target reserve ratio to calculate the swing factor against
    /// @return swingFactor The swing factor to apply
    function _getSwingFactor(int256 reserveImpact, uint64 maxSwingFactor, uint64 targetReserveRatio)
        internal
        pure
        returns (uint256 swingFactor)
    {
        // checks if a negative number
        if (reserveImpact < 0) {
            revert ErrorsLib.InvalidInput(reserveImpact);

            // else if reserve exceeds target after deposit no swing factor is applied
        } else if (uint256(reserveImpact) >= targetReserveRatio) {
            return 0;

            // else swing factor is applied
        } else {
            SD59x18 reserveImpactSd = sd(int256(reserveImpact));

            SD59x18 result = sd(int256(uint256(maxSwingFactor)))
                * exp(sd(SCALING_FACTOR).mul(reserveImpactSd).div(sd(int256(uint256(targetReserveRatio)))));

            return uint256(result.unwrap());
        }
    }
}
