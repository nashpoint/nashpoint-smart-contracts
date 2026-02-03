// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TransferEventVerifier} from "src/adapters/TransferEventVerifier.sol";
import {AdapterBase, NodeState} from "src/adapters/AdapterBase.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

/**
 * @title WisdomTree Adapter
 * @author ODND Studios
 * @notice ERC7540-compatible adapter for Wisdom Tree Funds interactions
 */
contract WTAdapter is AdapterBase, IERC721Receiver {
    using SafeERC20 for IERC20;

    // =============================
    //         Custom State
    // =============================

    /// @notice Transfer Event Verifier (shared/immutable)
    TransferEventVerifier public immutable eventVerifier;

    /// @notice WT address receiving assets and funds from this adapter
    address public receiverAddress;

    /// @notice Address sending asset on redemption to this adapter
    address public senderAddress;

    // =============================
    //            Events
    // =============================

    event ReceiverAddressChange(address indexed previousReceiver, address indexed newReceiver);
    event SenderAddressChange(address indexed previousSender, address indexed newSender);
    event DividendSettled(uint256 fundShares, uint256 adapterSharesMinted);

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

    // =============================
    //   Custom operations
    // =============================

    /**
     * @notice Settle a WT dividend paid as fund-share mint to the adapter and distribute fairly to nodes
     * @dev Only allowed when no deposit/redemption cycle is in-flight to avoid log mix-ups
     * @param nodes List of node addresses to receive their pro-rata share of the dividend
     * @param verifyArgs Offchain arguments for event verification
     */
    function settleDividend(address[] calldata nodes, EventVerifierBase.OffchainArgs calldata verifyArgs)
        external
        onlyManager
        nonReentrant
    {
        // Ensure no async cycle is active to avoid consuming logs in the wrong flow
        require(_globalState.pendingDepositRequest == 0, DepositRequestPending());
        require(_globalState.pendingRedeemRequest == 0, RedeemRequestPending());
        require(nodes.length > 0, NothingToSettle());

        uint256 dividends = eventVerifier.verifyEvent(verifyArgs, TransferEventVerifier.OnchainArgs(fund, address(0)));
        require(dividends > 0, NothingToSettle());

        uint256[] memory weights = new uint256[](nodes.length);
        uint256 totalWeight;
        uint256 totalMaxMint;

        for (uint256 i; i < nodes.length; i++) {
            NodeState memory node = _nodeState[nodes[i]];
            uint256 weight =
                balanceOf(nodes[i]) + node.pendingRedeemRequest + node.claimableRedeemRequest + node.maxMint;
            weights[i] = weight;
            totalWeight += weight;
            totalMaxMint += node.maxMint;
        }

        // Expected supply = existing supply (includes parked redeem shares) + unminted deposit entitlements
        require(totalWeight == totalSupply() + totalMaxMint, NotAllNodesSettled());

        uint256 minted;
        for (uint256 i; i < nodes.length; i++) {
            uint256 shareOut = dividends * weights[i] / totalWeight;
            // last index gets any dust
            if (i == nodes.length - 1 && minted + shareOut < dividends) {
                shareOut += dividends - minted - shareOut;
            }
            minted += shareOut;
            if (shareOut > 0) {
                _mint(nodes[i], shareOut);
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
}
