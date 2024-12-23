// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IERC7540} from "../interfaces/IERC7540.sol";
import {IERC7575} from "../interfaces/IERC7575.sol";
import {INode} from "../interfaces/INode.sol";
import {IQuoterV1, IQuoter} from "../interfaces/IQuoterV1.sol";

import {BaseQuoter} from "../libraries/BaseQuoter.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

// todo: remove after testing
import {console2} from "forge-std/Test.sol";

/// @title QuoterV1
/// @author ODND Studios
contract QuoterV1 is IQuoterV1, BaseQuoter {
    using MathLib for uint256;

    /* CONSTANTS */
    // uint8 internal constant PRICE_DECIMALS = 18;
    // Constants
    int256 public constant SCALING_FACTOR = -5e18;
    uint256 public constant WAD = 1e18;

    /* STORAGE */
    mapping(address => bool) public isErc4626;
    mapping(address => bool) public isErc7540;
    bool public isInitialized;

    /* CONSTRUCTOR */
    constructor(address registry_) BaseQuoter(registry_) {}

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc IQuoterV1
    function initialize(address[] memory erc4626Components_, address[] memory erc7540Components_)
        external
        onlyRegistryOwner
    {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();

        uint256 erc4626ComponentsLength = erc4626Components_.length;
        for (uint256 i = 0; i < erc4626ComponentsLength; i++) {
            isErc4626[erc4626Components_[i]] = true;
        }

        uint256 erc7540ComponentsLength = erc7540Components_.length;
        for (uint256 i = 0; i < erc7540ComponentsLength; i++) {
            isErc7540[erc7540Components_[i]] = true;
        }

        isInitialized = true;
    }

    /// @inheritdoc IQuoterV1
    function setErc4626(address component, bool value) external onlyRegistryOwner {
        isErc4626[component] = value;
    }

    /// @inheritdoc IQuoterV1
    function setErc7540(address component, bool value) external onlyRegistryOwner {
        isErc7540[component] = value;
    }

    /// @inheritdoc IQuoter
    function getTotalAssets(address node) external view onlyValidNode(node) returns (uint256) {
        return _getTotalAssets(node);
    }

    function getErc7540Assets(address node, address component) external view returns (uint256) {
        return _getErc7540Assets(node, component);
    }

    /* INTERNAL FUNCTIONS */
    function _getErc4626Assets(address node, address component) internal view returns (uint256) {
        uint256 balance = IERC4626(component).balanceOf(node);
        if (balance == 0) return 0;
        return IERC4626(component).convertToAssets(balance);
    }

    function _getErc7540Assets(address node, address component) internal view returns (uint256) {
        uint256 assets;
        address shareToken = IERC7575(component).share();
        uint256 shareBalance = IERC20(shareToken).balanceOf(node);

        if (shareBalance > 0) {
            assets = IERC4626(component).convertToAssets(shareBalance);
        }
        /// @dev in ERC7540 deposits are denominated in assets and redeems are in shares
        assets += IERC7540(component).pendingDepositRequest(0, node);
        assets += IERC7540(component).claimableDepositRequest(0, node);
        assets += IERC4626(component).convertToAssets(IERC7540(component).pendingRedeemRequest(0, node));
        assets += IERC4626(component).convertToAssets(IERC7540(component).claimableRedeemRequest(0, node));

        return assets;
    }

    function _getTotalAssets(address node) internal view returns (uint256) {
        uint256 reserveAssets = IERC20(INode(node).asset()).balanceOf(node);

        uint256 componentAssets;
        address[] memory components = INode(node).getComponents();
        uint256 componentsLength = components.length;

        for (uint256 i = 0; i < componentsLength; i++) {
            if (isErc4626[components[i]]) {
                componentAssets += _getErc4626Assets(node, components[i]);
            } else if (isErc7540[components[i]]) {
                componentAssets += _getErc7540Assets(node, components[i]);
            } else {
                revert ErrorsLib.InvalidComponent();
            }
        }

        return reserveAssets + componentAssets;
    }

    function calculateDeposit(address asset, uint256 assets, uint256 targetReserveRatio, uint256 maxSwingFactor)
        external
        view
        onlyValidNode(msg.sender)
        returns (uint256)
    {
        uint256 reserveCash = IERC20(asset).balanceOf(address(msg.sender));
        int256 reserveImpact =
            int256(calculateReserveImpact(targetReserveRatio, reserveCash, IERC7575(msg.sender).totalAssets(), assets));

        // Adjust the deposited assets based on the swing pricing factor.
        uint256 adjustedAssets =
            MathLib.mulDiv(assets, (WAD + getSwingFactor(reserveImpact, maxSwingFactor, targetReserveRatio)), WAD);

        // Calculate the number of shares to mint based on the adjusted assets.
        uint256 sharesToMint = IERC7575(msg.sender).convertToShares(adjustedAssets);
        return (sharesToMint);
    }

    function getAdjustedAssets(
        address asset,
        uint256 sharesExiting,
        uint256 shares,
        uint256 maxSwingFactor,
        uint256 targetReserveRatio,
        bool swingPricingEnabled
    ) external view onlyValidNode(msg.sender) returns (uint256 adjustedAssets) {
        // get the cash balance of the node and pending redemptions
        uint256 balance = IERC20(asset).balanceOf(address(msg.sender));
        uint256 pendingRedemptions = IERC7575(msg.sender).convertToAssets(sharesExiting);

        // check if pending redemptions exceed current cash balance
        // if not subtract pending redemptions from balance
        if (pendingRedemptions > balance) {
            balance = 0;
        } else {
            balance = balance - pendingRedemptions;
        }

        // get the asset value of the redeem request
        uint256 assets = IERC7575(msg.sender).convertToAssets(shares);

        // gets the expected reserve ratio after tx
        // check redemption (assets) exceed current cash balance
        // if not get reserve ratio
        int256 reserveRatioAfterTX;
        if (assets > balance) {
            reserveRatioAfterTX = 0;
        } else {
            reserveRatioAfterTX =
                int256(MathLib.mulDiv(balance - assets, WAD, IERC7575(msg.sender).totalAssets() - assets));
        }

        if (swingPricingEnabled) {
            adjustedAssets = MathLib.mulDiv(
                assets, (WAD - getSwingFactor(reserveRatioAfterTX, maxSwingFactor, targetReserveRatio)), WAD
            );
        } else {
            adjustedAssets = assets;
        }
        return adjustedAssets;
    }

    function calculateReserveImpact(
        uint256 targetReserveRatio,
        uint256 reserveCash,
        uint256 totalAssets,
        uint256 deposit
    ) public pure returns (int256) {
        console2.log("targetReserveRatio: ", targetReserveRatio / 1e16);
        console2.log("reserveCash: ", reserveCash / 1e18);
        console2.log("totalAssets: ", totalAssets / 1e18);
        console2.log("deposit: ", deposit / 1e18);

        // get current reserve ratio
        uint256 currentReserveRatio = MathLib.mulDiv(reserveCash, WAD, totalAssets);
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
        uint256 targetTotalAssets = MathLib.mulDiv(investedAssets, WAD, WAD - targetReserveRatio);
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
        uint256 deltaClosedPct = MathLib.mulDiv(deltaClosed, WAD, targetReserve);
        console2.log("deltaClosdPct :", deltaClosedPct / 1e16, "%");

        // Reserve Impact
        // reserveImpact is the inverse of the percentage of the reserve delta closed by the deposit
        // As deltaClosedPct increases to 100% this number reaches zero
        // It is multiplied by the targetReserveRatio to cancel out this in the denominator in the swing factor equation
        // todo: find a way to create the same number in less steps and simpler

        uint256 reserveImpact = MathLib.mulDiv(WAD - deltaClosedPct, targetReserveRatio, WAD);
        console2.log("reserveImpact : ", reserveImpact / 1e16);

        return int256(reserveImpact);
    }

    function getSwingFactor(int256 reserveImpact, uint256 maxSwingFactor, uint256 targetReserveRatio)
        public
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

            SD59x18 result = sd(int256(maxSwingFactor))
                * exp(sd(SCALING_FACTOR).mul(reserveImpactSd).div(sd(int256(targetReserveRatio))));

            return uint256(result.unwrap());
        }
    }
}
