// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode} from "./interfaces/INode.sol";
import {Ownable2Step, Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {IQueueManager} from "./interfaces/IQueueManager.sol";

/**
 * @title QueueManager
 * @author ODND Studios
 */
contract QueueManager is Ownable2Step, IQueueManager {

    /* CONSTANTS */

    /// @dev Prices are fixed-point integers with 18 decimals
    uint8 internal constant PRICE_DECIMALS = 18;

    /* IMMUTABLES */

    INode public immutable node;

    /* STORAGE */

    /// @inheritdoc IQueueManager
    IQuoter public quoter;

    /// @inheritdoc IQueueManager
    mapping(address => QueueState) public queueStates;

    /* CONSTRUCTOR */

    constructor(address node_, address quoter_, address owner_) Ownable(owner_) {
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
    function requestDeposit(uint256 assets, address controller, address, /* owner */ address source)
        public
        onlyNode
        returns (bool)
    {
        if (assets == 0) revert ErrorsLib.ZeroAmount();
        QueueState storage state = queueStates[controller];
        state.pendingDepositRequest = state.pendingDepositRequest + assets;
        return true;
    }

    /// @inheritdoc IQueueManager
    function requestRedeem(uint256 shares, address controller, address, /* owner */ address source)
        public
        onlyNode
        returns (bool)
    {
        if (shares == 0) revert ErrorsLib.ZeroAmount();
        QueueState storage state = queueStates[controller];
        state.pendingRedeemRequest = state.pendingRedeemRequest + shares;
        return true;
    }

    // function fulfillDepositRequest

    // function fulfillRedeemRequest

    /* VIEW */

    /// @inheritdoc IQueueManager
    function convertToShares(uint256 _assets) public view returns (uint256 shares) {
        uint256 latestPrice = quoter.getPrice();
        shares = uint256(_calculateShares(_assets, latestPrice, MathLib.Rounding.Down));
    }

    /// @inheritdoc IQueueManager
    function convertToAssets(uint256 _shares) public view returns (uint256 assets) {
        uint256 latestPrice = quoter.getPrice();
        assets = uint256(_calculateAssets(_shares, latestPrice, MathLib.Rounding.Down));
    }

    /// @inheritdoc IQueueManager
    function maxDeposit(address controller) public view returns (uint256 assets) {
        QueueState storage state = queueStates[controller];
        assets = _calculateAssets(state.maxMint, state.depositPrice, MathLib.Rounding.Down);
    }

    /// @inheritdoc IQueueManager
    function maxMint(address controller) public view returns (uint256 shares) {
        QueueState storage state = queueStates[controller];
        shares = state.maxMint;
    }

    /// @inheritdoc IQueueManager
    function maxWithdraw(address controller) public view returns (uint256 assets) {
        QueueState storage state = queueStates[controller];
        assets = state.maxWithdraw;
    }

    /// @inheritdoc IQueueManager
    function maxRedeem(address controller) public view returns (uint256 shares) {
        QueueState storage state = queueStates[controller];
        shares = uint256(_calculateShares(state.maxWithdraw, state.redeemPrice, MathLib.Rounding.Down));
    }

    /// @inheritdoc IQueueManager
    function pendingDepositRequest(address controller) public view returns (uint256 assets) {
        QueueState storage state = queueStates[controller];
        assets = state.pendingDepositRequest;
    }

    /// @inheritdoc IInvestmentManager
    function pendingRedeemRequest(address controller) public view returns (uint256 shares) {
        QueueState storage state = queueStates[controller];
        shares = state.pendingRedeemRequest;
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
    function _calculatePrice(address vault, uint128 assets, uint128 shares) internal view returns (uint256) {
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

    /// @dev    Checks transfer restrictions for the vault shares. Sender (from) and receiver (to) have both to pass the
    ///         restrictions for a successful share transfer.
    function _canTransfer(address from, address to, uint256 value) internal view returns (bool) {
        return node.checkTransferRestriction(from, to, value);
    }
}
