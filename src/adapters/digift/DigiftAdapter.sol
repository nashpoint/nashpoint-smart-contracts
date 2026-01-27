// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISubRedManagement} from "src/interfaces/external/IDigift.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";

/**
 * @title DigiftAdapter
 * @author ODND Studios
 * @notice ERC7540-compatible adapter for Digift stToken operations
 */
contract DigiftAdapter is AdapterBase {
    using SafeERC20 for IERC20;

    // =============================
    //         Custom State
    // =============================

    /// @notice Digift subscription/redemption management contract
    ISubRedManagement public immutable subRedManagement;

    /// @notice Digift event verifier for settlement validation
    DigiftEventVerifier public immutable digiftEventVerifier;

    // =============================
    //         Constructor
    // =============================

    /**
     * @notice Constructor for Adapter
     * @dev Sets up immutable dependencies
     * @param registry_ Address of the registry contract for access control
     * @param subRedManagement_ Address of the Digift subscription/redemption management contract
     * @param digiftEventVerifier_ Address of the Digift event verifier contract
     */
    constructor(address registry_, address subRedManagement_, address digiftEventVerifier_) AdapterBase(registry_) {
        subRedManagement = ISubRedManagement(subRedManagement_);
        digiftEventVerifier = DigiftEventVerifier(digiftEventVerifier_);
    }

    function _initialize(bytes memory) internal override {}

    // =============================
    //         Overrides
    // =============================

    /**
     * @inheritdoc AdapterBase
     */
    function _verifySettleDeposit(EventVerifierBase.OffchainArgs calldata verifyArgs)
        internal
        override
        returns (uint256 shares, uint256 assets)
    {
        (shares, assets) = digiftEventVerifier.verifySettlementEvent(
            verifyArgs,
            DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.SUBSCRIBE, address(subRedManagement), fund, asset
            )
        );
    }

    /**
     * @inheritdoc AdapterBase
     */
    function _verifySettleRedeem(EventVerifierBase.OffchainArgs calldata verifyArgs)
        internal
        override
        returns (uint256 shares, uint256 assets)
    {
        (shares, assets) = digiftEventVerifier.verifySettlementEvent(
            verifyArgs,
            DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), fund, asset
            )
        );
    }

    /**
     * @inheritdoc AdapterBase
     */
    function _fundDeposit(uint256 pendingAssets) internal override {
        IERC20(asset).safeIncreaseAllowance(address(subRedManagement), pendingAssets);
        subRedManagement.subscribe(fund, asset, pendingAssets, block.timestamp + 1);
    }

    /**
     * @inheritdoc AdapterBase
     */
    function _fundRedeem(uint256 pendingShares) internal override {
        IERC20(fund).safeIncreaseAllowance(address(subRedManagement), pendingShares);
        subRedManagement.redeem(fund, asset, pendingShares, block.timestamp + 1);
    }
}
