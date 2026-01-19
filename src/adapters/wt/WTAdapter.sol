// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WTEventVerifier} from "src/adapters/wt/WTEventVerifier.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";

/**
 * @title WisdomTree Adapter
 * @notice ERC7540-compatible adapter for Wisdom Tree Funds interactions
 */
contract WTAdapter is AdapterBase {
    using SafeERC20 for IERC20;

    // =============================
    //         Custom State
    // =============================

    /// @notice WisdomTree EventVerifier
    WTEventVerifier public immutable eventVerifier;

    /// @notice WT address receiving assets and funds from this adapter
    address public immutable receiverAddress;

    /// @notice Address sending asset on redemption to this adapter
    address public immutable senderAddress;

    // =============================
    //         Constructor
    // =============================

    /**
     * @notice Constructor for Adapter
     * @dev Sets up immutable dependencies
     * @param registry_ Address of the registry contract for access control
     * @param receiverAddress_ WT address receiving assets and funds from this adapter
     * @param senderAddress_ Address sending asset on redemption to this adapter
     * @param eventVerifier_ Address of the WT EventVerifier contract
     */
    constructor(address registry_, address receiverAddress_, address senderAddress_, WTEventVerifier eventVerifier_)
        AdapterBase(registry_)
    {
        receiverAddress = receiverAddress_;
        senderAddress = senderAddress_;
        eventVerifier = eventVerifier_;
    }

    // =============================
    //         Admin Functions
    // =============================

    function _verifySettleDeposit(EventVerifierBase.OffchainArgs calldata verifyArgs)
        internal
        override
        returns (uint256 shares, uint256 assets)
    {
        // fund shares are minted, therefore "from" in Transfer event should be address zero
        shares = eventVerifier.verifySettlementEvent(verifyArgs, WTEventVerifier.OnchainArgs(fund, address(0)));
    }

    function _verifySettleRedeem(EventVerifierBase.OffchainArgs calldata verifyArgs)
        internal
        override
        returns (uint256 shares, uint256 assets)
    {
        // assets are coming from WT Wallet
        assets = eventVerifier.verifySettlementEvent(verifyArgs, WTEventVerifier.OnchainArgs(asset, senderAddress));
    }

    function _fundDeposit(uint256 pendingAssets) internal override {
        IERC20(asset).safeTransfer(receiverAddress, pendingAssets);
    }

    function _fundRedeem(uint256 pendingShares) internal override {
        IERC20(fund).safeTransfer(receiverAddress, pendingShares);
    }
}
