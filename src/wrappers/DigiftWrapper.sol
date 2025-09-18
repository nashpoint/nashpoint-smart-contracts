// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {ISubRedManagement, IDFeedPriceOracle} from "src/interfaces/external/IDigift.sol";
import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";

struct State {
    uint256 maxMint;
    uint256 maxWithdraw;
    uint256 pendingDepositRequest;
    uint256 pendingDepositReimbursement;
    uint256 pendingRedeemRequest;
    uint256 pendingRedeemReimbursement;
    uint256 claimableDepositRequest;
    uint256 claimableRedeemRequest;
    uint256 priceOnRequest;
}

contract DigiftWrapper is ERC20, RegistryAccessControl, Pausable, IERC7540, IERC7575 {
    using SafeERC20 for IERC20;

    // =============================
    //            Errors
    // =============================
    error ZeroAmount();
    error ControllerNotSender();
    error OwnerNotSender();
    error DepositRequestPending();
    error DepositRequestNotClaimed();
    error RedeemRequestPending();
    error RedeemRequestNotClaimed();
    error DepositRequestNotFulfilled();
    error RedeemRequestNotFulfilled();
    error MintAllSharesOnly();
    error WithdrawAllAssetsOnly();
    error NothingToSettle();
    error Unsupported();
    error InvalidPercentage();
    error InsufficientStTokenBalance(uint256 internalBalance, uint256 actualBalance);
    error InsufficientAssetBalance(uint256 internalBalance, uint256 actualBalance);
    error PriceNotInRange(uint256 lastValue, uint256 currentValue);
    error StalePriceData(uint256 lastUpdate, uint256 currentTimestamp);
    error NotManager(address caller);

    // =============================
    //            Events
    // =============================
    event DepositSettled(address indexed node, uint256 shares, uint256 assets);
    event RedeemSettled(address indexed node, uint256 shares, uint256 assets);
    event SettlementDeviationChange(uint64 oldValue, uint64 newValue);
    event PriceDeviationChange(uint64 oldValue, uint64 newValue);
    event PriceUpdateDeviationChange(uint64 oldValue, uint64 newValue);
    event NotInRange(address node, uint256 expectedValue, uint256 actualValue);
    event ManagerWhitelistChange(address manager, bool whitelisted);
    event LastPriceUpdate(uint256 price);

    /* IMMUTABLES */
    uint256 constant WAD = 1e18;

    uint256 private constant REQUEST_ID = 0;

    address public immutable asset;
    uint8 internal immutable _assetDecimals;

    address public immutable stToken;
    uint8 internal immutable _stTokenDecimals;

    ISubRedManagement public immutable subRedManagement;
    IDFeedPriceOracle public immutable dFeedPriceOracle;
    uint8 internal immutable _dFeedPriceOracleDecimals;

    /* STATE */

    uint64 public settlementDeviation;
    uint64 public priceDeviation;
    uint64 public priceUpdateDeviation;

    uint256 lastPrice;

    uint256 public stTokenBalance;
    uint256 public assetBalance;

    mapping(address node => State state) internal _nodeState;

    mapping(address manager => bool whitelisted) public managerWhitelisted;

    constructor(
        address asset_,
        address stToken_,
        address subRedManagement_,
        address dFeedPriceOracle_,
        address registry_,
        string memory name_,
        string memory symbol_,
        uint64 settlementDeviation_,
        uint64 priceDeviation_,
        uint64 priceUpdateDeviation_
    ) RegistryAccessControl(registry_) ERC20(name_, symbol_) {
        asset = asset_;
        stToken = stToken_;
        _assetDecimals = IERC20Metadata(asset_).decimals();
        _stTokenDecimals = IERC20Metadata(stToken_).decimals();
        subRedManagement = ISubRedManagement(subRedManagement_);
        dFeedPriceOracle = IDFeedPriceOracle(dFeedPriceOracle_);
        _dFeedPriceOracleDecimals = IDFeedPriceOracle(dFeedPriceOracle_).decimals();
        settlementDeviation = settlementDeviation_;
        priceDeviation = priceDeviation_;
        priceUpdateDeviation = priceUpdateDeviation_;
        // initialize price cache
        lastPrice = dFeedPriceOracle.getPrice();
    }

    function _actionValidation(uint256 amount, address controller, address owner) internal {
        require(amount > 0, ZeroAmount());
        require(controller == msg.sender, ControllerNotSender());
        require(owner == msg.sender, OwnerNotSender());
    }

    function _nothingPending() internal {
        State memory nodeState = _nodeState[msg.sender];
        require(nodeState.pendingDepositRequest == 0, DepositRequestPending());
        require(nodeState.maxMint == 0, DepositRequestNotClaimed());
        require(nodeState.pendingRedeemRequest == 0, RedeemRequestPending());
        require(nodeState.maxWithdraw == 0, RedeemRequestNotClaimed());
    }

    function setSettlementDeviation(uint64 value) external onlyRegistryOwner {
        require(value <= WAD, InvalidPercentage());
        emit SettlementDeviationChange(settlementDeviation, value);
        settlementDeviation = value;
    }

    function setPriceDeviation(uint64 value) external onlyRegistryOwner {
        require(value <= WAD, InvalidPercentage());
        emit PriceDeviationChange(priceDeviation, value);
        priceDeviation = value;
    }

    function setPriceUpdateDeviation(uint64 value) external onlyRegistryOwner {
        emit PriceUpdateDeviationChange(priceUpdateDeviation, value);
        priceUpdateDeviation = value;
    }

    function pause() external onlyRegistryOwner {
        _pause();
    }

    function unpause() external onlyRegistryOwner {
        _unpause();
    }

    function setManager(address manager, bool whitelisted) external onlyRegistryOwner {
        managerWhitelisted[manager] = whitelisted;
        emit ManagerWhitelistChange(manager, whitelisted);
    }

    modifier onlyManager() {
        require(managerWhitelisted[msg.sender] == true, NotManager(msg.sender));
        _;
    }

    function forceUpdateLastPrice() external onlyRegistryOwner {
        uint256 price = dFeedPriceOracle.getPrice();
        lastPrice = price;
        emit LastPriceUpdate(price);
    }

    function updateLastPrice() external onlyManager {
        _getAndUpdatePrice();
    }

    function _getAndUpdatePrice() internal returns (uint256) {
        uint256 price = _getPrice();
        lastPrice = price;
        emit LastPriceUpdate(price);
        return price;
    }

    function _getPrice() internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = dFeedPriceOracle.latestRoundData();
        uint256 price = uint256(answer);
        require(MathLib._withinRange(lastPrice, price, priceDeviation), PriceNotInRange(lastPrice, price));
        require(block.timestamp - updatedAt <= priceUpdateDeviation, StalePriceData(updatedAt, block.timestamp));
        return price;
    }

    function requestDeposit(uint256 assets, address controller, address owner)
        external
        onlyNode
        whenNotPaused
        returns (uint256)
    {
        _actionValidation(assets, controller, owner);
        _nothingPending();

        _nodeState[msg.sender].pendingDepositRequest = assets;
        uint256 price = _getAndUpdatePrice();
        _nodeState[msg.sender].priceOnRequest = price;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(asset).safeIncreaseAllowance(address(subRedManagement), assets);
        subRedManagement.subscribe(stToken, asset, assets, block.timestamp + 1);

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    function requestRedeem(uint256 shares, address controller, address owner)
        external
        onlyNode
        whenNotPaused
        returns (uint256)
    {
        _actionValidation(shares, controller, owner);
        _nothingPending();

        _nodeState[msg.sender].pendingRedeemRequest = shares;
        uint256 price = _getAndUpdatePrice();
        _nodeState[msg.sender].priceOnRequest = price;

        _spendAllowance(msg.sender, address(this), shares);
        _transfer(msg.sender, address(this), shares);
        // stTokens are transferred to subRedManagement - we need to reduce internal accounting
        stTokenBalance -= shares;

        IERC20(stToken).safeIncreaseAllowance(address(subRedManagement), shares);
        subRedManagement.redeem(stToken, asset, shares, block.timestamp + 1);

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function mint(uint256 shares, address receiver, address controller)
        public
        onlyNode
        whenNotPaused
        returns (uint256 assets)
    {
        _actionValidation(shares, controller, receiver);
        require(_nodeState[msg.sender].claimableDepositRequest > 0, DepositRequestNotFulfilled());
        require(_nodeState[msg.sender].maxMint == shares, MintAllSharesOnly());

        _getAndUpdatePrice();

        assets = _nodeState[msg.sender].claimableDepositRequest;

        uint256 assetsToReimburse = _nodeState[msg.sender].pendingDepositReimbursement;

        _nodeState[msg.sender].claimableDepositRequest = 0;
        _nodeState[msg.sender].maxMint = 0;
        _nodeState[msg.sender].pendingDepositReimbursement = 0;

        _mint(msg.sender, shares);

        // if assets are partially used => send back to the node
        if (assetsToReimburse > 0) {
            IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);
        }
        emit Deposit(controller, receiver, assets - assetsToReimburse, shares);
    }

    function withdraw(uint256 assets, address receiver, address controller)
        external
        onlyNode
        whenNotPaused
        returns (uint256 shares)
    {
        _actionValidation(assets, controller, receiver);

        require(_nodeState[msg.sender].claimableRedeemRequest > 0, RedeemRequestNotFulfilled());
        require(_nodeState[msg.sender].maxWithdraw == assets, WithdrawAllAssetsOnly());

        _getAndUpdatePrice();

        shares = _nodeState[msg.sender].claimableRedeemRequest;

        uint256 sharesToReimburse = _nodeState[msg.sender].pendingRedeemReimbursement;
        uint256 sharesToBurn = shares - sharesToReimburse;

        _nodeState[msg.sender].claimableRedeemRequest = 0;
        _nodeState[msg.sender].maxWithdraw = 0;
        _nodeState[msg.sender].pendingRedeemReimbursement = 0;

        // assets are moved to node - we need to reduce internal accounting
        assetBalance -= assets;

        _burn(address(this), sharesToBurn);

        if (sharesToReimburse > 0) {
            _transfer(address(this), msg.sender, sharesToReimburse);
        }

        IERC20(asset).safeTransfer(msg.sender, assets);
        emit Withdraw(msg.sender, receiver, controller, assets, shares - sharesToReimburse);
    }

    function _sufficientBalances(uint256 shares, uint256 assets) internal {
        uint256 stTokenBalanceActual = IERC20(stToken).balanceOf(address(this));
        stTokenBalance += shares;
        require(
            stTokenBalance <= stTokenBalanceActual, InsufficientStTokenBalance(stTokenBalance, stTokenBalanceActual)
        );
        uint256 assetBalanceActual = IERC20(asset).balanceOf(address(this));
        assetBalance += assets;
        require(assetBalance <= assetBalanceActual, InsufficientAssetBalance(assetBalance, assetBalanceActual));
    }

    function settleDeposit(address node, uint256 shares, uint256 assets) external onlyManager whenNotPaused {
        require(_nodeState[node].pendingDepositRequest > 0, NothingToSettle());
        uint256 effectiveAssets = _nodeState[node].pendingDepositRequest - assets;
        uint256 expectedShares = _convertToShares(effectiveAssets, _nodeState[node].priceOnRequest);
        if (!MathLib._withinRange(expectedShares, shares, settlementDeviation)) {
            emit NotInRange(node, expectedShares, shares);
            _pause();
            return;
        }

        _sufficientBalances(shares, assets);
        _nodeState[node].claimableDepositRequest = _nodeState[node].pendingDepositRequest;
        _nodeState[node].pendingDepositRequest = 0;
        _nodeState[node].maxMint = shares;
        _nodeState[node].pendingDepositReimbursement = assets;
        _nodeState[node].priceOnRequest = 0;
        emit DepositSettled(node, shares, assets);
    }

    function settleRedeem(address node, uint256 shares, uint256 assets) external onlyManager whenNotPaused {
        require(_nodeState[node].pendingRedeemRequest > 0, NothingToSettle());
        uint256 effectiveShares = _nodeState[node].pendingRedeemRequest - shares;
        uint256 expectedAssets = _convertToAssets(effectiveShares, _nodeState[node].priceOnRequest);
        if (!MathLib._withinRange(expectedAssets, assets, settlementDeviation)) {
            emit NotInRange(node, expectedAssets, assets);
            _pause();
            return;
        }

        _sufficientBalances(shares, assets);
        _nodeState[node].claimableRedeemRequest = _nodeState[node].pendingRedeemRequest;
        _nodeState[node].pendingRedeemRequest = 0;
        _nodeState[node].maxWithdraw = assets;
        _nodeState[node].pendingRedeemReimbursement = shares;
        _nodeState[node].priceOnRequest = 0;
        emit RedeemSettled(node, shares, assets);
    }

    function pendingDepositRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].pendingDepositRequest;
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].claimableDepositRequest;
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].pendingRedeemRequest;
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].claimableRedeemRequest;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7575).interfaceId
            || interfaceId == type(IERC7540Deposit).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId;
    }

    function totalAssets() external view returns (uint256) {
        return convertToAssets(totalSupply());
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, _getPrice());
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, _getPrice());
    }

    function _convertToShares(uint256 assets, uint256 stTokenPrice) internal view returns (uint256 shares) {
        // TODO: asset price should be fetched as well
        // for USDC assume not it's 1 USD;
        return assets * 10 ** (_stTokenDecimals + _dFeedPriceOracleDecimals) / (stTokenPrice * 10 ** (_assetDecimals));
    }

    function _convertToAssets(uint256 shares, uint256 stTokenPrice) internal view returns (uint256 assets) {
        // TODO: asset price should be fetched as well
        // for USDC assume not it's 1 USD;
        return shares * stTokenPrice * 10 ** (_assetDecimals) / 10 ** (_stTokenDecimals + _dFeedPriceOracleDecimals);
    }

    function maxMint(address controller) public view returns (uint256) {
        return _nodeState[controller].maxMint;
    }

    function maxWithdraw(address controller) external view returns (uint256) {
        return _nodeState[controller].maxWithdraw;
    }

    function decimals() public view override returns (uint8) {
        return _stTokenDecimals;
    }

    function share() external view returns (address) {
        return address(this);
    }

    // Unsupported functions

    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        revert Unsupported();
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        revert Unsupported();
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        revert Unsupported();
    }

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        revert Unsupported();
    }

    function previewDeposit(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    function previewMint(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    function previewWithdraw(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    function previewRedeem(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        revert Unsupported();
    }

    function maxDeposit(address controller) public view returns (uint256 maxAssets) {
        revert Unsupported();
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        revert Unsupported();
    }

    function isOperator(address controller, address operator) external view returns (bool) {
        revert Unsupported();
    }
}
