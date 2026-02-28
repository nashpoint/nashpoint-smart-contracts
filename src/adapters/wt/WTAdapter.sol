// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {AdapterBase, NodeState} from "src/adapters/AdapterBase.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

/**
 * @title WisdomTree Adapter
 * @author ODND Studios
 * @notice ERC7540-compatible adapter for Wisdom Tree Funds interactions
 * @dev Ex-dividend operational flow for manual price freeze:
 *      1) Before ex-dividend date, manager updates `lastFundPrice` (for example, via `updateLastPrice`) and calls
 *         `startPriceFreeze` to configure the freeze window.
 *      2) While `priceFreezeActive` is true, `forwardRequests` and `updateLastPrice` are blocked.
 *      3) Price conversions use the current cached `lastFundPrice` only while `block.timestamp <= priceFreezeUntil`.
 *      4) After dividend settlement, manager calls `endPriceFreeze` to unblock operations.
 *      5) Freeze is not auto-cleared on timeout, explicit `endPriceFreeze` is required to resume forwarding/price updates.
 */
contract WTAdapter is AdapterBase, IERC721Receiver {
    using SafeERC20 for IERC20;

    uint64 internal constant MAX_PRICE_FREEZE_DURATION = 7 days;

    // =============================
    //            Errors
    // =============================

    /// @notice Thrown when dividend node list is not strictly sorted ascending (duplicates included)
    error NodesNotStrictlySorted();
    /// @notice Thrown when dividend node list includes the adapter itself
    error AdapterAddressInNodeList();
    /// @notice Thrown when attempting to forwardRequests while one is active
    error PriceFreezeActive();
    /// @notice Thrown when attempting to start a price freeze while one is active
    error PriceFreezeAlreadyActive();
    /// @notice Thrown when attempting to end a price freeze while none is active
    error PriceFreezeNotActive();
    /// @notice Thrown when requested freeze duration is invalid
    error InvalidPriceFreezeDuration(uint256 duration, uint256 maxDuration);

    // =============================
    //         Custom State
    // =============================

    /// @notice Transfer Event Verifier (shared/immutable)
    TransferEventVerifier public immutable eventVerifier;

    /// @notice WT address receiving assets and funds from this adapter
    address public receiverAddress;

    /// @notice Address sending asset on redemption to this adapter
    address public senderAddress;

    /// @notice True if a manual WT price freeze window is configured
    bool public priceFreezeActive;

    /// @notice Timestamp when a configured price freeze window expires
    uint64 public priceFreezeUntil;

    // =============================
    //            Events
    // =============================

    /// @notice Emitted when the configured WT receiver address is updated.
    /// @param previousReceiver Previous receiver address used for WT transfers.
    /// @param newReceiver New receiver address used for WT transfers.
    event ReceiverAddressChange(address indexed previousReceiver, address indexed newReceiver);

    /// @notice Emitted when the configured WT sender address is updated.
    /// @param previousSender Previous sender address expected for redemption transfers.
    /// @param newSender New sender address expected for redemption transfers.
    event SenderAddressChange(address indexed previousSender, address indexed newSender);

    /// @notice Emitted after dividend fund shares are distributed to nodes.
    /// @param fundShares Total dividend fund shares verified for distribution.
    /// @param adapterSharesMinted Total adapter shares minted to nodes for the dividend.
    event DividendSettled(uint256 fundShares, uint256 adapterSharesMinted);

    /// @notice Emitted when a node receives minted shares from a settled dividend.
    /// @param node Node address receiving the dividend shares.
    /// @param sharesOut Amount of adapter shares minted to the node for this dividend settlement.
    event DividendPaid(address indexed node, uint256 sharesOut);

    /// @notice Emitted when a manual price freeze window is started.
    /// @param fundPrice Current cached fund price (`lastFundPrice`) at freeze start.
    /// @param freezeUntil Timestamp when the configured freeze window expires.
    event PriceFreezeStarted(uint256 fundPrice, uint64 freezeUntil);

    /// @notice Emitted when an active manual price freeze is ended.
    event PriceFreezeEnded();

    // =============================
    //         Constructor
    // =============================

    /**
     * @notice Constructor for Adapter
     * @param registry_ Address of the registry contract for access control
     * @param eventVerifier_ Address of the TransferEventVerifier contract (immutable)
     */
    constructor(address registry_, address eventVerifier_) AdapterBase(registry_) {
        eventVerifier = TransferEventVerifier(eventVerifier_);
    }

    function _initialize(bytes memory customInitData) internal override {
        // receiverAddress_ WT address receiving assets and funds from this adapter
        // senderAddress_ Address sending asset on redemption to this adapter
        (address receiverAddress_, address senderAddress_) = abi.decode(customInitData, (address, address));
        receiverAddress = receiverAddress_;
        senderAddress = senderAddress_;
    }

    // =============================
    //         Admin Functions
    // =============================

    /**
     * @notice Update the WT receiver wallet
     * @dev Only callable by registry owner; rejects zero address and emits ReceiverAddressChange
     * @param newReceiver New receiver address for deposits/redemptions
     */
    function setReceiverAddress(address newReceiver) external onlyRegistryOwner {
        if (newReceiver == address(0)) revert ErrorsLib.ZeroAddress();
        emit ReceiverAddressChange(receiverAddress, newReceiver);
        receiverAddress = newReceiver;
    }

    /**
     * @notice Update the WT sender wallet used to return assets on redemption
     * @dev Only callable by registry owner; rejects zero address and emits SenderAddressChange
     * @param newSender New sender address expected in redemption transfers
     */
    function setSenderAddress(address newSender) external onlyRegistryOwner {
        if (newSender == address(0)) revert ErrorsLib.ZeroAddress();
        emit SenderAddressChange(senderAddress, newSender);
        senderAddress = newSender;
    }

    /**
     * @notice Start a temporary freeze window that protects operations around ex-dividend NAV drop.
     * @dev Requires no pending forwarded batches (`_noPendingForwardRequests`) and no active freeze.
     * @dev Does not refresh `lastFundPrice`, call `updateLastPrice` first when a fresh snapshot is needed.
     * @dev While freeze is active, `forwardRequests` and `updateLastPrice` are blocked.
     * @param duration Duration of freeze in seconds, capped by MAX_PRICE_FREEZE_DURATION.
     */
    function startPriceFreeze(uint64 duration) external onlyManager {
        _noPendingForwardRequests();
        require(priceFreezeActive == false, PriceFreezeAlreadyActive());
        require(
            duration > 0 && duration <= MAX_PRICE_FREEZE_DURATION,
            InvalidPriceFreezeDuration(duration, MAX_PRICE_FREEZE_DURATION)
        );

        priceFreezeActive = true;
        priceFreezeUntil = uint64(block.timestamp + duration);
        emit PriceFreezeStarted(lastFundPrice, priceFreezeUntil);
    }

    /**
     * @notice End an active freeze window after dividend settlement.
     * @dev Explicitly clears freeze state; timeout alone does not unblock `forwardRequests`.
     */
    function endPriceFreeze() external onlyManager {
        require(priceFreezeActive, PriceFreezeNotActive());
        priceFreezeActive = false;
        priceFreezeUntil = 0;
        emit PriceFreezeEnded();
    }

    /**
     * @notice Returns max allowed freeze duration.
     */
    function maxPriceFreezeDuration() external pure returns (uint64) {
        return MAX_PRICE_FREEZE_DURATION;
    }

    // =============================
    //   Custom operations
    // =============================

    /**
     * @notice Settle a WT dividend paid as fund-share mint to the adapter and distribute fairly to nodes
     * @dev Only allowed when no forwarded batch is pending settlement to avoid consuming logs in the wrong flow.
     *      Weighting is based on balances that are economically backed by fund tokens currently custodied by adapter:
     *      `balanceOf(node)`, `pendingRedeemRequest`, and `maxMint`.
     *      `claimableRedeemRequest` is excluded because those shares are parked in adapter after settleRedeem, while
     *      the corresponding fund tokens were already transferred out during `forwardRequests`.
     * @param nodes Strictly sorted ascending list of unique node addresses to receive their pro-rata share of dividend
     * @param verifyArgs Offchain arguments for event verification
     */
    function settleDividend(address[] calldata nodes, EventVerifierBase.OffchainArgs calldata verifyArgs)
        external
        onlyManager
        nonReentrant
    {
        _noPendingForwardRequests();
        require(nodes.length > 0, NothingToSettle());

        uint256 dividends = eventVerifier.verifyEvent(verifyArgs, TransferEventVerifier.OnchainArgs(fund, address(0)));
        require(dividends > 0, NothingToSettle());

        uint256[] memory weights = new uint256[](nodes.length);
        uint256 totalWeight;
        uint256 totalMaxMint;
        uint256 totalClaimableRedeemRequest;
        address previousNode;

        for (uint256 i; i < nodes.length; i++) {
            address nodeAddress = nodes[i];
            require(nodeAddress != address(this), AdapterAddressInNodeList());
            require(nodeAddress > previousNode, NodesNotStrictlySorted());
            previousNode = nodeAddress;

            NodeState memory node = _nodeState[nodeAddress];
            uint256 weight = balanceOf(nodeAddress) + node.pendingRedeemRequest + node.maxMint;
            totalClaimableRedeemRequest += node.claimableRedeemRequest;
            weights[i] = weight;
            totalWeight += weight;
            totalMaxMint += node.maxMint;
        }

        // Invariant check across the provided node set.
        // totalSupply includes adapter-held parked redeem shares, which should be excluded
        require(totalWeight == totalSupply() + totalMaxMint - totalClaimableRedeemRequest, NotAllNodesSettled());

        uint256 minted;
        for (uint256 i; i < nodes.length; i++) {
            uint256 shareOut = Math.mulDiv(dividends, weights[i], totalWeight);
            // last index gets any dust
            if (i == nodes.length - 1 && minted + shareOut < dividends) {
                shareOut += dividends - minted - shareOut;
            }
            minted += shareOut;
            if (shareOut > 0) {
                _mint(nodes[i], shareOut);
                emit DividendPaid(nodes[i], shareOut);
            }
        }
        require(minted == dividends, NotAllNodesSettled());

        emit DividendSettled(dividends, minted);
    }

    /**
     * @notice Allows the adapter to receive WT soulbound ERC721 token
     * @dev Returns the ERC721 receiver magic value so `safeMint`/`safeTransferFrom` do not revert.
     *      No state is updated because the token is only used as a receipt on-chain.
     * @return The selector required by ERC721 to confirm receipt.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // =============================
    //   Overrides
    // =============================

    /**
     * @inheritdoc AdapterBase
     * @dev Reverts while `priceFreezeActive` is true; manager must call `endPriceFreeze` first.
     */
    function updateLastPrice() public override {
        require(priceFreezeActive == false, PriceFreezeActive());
        super.updateLastPrice();
    }

    /**
     * @inheritdoc AdapterBase
     * @dev Reverts while `priceFreezeActive` is true; manager must call `endPriceFreeze` first.
     */
    function forwardRequests() public override {
        require(priceFreezeActive == false, PriceFreezeActive());
        super.forwardRequests();
    }

    /**
     * @inheritdoc AdapterBase
     */
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        uint256 fundPrice = _priceFreezeRunning() ? lastFundPrice : _getFundPrice();
        return _convertToShares(assets, _getAssetPrice(), fundPrice);
    }

    /**
     * @inheritdoc AdapterBase
     */
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        uint256 fundPrice = _priceFreezeRunning() ? lastFundPrice : _getFundPrice();
        return _convertToAssets(shares, _getAssetPrice(), fundPrice);
    }

    /**
     * @inheritdoc AdapterBase
     */
    function _verifySettleDeposit(EventVerifierBase.OffchainArgs calldata verifyArgs)
        internal
        override
        returns (uint256 shares, uint256 assets)
    {
        // no assets are returned on WT deposit
        // fund shares are minted, therefore "from" in Transfer event should be zero address
        shares = eventVerifier.verifyEvent(verifyArgs, TransferEventVerifier.OnchainArgs(fund, address(0)));
    }

    /**
     * @inheritdoc AdapterBase
     */
    function _verifySettleRedeem(EventVerifierBase.OffchainArgs calldata verifyArgs)
        internal
        override
        returns (uint256 shares, uint256 assets)
    {
        // no shares are returned on WT redeem; assets are coming from WT wallet
        assets = eventVerifier.verifyEvent(verifyArgs, TransferEventVerifier.OnchainArgs(asset, senderAddress));
    }

    /**
     * @inheritdoc AdapterBase
     */
    function _fundDeposit(uint256 pendingAssets) internal override {
        IERC20(asset).safeTransfer(receiverAddress, pendingAssets);
    }

    /**
     * @inheritdoc AdapterBase
     */
    function _fundRedeem(uint256 pendingShares) internal override {
        IERC20(fund).safeTransfer(receiverAddress, pendingShares);
    }

    /**
     * @dev Returns whether the configured price freeze window is currently in effect.
     * @return True when `priceFreezeActive` is set and `block.timestamp` is less than or equal to `priceFreezeUntil`.
     */
    function _priceFreezeRunning() internal view returns (bool) {
        return priceFreezeActive && block.timestamp <= priceFreezeUntil;
    }
}
