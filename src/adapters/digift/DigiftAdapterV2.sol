// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DigiftAdapter} from "src/adapters/digift/DigiftAdapter.sol";

/**
 * @title DigiftAdapterV2
 * @author ODND Studios
 * @notice Drop-in beacon implementation upgrade for {DigiftAdapter}
 * @dev Adds a recovery path for a forwarded deposit that DigiFT refunded out-of-band.
 *
 *      Background: a deposit is forwarded to DigiFT via {forwardRequests} -> subscribe(), which
 *      moves the asset into DigiFT's SubRedManagement and sets the global/per-node
 *      `pendingDepositRequest`. The position can normally only be cleared by {settleDeposit},
 *      which requires a canonical `SettleSubscriber` event proven by the DigiftEventVerifier.
 *
 *      If DigiFT instead returns the asset to this adapter through a non-standard transfer
 *      (no `SettleSubscriber` event), {settleDeposit} can never verify it: the asset is stranded
 *      in the adapter and `pendingDepositRequest` stays jammed (blocking {forwardRequests}).
 *
 *      {settleDepositRefund} resolves exactly this case: it clears the node's pending deposit,
 *      decrements the global pending deposit, and returns the refunded asset to the node — without
 *      minting shares (DigiFT issued none). The router values the pending deposit as node assets
 *      (see ERC7540Router._getErc7540Assets), so returning the same amount as cash keeps node NAV
 *      unchanged.
 *
 * @dev Storage layout is inherited unchanged from {DigiftAdapter}/{AdapterBase}; no new state is
 *      introduced, so this is a safe beacon upgrade.
 */
contract DigiftAdapterV2 is DigiftAdapter {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a stranded forwarded deposit is refunded to a node
    /// @param node The node receiving the refunded assets
    /// @param assets The amount of asset tokens returned to the node
    event DepositRefunded(address indexed node, uint256 assets);

    /**
     * @notice Constructor mirrors {DigiftAdapter}; immutables live in implementation bytecode
     * @param registry_ Address of the registry contract for access control
     * @param subRedManagement_ Address of the Digift subscription/redemption management contract
     * @param digiftEventVerifier_ Address of the Digift event verifier contract
     */
    constructor(address registry_, address subRedManagement_, address digiftEventVerifier_)
        DigiftAdapter(registry_, subRedManagement_, digiftEventVerifier_)
    {}

    /**
     * @notice Refund a forwarded deposit that DigiFT returned without a canonical settlement event
     * @dev Clears the node's pending deposit, decrements the global pending deposit, and transfers
     *      the refunded asset back to the node. No shares are minted.
     * @dev Only callable by the registry owner because it bypasses cryptographic event verification.
     * @param node The node whose forwarded deposit was refunded by DigiFT
     * @return assets The amount of asset tokens returned to the node
     */
    function settleDepositRefund(address node) external nonReentrant onlyRegistryOwner returns (uint256 assets) {
        assets = _nodeState[node].pendingDepositRequest;
        require(assets > 0, NoPendingDepositRequest(node));
        require(_globalState.pendingDepositRequest >= assets, NothingToSettle());

        _nodeState[node].pendingDepositRequest = 0;
        _globalState.pendingDepositRequest -= assets;

        IERC20(asset).safeTransfer(node, assets);

        emit DepositRefunded(node, assets);
    }
}
