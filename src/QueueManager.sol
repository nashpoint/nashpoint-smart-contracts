// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {INode} from "./interfaces/INode.sol";
import {IQueueManager, QueueState} from "./interfaces/IQueueManager.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {MathLib} from "./libraries/MathLib.sol";

/**
 * @title QueueManager
 * @author ODND Studios
 */
contract QueueManager is IQueueManager, Ownable {
    using MathLib for uint256;
    using SafeERC20 for IERC20;

    /* CONSTANTS */
    uint8 internal constant PRICE_DECIMALS = 18;

    /* IMMUTABLES */
    /// @dev Reference to the Node contract this queue manager serves
    INode public immutable node;

    /* STORAGE */
    /// @inheritdoc IQueueManager
    IQuoter public quoter;
    mapping(address => QueueState) public queueStates;

    /* CONSTRUCTOR */
    constructor(address node_, address quoter_, address owner_) Ownable(owner_) {
        if (node_ == address(0) || quoter_ == address(0)) revert ErrorsLib.ZeroAddress();

        node = INode(node_);
        quoter = IQuoter(quoter_);
    }

    /* MODIFIERS */
    modifier onlyNode() {
        if (msg.sender != address(node)) revert ErrorsLib.InvalidSender();
        _;
    }

    /* EXTERNAL */
    /// @inheritdoc IQueueManager
    function requestDeposit(uint256 assets, address controller) public onlyNode returns (bool) {
        uint128 _assets = assets.toUint128();
        if (_assets == 0) revert ErrorsLib.ZeroAmount();
        QueueState storage state = queueStates[controller];
        state.pendingDepositRequest = state.pendingDepositRequest + _assets;
        return true;
    }

    /// @inheritdoc IQueueManager
    function requestRedeem(uint256 shares, address controller) public onlyNode returns (bool) {
        uint128 _shares = shares.toUint128();
        if (_shares == 0) revert ErrorsLib.ZeroAmount();
        QueueState storage state = queueStates[controller];
        state.pendingRedeemRequest = state.pendingRedeemRequest + _shares;
        return true;
    }

    /// @inheritdoc IQueueManager
    function fulfillDepositRequest(address user, uint128 assets, uint128 shares) public onlyOwner {
        QueueState storage state = queueStates[user];
        if (state.pendingDepositRequest == 0) revert ErrorsLib.NoPendingDepositRequest();
        state.depositPrice = _calculatePrice(_maxDeposit(user) + assets, state.maxMint + shares);
        state.maxMint = state.maxMint + shares;
        state.pendingDepositRequest = state.pendingDepositRequest > assets ? state.pendingDepositRequest - assets : 0;

        node.mint(node.escrow(), shares);
        node.onDepositClaimable(user, assets, shares);
    }

    /// @inheritdoc IQueueManager
    function fulfillRedeemRequest(address user, uint128 assets, uint128 shares) public onlyOwner {
        QueueState storage state = queueStates[user];
        if (state.pendingRedeemRequest == 0) revert ErrorsLib.NoPendingRedeemRequest();
        state.redeemPrice = _calculatePrice(state.maxWithdraw + assets, _maxRedeem(user) + shares);
        state.maxWithdraw = state.maxWithdraw > assets ? state.maxWithdraw - assets : 0;
        state.pendingRedeemRequest = state.pendingRedeemRequest > shares ? state.pendingRedeemRequest - shares : 0;

        node.burn(node.escrow(), shares);
        node.onRedeemClaimable(user, assets, shares);
    }

    /* VIEW */
    /// @inheritdoc IQueueManager
    function convertToShares(uint256 _assets) public view returns (uint256 shares) {
        uint128 latestPrice = quoter.getPrice();
        shares = uint256(_calculateShares(_assets.toUint128(), latestPrice, MathLib.Rounding.Down));
    }

    /// @inheritdoc IQueueManager
    function convertToAssets(uint256 _shares) public view returns (uint256 assets) {
        uint128 latestPrice = quoter.getPrice();
        assets = uint256(_calculateAssets(_shares.toUint128(), latestPrice, MathLib.Rounding.Down));
    }

    /// @inheritdoc IQueueManager
    function maxDeposit(address user) public view returns (uint256 assets) {
        assets = uint256(_maxDeposit(user));
    }

    function _maxDeposit(address user) internal view returns (uint128 assets) {
        QueueState storage state = queueStates[user];
        assets = _calculateAssets(state.maxMint, state.depositPrice, MathLib.Rounding.Down);
    }

    /// @inheritdoc IQueueManager
    function maxMint(address user) public view returns (uint256 shares) {
        QueueState storage state = queueStates[user];
        shares = state.maxMint;
    }

    /// @inheritdoc IQueueManager
    function maxWithdraw(address user) public view returns (uint256 assets) {
        QueueState storage state = queueStates[user];
        assets = state.maxWithdraw;
    }

    /// @inheritdoc IQueueManager
    function maxRedeem(address user) public view returns (uint256 shares) {
        shares = uint256(_maxRedeem(user));
    }

    function _maxRedeem(address user) internal view returns (uint128 shares) {
        QueueState storage state = queueStates[user];
        shares = _calculateShares(state.maxWithdraw, state.redeemPrice, MathLib.Rounding.Down);
    }

    /// @inheritdoc IQueueManager
    function pendingDepositRequest(address user) public view returns (uint256 assets) {
        QueueState storage state = queueStates[user];
        assets = state.pendingDepositRequest;
    }

    /// @inheritdoc IQueueManager
    function pendingRedeemRequest(address user) public view returns (uint256 shares) {
        QueueState storage state = queueStates[user];
        shares = state.pendingRedeemRequest;
    }

    /* VAULT CLAIM FUNCTIONS */
    /// @inheritdoc IQueueManager
    function deposit(uint256 assets, address receiver, address controller) public onlyNode returns (uint256 shares) {
        if (assets > maxDeposit(controller)) revert ErrorsLib.ExceedsMaxDeposit();

        QueueState storage state = queueStates[controller];
        uint128 sharesUp = _calculateShares(assets.toUint128(), state.depositPrice, MathLib.Rounding.Up);
        uint128 sharesDown = _calculateShares(assets.toUint128(), state.depositPrice, MathLib.Rounding.Down);
        _processDeposit(state, sharesUp, sharesDown, receiver);
        shares = uint256(sharesDown);
    }

    /// @inheritdoc IQueueManager
    function mint(uint256 shares, address receiver, address controller) public onlyNode returns (uint256 assets) {
        QueueState storage state = queueStates[controller];
        uint128 shares_ = shares.toUint128();
        _processDeposit(state, shares_, shares_, receiver);
        assets = uint256(_calculateAssets(shares_, state.depositPrice, MathLib.Rounding.Down));
    }

    function _processDeposit(QueueState storage state, uint128 sharesUp, uint128 sharesDown, address receiver)
        internal
    {
        if (sharesUp > state.maxMint) revert ErrorsLib.ExceedsMaxDeposit();
        state.maxMint = state.maxMint > sharesUp ? state.maxMint - sharesUp : 0;
        if (sharesDown > 0) {
            IERC20(node).safeTransferFrom(node.escrow(), receiver, sharesDown);
        }
    }

    /// @inheritdoc IQueueManager
    function redeem(uint256 shares, address receiver, address controller) public onlyNode returns (uint256 assets) {
        if (shares > maxRedeem(controller)) revert ErrorsLib.ExceedsMaxRedeem();

        QueueState storage state = queueStates[controller];
        uint128 assetsUp = _calculateAssets(shares.toUint128(), state.redeemPrice, MathLib.Rounding.Up);
        uint128 assetsDown = _calculateAssets(shares.toUint128(), state.redeemPrice, MathLib.Rounding.Down);
        _processRedeem(state, assetsUp, assetsDown, receiver);
        assets = uint256(assetsDown);
    }

    /// @inheritdoc IQueueManager
    function withdraw(uint256 assets, address receiver, address controller) public onlyNode returns (uint256 shares) {
        QueueState storage state = queueStates[controller];
        uint128 assets_ = assets.toUint128();
        _processRedeem(state, assets_, assets_, receiver);
        shares = uint256(_calculateShares(assets_, state.redeemPrice, MathLib.Rounding.Down));
    }

    function _processRedeem(QueueState storage state, uint128 assetsUp, uint128 assetsDown, address receiver)
        internal
    {
        if (assetsUp > state.maxWithdraw) revert ErrorsLib.ExceedsMaxWithdraw();
        state.maxWithdraw = state.maxWithdraw > assetsUp ? state.maxWithdraw - assetsUp : 0;
        if (assetsDown > 0) IERC20(node.asset()).safeTransferFrom(node.escrow(), receiver, assetsDown);
    }

    /* INTERNAL */
    /// @dev    Calculates share amount based on asset amount and share price. Returned value is in share decimals.
    function _calculateShares(uint128 assets, uint256 price, MathLib.Rounding rounding)
        internal
        view
        returns (uint128 shares)
    {
        if (price == 0 || assets == 0) {
            shares = 0;
        } else {
            (uint8 assetDecimals, uint8 nodeDecimals) = _getNodeDecimals();

            uint256 sharesInPriceDecimals =
                _toPriceDecimals(assets, assetDecimals).mulDiv(10 ** PRICE_DECIMALS, price, rounding);

            shares = _fromPriceDecimals(sharesInPriceDecimals, nodeDecimals);
        }
    }

    /// @dev    Calculates asset amount based on share amount and share price. Returned value is in asset decimals.
    function _calculateAssets(uint128 shares, uint256 price, MathLib.Rounding rounding)
        internal
        view
        returns (uint128 assets)
    {
        if (price == 0 || shares == 0) {
            assets = 0;
        } else {
            (uint8 assetDecimals, uint8 nodeDecimals) = _getNodeDecimals();

            uint256 assetsInPriceDecimals =
                _toPriceDecimals(shares, nodeDecimals).mulDiv(price, 10 ** PRICE_DECIMALS, rounding);

            assets = _fromPriceDecimals(assetsInPriceDecimals, assetDecimals);
        }
    }

    /// @dev    Calculates share price and returns the value in price decimals
    function _calculatePrice(uint128 assets, uint128 shares) internal view returns (uint256) {
        if (assets == 0 || shares == 0) {
            return 0;
        }

        (uint8 assetDecimals, uint8 nodeDecimals) = _getNodeDecimals();
        return _toPriceDecimals(assets, assetDecimals).mulDiv(
            10 ** PRICE_DECIMALS, _toPriceDecimals(shares, nodeDecimals), MathLib.Rounding.Down
        );
    }

    /// @dev    When converting assets to shares using the price,
    ///         all values are normalized to PRICE_DECIMALS
    function _toPriceDecimals(uint128 _value, uint8 decimals) internal pure returns (uint256) {
        if (PRICE_DECIMALS == decimals) return uint256(_value);
        return uint256(_value) * 10 ** (PRICE_DECIMALS - decimals);
    }

    /// @dev    Converts decimals of the value from the price decimals back to the intended decimals
    function _fromPriceDecimals(uint256 _value, uint8 decimals) internal pure returns (uint128) {
        if (PRICE_DECIMALS == decimals) return _value.toUint128();
        return (_value / 10 ** (PRICE_DECIMALS - decimals)).toUint128();
    }

    /// @dev    Returns the asset decimals and the share decimals for a given vault
    function _getNodeDecimals() internal view returns (uint8 assetDecimals, uint8 nodeDecimals) {
        assetDecimals = IERC20Metadata(node.asset()).decimals();
        nodeDecimals = node.decimals();
    }
}
