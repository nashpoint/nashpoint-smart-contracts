// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import {ISubRedManagement, IDFeedPriceOracle} from "src/interfaces/external/IDigift.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";
import {IPriceOracle} from "src/interfaces/external/IPriceOracle.sol";

import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";
import {MathLib} from "src/libraries/MathLib.sol";

import {DigiftEventVerifier} from "src/wrappers/DigiftEventVerifier.sol";

struct NodeState {
    uint256 maxMint;
    uint256 maxWithdraw;
    uint256 pendingDepositRequest;
    uint256 pendingDepositReimbursement;
    uint256 pendingRedeemRequest;
    uint256 pendingRedeemReimbursement;
    uint256 claimableDepositRequest;
    uint256 claimableRedeemRequest;
}

struct GlobalState {
    uint256 accumulatedDeposit;
    uint256 accumulatedRedemption;
    uint256 pendingDepositRequest;
    uint256 pendingRedeemRequest;
}

contract DigiftWrapper is ERC20Upgradeable, RegistryAccessControl, IERC7540, IERC7575 {
    using SafeERC20 for IERC20;
    using MathLib for uint256;

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
    error NotNode();
    error NotManager(address caller);
    error NotWhitelistedNode(address node);
    error BadPriceOracle(address oracle);

    // =============================
    //            Events
    // =============================
    event DepositSettled(address indexed node, uint256 shares, uint256 assets);
    event RedeemSettled(address indexed node, uint256 shares, uint256 assets);
    event PriceDeviationChange(uint64 oldValue, uint64 newValue);
    event PriceUpdateDeviationChange(uint64 oldValue, uint64 newValue);
    event NotInRange(address indexed node, uint256 expectedValue, uint256 actualValue);
    event ManagerWhitelistChange(address indexed manager, bool whitelisted);
    event NodeWhitelistChange(address indexed node, bool whitelisted);
    event LastPriceUpdate(uint256 price);
    event DigiftSubscribed(uint256 assets);
    event DigiftRedeemed(uint256 shares);

    /* IMMUTABLES */
    uint256 constant WAD = 1e18;

    uint256 private constant REQUEST_ID = 0;

    ISubRedManagement public immutable subRedManagement;

    DigiftEventVerifier digiftEventVerifier;

    /* STATE */

    address public asset;
    uint8 internal _assetDecimals;
    IPriceOracle public assetPriceOracle;
    uint8 internal _assetPriceOracleDecimals;

    address public stToken;
    uint8 internal _stTokenDecimals;

    IDFeedPriceOracle public dFeedPriceOracle;
    uint8 internal _dFeedPriceOracleDecimals;

    uint64 public priceDeviation;
    uint64 public priceUpdateDeviation;

    uint256 lastPrice;

    uint256 public stTokenBalance;
    uint256 public assetBalance;

    GlobalState internal _globalState;

    mapping(address node => NodeState state) internal _nodeState;

    mapping(address manager => bool whitelisted) public managerWhitelisted;

    mapping(address node => bool whitelisted) public nodeWhitelisted;

    struct SettleDepositVars {
        uint256 globalPendingDepositRequest;
        uint256 totalPendingDepositRequestCheck;
        uint256 totalSharesToMint;
        uint256 totalAssetsToReimburse;
    }

    struct SettleRedeemVars {
        uint256 globalPendingRedeemRequest;
        uint256 totalPendingRedeemRequestCheck;
        uint256 totalAssetsToReturn;
        uint256 totalSharesToReimburse;
    }

    constructor(address subRedManagement_, address registry_, address digiftEventVerifier_)
        RegistryAccessControl(registry_)
    {
        subRedManagement = ISubRedManagement(subRedManagement_);
        digiftEventVerifier = DigiftEventVerifier(digiftEventVerifier_);
    }

    function initialize(
        address asset_,
        address assetPriceOracle_,
        address stToken_,
        address dFeedPriceOracle_,
        string memory name_,
        string memory symbol_,
        uint64 priceDeviation_,
        uint64 priceUpdateDeviation_
    ) external initializer {
        __ERC20_init(name_, symbol_);

        asset = asset_;
        assetPriceOracle = IPriceOracle(assetPriceOracle_);
        _assetPriceOracleDecimals = IPriceOracle(assetPriceOracle_).decimals();
        stToken = stToken_;
        _assetDecimals = IERC20Metadata(asset_).decimals();
        _stTokenDecimals = IERC20Metadata(stToken_).decimals();
        dFeedPriceOracle = IDFeedPriceOracle(dFeedPriceOracle_);
        _dFeedPriceOracleDecimals = IDFeedPriceOracle(dFeedPriceOracle_).decimals();
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
        NodeState memory nodeState = _nodeState[msg.sender];
        require(nodeState.pendingDepositRequest == 0, DepositRequestPending());
        require(nodeState.maxMint == 0, DepositRequestNotClaimed());
        require(nodeState.pendingRedeemRequest == 0, RedeemRequestPending());
        require(nodeState.maxWithdraw == 0, RedeemRequestNotClaimed());
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

    function setManager(address manager, bool whitelisted) external onlyRegistryOwner {
        managerWhitelisted[manager] = whitelisted;
        emit ManagerWhitelistChange(manager, whitelisted);
    }

    function setNode(address node, bool whitelisted) external onlyRegistryOwner {
        require(registry.isNode(node), NotNode());
        nodeWhitelisted[node] = whitelisted;
        emit NodeWhitelistChange(node, whitelisted);
    }

    modifier onlyManager() {
        require(managerWhitelisted[msg.sender] == true, NotManager(msg.sender));
        _;
    }

    modifier onlyWhitelistedNode() {
        require(nodeWhitelisted[msg.sender] == true, NotWhitelistedNode(msg.sender));
        _;
    }

    function forceUpdateLastPrice() external onlyRegistryOwner {
        uint256 price = dFeedPriceOracle.getPrice();
        lastPrice = price;
        emit LastPriceUpdate(price);
    }

    function updateLastPrice() external onlyManager {
        uint256 price = _getPrice();
        lastPrice = price;
        emit LastPriceUpdate(price);
    }

    function _getPrice() internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = dFeedPriceOracle.latestRoundData();
        require(answer > 0, BadPriceOracle(address(dFeedPriceOracle)));
        uint256 price = uint256(answer);
        require(MathLib._withinRange(lastPrice, price, priceDeviation), PriceNotInRange(lastPrice, price));
        require(block.timestamp - updatedAt <= priceUpdateDeviation, StalePriceData(updatedAt, block.timestamp));
        return price;
    }

    function _getAssetPrice() internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = assetPriceOracle.latestRoundData();
        require(answer > 0, BadPriceOracle(address(assetPriceOracle)));
        uint256 price = uint256(answer);
        require(block.timestamp - updatedAt <= priceUpdateDeviation, StalePriceData(updatedAt, block.timestamp));
        return price;
    }

    function requestDeposit(uint256 assets, address controller, address owner)
        external
        onlyWhitelistedNode
        returns (uint256)
    {
        _actionValidation(assets, controller, owner);
        _nothingPending();

        _nodeState[msg.sender].pendingDepositRequest = assets;
        _globalState.accumulatedDeposit += assets;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    function settleDeposit(address[] calldata nodes, DigiftEventVerifier.OffchainArgs calldata verifyArgs)
        external
        onlyManager
    {
        (uint256 shares, uint256 assets) = digiftEventVerifier.verifySettlementEvent(
            verifyArgs,
            DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.SUBSCRIBE, address(subRedManagement), stToken, asset
            )
        );
        SettleDepositVars memory vars;
        vars.globalPendingDepositRequest = _globalState.pendingDepositRequest;
        require(vars.globalPendingDepositRequest > 0, NothingToSettle());

        for (uint256 i; i < nodes.length; i++) {
            NodeState storage node = _nodeState[nodes[i]];

            uint256 nodePendingDepositRequest = node.pendingDepositRequest;
            uint256 assetsToReimburse = nodePendingDepositRequest.mulDiv(assets, vars.globalPendingDepositRequest);
            uint256 sharesToMint = nodePendingDepositRequest.mulDiv(shares, vars.globalPendingDepositRequest);

            vars.totalPendingDepositRequestCheck += nodePendingDepositRequest;
            vars.totalSharesToMint += sharesToMint;
            vars.totalAssetsToReimburse += assetsToReimburse;

            // to avoid dust accumulation
            if (i == nodes.length - 1) {
                if (vars.totalSharesToMint < shares || vars.totalAssetsToReimburse < assets) {
                    sharesToMint += shares - vars.totalSharesToMint;
                    assetsToReimburse += assets - vars.totalAssetsToReimburse;
                }
            }

            node.claimableDepositRequest = nodePendingDepositRequest;
            node.pendingDepositRequest = 0;
            node.maxMint = sharesToMint;
            node.pendingDepositReimbursement = assetsToReimburse;

            emit DepositSettled(nodes[i], sharesToMint, assetsToReimburse);
        }

        require(vars.totalPendingDepositRequestCheck == vars.globalPendingDepositRequest, "Not all nodes are settled");
        _globalState.pendingDepositRequest = 0;
    }

    function mint(uint256 shares, address receiver, address controller)
        public
        onlyWhitelistedNode
        returns (uint256 assets)
    {
        _actionValidation(shares, controller, receiver);
        NodeState storage node = _nodeState[msg.sender];
        require(node.claimableDepositRequest > 0, DepositRequestNotFulfilled());
        require(node.maxMint == shares, MintAllSharesOnly());

        assets = node.claimableDepositRequest;

        uint256 assetsToReimburse = node.pendingDepositReimbursement;

        node.claimableDepositRequest = 0;
        node.maxMint = 0;
        node.pendingDepositReimbursement = 0;

        _mint(msg.sender, shares);

        // if assets are partially used => send back to the node
        if (assetsToReimburse > 0) {
            IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);
        }
        emit Deposit(controller, receiver, assets - assetsToReimburse, shares);
    }

    function requestRedeem(uint256 shares, address controller, address owner)
        external
        onlyWhitelistedNode
        returns (uint256)
    {
        _actionValidation(shares, controller, owner);
        _nothingPending();

        _nodeState[msg.sender].pendingRedeemRequest = shares;
        _globalState.accumulatedRedemption += shares;

        _spendAllowance(msg.sender, address(this), shares);
        _transfer(msg.sender, address(this), shares);

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function settleRedeem(address[] calldata nodes, DigiftEventVerifier.OffchainArgs calldata verifyArgs)
        external
        onlyManager
    {
        (uint256 shares, uint256 assets) = digiftEventVerifier.verifySettlementEvent(
            verifyArgs,
            DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), stToken, asset
            )
        );
        SettleRedeemVars memory vars;
        vars.globalPendingRedeemRequest = _globalState.pendingRedeemRequest;
        require(vars.globalPendingRedeemRequest > 0, NothingToSettle());

        for (uint256 i; i < nodes.length; i++) {
            NodeState storage node = _nodeState[nodes[i]];

            uint256 nodePendingRedeemRequest = node.pendingRedeemRequest;
            uint256 assetsToReturn = nodePendingRedeemRequest.mulDiv(assets, vars.globalPendingRedeemRequest);
            uint256 sharesToReimburse = nodePendingRedeemRequest.mulDiv(shares, vars.globalPendingRedeemRequest);

            vars.totalPendingRedeemRequestCheck += nodePendingRedeemRequest;
            vars.totalAssetsToReturn += assetsToReturn;
            vars.totalSharesToReimburse += sharesToReimburse;

            // to avoid dust accumulation
            if (i == nodes.length - 1) {
                if (vars.totalAssetsToReturn < assets || vars.totalSharesToReimburse < shares) {
                    assetsToReturn += assets - vars.totalAssetsToReturn;
                    sharesToReimburse += shares - vars.totalSharesToReimburse;
                }
            }

            node.claimableRedeemRequest = nodePendingRedeemRequest;
            node.pendingRedeemRequest = 0;
            node.maxWithdraw = assetsToReturn;
            node.pendingRedeemReimbursement = sharesToReimburse;

            emit RedeemSettled(nodes[i], sharesToReimburse, assetsToReturn);
        }

        require(vars.totalPendingRedeemRequestCheck == vars.globalPendingRedeemRequest, "Not all nodes are settled");
        _globalState.pendingRedeemRequest = 0;
    }

    function withdraw(uint256 assets, address receiver, address controller)
        external
        onlyWhitelistedNode
        returns (uint256 shares)
    {
        _actionValidation(assets, controller, receiver);

        require(_nodeState[msg.sender].claimableRedeemRequest > 0, RedeemRequestNotFulfilled());
        require(_nodeState[msg.sender].maxWithdraw == assets, WithdrawAllAssetsOnly());

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

    function forwardRequestsToDigift() external onlyManager {
        require(_globalState.pendingDepositRequest == 0, DepositRequestPending());
        require(_globalState.pendingRedeemRequest == 0, RedeemRequestPending());

        uint256 pendingAssets = _globalState.accumulatedDeposit;
        if (pendingAssets > 0) {
            _globalState.accumulatedDeposit = 0;
            _globalState.pendingDepositRequest = pendingAssets;
            IERC20(asset).safeIncreaseAllowance(address(subRedManagement), pendingAssets);
            subRedManagement.subscribe(stToken, asset, pendingAssets, block.timestamp + 1);
            emit DigiftSubscribed(pendingAssets);
        }

        uint256 pendingShares = _globalState.accumulatedRedemption;
        if (pendingShares > 0) {
            _globalState.accumulatedRedemption = 0;
            _globalState.pendingRedeemRequest = pendingShares;
            IERC20(stToken).safeIncreaseAllowance(address(subRedManagement), pendingShares);
            subRedManagement.redeem(stToken, asset, pendingShares, block.timestamp + 1);
            emit DigiftRedeemed(pendingShares);
        }
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
        return assets * 10 ** (_stTokenDecimals + _dFeedPriceOracleDecimals) / (stTokenPrice * 10 ** (_assetDecimals))
            * _getAssetPrice() / 10 ** _assetPriceOracleDecimals;
    }

    function _convertToAssets(uint256 shares, uint256 stTokenPrice) internal view returns (uint256 assets) {
        return (shares * stTokenPrice * 10 ** (_assetDecimals) / 10 ** (_stTokenDecimals + _dFeedPriceOracleDecimals))
            * 10 ** _assetPriceOracleDecimals / _getAssetPrice();
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
