// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import {ISubRedManagement, IDFeedPriceOracle} from "src/interfaces/external/IDigift.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";
import {IPriceOracle} from "src/interfaces/external/IPriceOracle.sol";
import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import {DigiftEventVerifier} from "./DigiftEventVerifier.sol";

/**
 * @title NodeState
 * @notice Represents the state of a node for deposit and redemption operations
 * @dev Tracks pending requests, claimable amounts, and reimbursement details
 */
struct NodeState {
    /// @notice Maximum shares that can be minted for this node
    uint256 maxMint;
    /// @notice Maximum assets that can be withdrawn for this node
    uint256 maxWithdraw;
    /// @notice Amount of assets pending deposit request
    uint256 pendingDepositRequest;
    /// @notice Amount of assets to be reimbursed after deposit settlement
    uint256 pendingDepositReimbursement;
    /// @notice Amount of shares pending redemption request
    uint256 pendingRedeemRequest;
    /// @notice Amount of shares to be reimbursed after redemption settlement
    uint256 pendingRedeemReimbursement;
    /// @notice Amount of assets claimable after deposit settlement
    uint256 claimableDepositRequest;
    /// @notice Amount of shares claimable after redemption settlement
    uint256 claimableRedeemRequest;
}

/**
 * @title GlobalState
 * @notice Represents the global state of the wrapper contract
 * @dev Tracks accumulated deposits/redemptions and pending requests across all nodes
 */
struct GlobalState {
    /// @notice Total accumulated deposits from all nodes
    uint256 accumulatedDeposit;
    /// @notice Total accumulated redemptions from all nodes
    uint256 accumulatedRedemption;
    /// @notice Total pending deposit requests across all nodes
    uint256 pendingDepositRequest;
    /// @notice Total pending redemption requests across all nodes
    uint256 pendingRedeemRequest;
}

/**
 * @title DigiftWrapper
 * @notice ERC7540-compatible wrapper for Digift stToken operations
 */
contract DigiftWrapper is ERC20Upgradeable, ReentrancyGuardUpgradeable, RegistryAccessControl, IERC7540, IERC7575 {
    using SafeERC20 for IERC20;
    using MathLib for uint256;

    // =============================
    //            Errors
    // =============================

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when controller is not the message sender
    error ControllerNotSender();

    /// @notice Thrown when owner is not the message sender
    error OwnerNotSender();

    /// @notice Thrown when a deposit request is already pending
    error DepositRequestPending();

    /// @notice Thrown when deposit request has not been claimed yet
    error DepositRequestNotClaimed();

    /// @notice Thrown when a redemption request is already pending
    error RedeemRequestPending();

    /// @notice Thrown when redemption request has not been claimed yet
    error RedeemRequestNotClaimed();

    /// @notice Thrown when deposit request has not been fulfilled
    error DepositRequestNotFulfilled();

    /// @notice Thrown when redemption request has not been fulfilled
    error RedeemRequestNotFulfilled();

    /// @notice Thrown when trying to mint partial shares instead of all available
    error MintAllSharesOnly();

    /// @notice Thrown when trying to withdraw partial assets instead of all available
    error WithdrawAllAssetsOnly();

    /// @notice Thrown when there's nothing to settle
    error NothingToSettle();

    /// @notice Thrown when function is not supported
    error Unsupported();

    /// @notice Thrown when percentage value is invalid
    error InvalidPercentage();

    /// @notice Thrown when price is not within acceptable range
    /// @param lastValue The last known price value
    /// @param currentValue The current price value
    error PriceNotInRange(uint256 lastValue, uint256 currentValue);

    /// @notice Thrown when price data is stale
    /// @param lastUpdate Timestamp of last price update
    /// @param currentTimestamp Current block timestamp
    error StalePriceData(uint256 lastUpdate, uint256 currentTimestamp);

    /// @notice Thrown when address is not a registered node
    error NotNode();

    /// @notice Thrown when caller is not a whitelisted manager
    /// @param caller The address that attempted the action
    error NotManager(address caller);

    /// @notice Thrown when node is not whitelisted
    /// @param node The node address that is not whitelisted
    error NotWhitelistedNode(address node);

    /// @notice Thrown when price oracle returns invalid data
    /// @param oracle The address of the problematic oracle
    error BadPriceOracle(address oracle);

    /// @notice Thrown when not all nodes have been settled
    error NotAllNodesSettled();

    // =============================
    //            Events
    // =============================

    /// @notice Emitted when a deposit is settled for a node
    /// @param node The node address
    /// @param shares The number of shares minted
    /// @param assets The amount of assets settled
    event DepositSettled(address indexed node, uint256 shares, uint256 assets);

    /// @notice Emitted when a redemption is settled for a node
    /// @param node The node address
    /// @param shares The number of shares redeemed
    /// @param assets The amount of assets returned
    event RedeemSettled(address indexed node, uint256 shares, uint256 assets);

    /// @notice Emitted when price deviation threshold is changed
    /// @param oldValue The previous price deviation value
    /// @param newValue The new price deviation value
    event PriceDeviationChange(uint64 oldValue, uint64 newValue);

    /// @notice Emitted when price update deviation threshold is changed
    /// @param oldValue The previous price update deviation value
    /// @param newValue The new price update deviation value
    event PriceUpdateDeviationChange(uint64 oldValue, uint64 newValue);

    /// @notice Emitted when a manager's whitelist status changes
    /// @param manager The manager address
    /// @param whitelisted Whether the manager is whitelisted
    event ManagerWhitelistChange(address indexed manager, bool whitelisted);

    /// @notice Emitted when a node's whitelist status changes
    /// @param node The node address
    /// @param whitelisted Whether the node is whitelisted
    event NodeWhitelistChange(address indexed node, bool whitelisted);

    /// @notice Emitted when the last price is updated
    /// @param price The updated price value
    event LastPriceUpdate(uint256 price);

    /// @notice Emitted when assets are subscribed to Digift
    /// @param assets The amount of assets subscribed
    event DigiftSubscribed(uint256 assets);

    /// @notice Emitted when shares are redeemed from Digift
    /// @param shares The amount of shares redeemed
    event DigiftRedeemed(uint256 shares);

    // =============================
    //         Immutable Variables
    // =============================

    /// @notice WAD constant for 100% percent limit
    uint256 constant WAD = 1e18;

    /// @notice Request ID constant (always 0 for this implementation)
    uint256 private constant REQUEST_ID = 0;

    /// @notice Digift subscription/redemption management contract
    ISubRedManagement public immutable subRedManagement;

    /// @notice Digift event verifier for settlement validation
    DigiftEventVerifier public immutable digiftEventVerifier;

    // =============================
    //         State Variables
    // =============================

    /// @notice The underlying asset token address
    address public asset;

    /// @notice Number of decimals for the asset token
    uint8 internal _assetDecimals;

    /// @notice Price oracle for the underlying asset
    IPriceOracle public assetPriceOracle;

    /// @notice Number of decimals for the asset price oracle
    uint8 internal _assetPriceOracleDecimals;

    /// @notice The Digift stToken address
    address public stToken;

    /// @notice Number of decimals for the stToken
    uint8 internal _stTokenDecimals;

    /// @notice Digift price oracle for stToken pricing
    IDFeedPriceOracle public dFeedPriceOracle;

    /// @notice Number of decimals for the Digift price oracle
    uint8 internal _dFeedPriceOracleDecimals;

    /// @notice Maximum price deviation allowed (1e18 = 100%)
    uint64 public priceDeviation;

    /// @notice Maximum time deviation for price updates (in seconds)
    uint64 public priceUpdateDeviation;

    /// @notice Last cached price from Digift oracle
    uint256 public lastPrice;

    /// @notice Global state tracking accumulated deposits and redemptions
    GlobalState internal _globalState;

    /// @notice Mapping of node addresses to their individual states
    mapping(address node => NodeState state) internal _nodeState;

    /// @notice Mapping of manager addresses to their whitelist status
    mapping(address manager => bool whitelisted) public managerWhitelisted;

    /// @notice Mapping of node addresses to their whitelist status
    mapping(address node => bool whitelisted) public nodeWhitelisted;

    // =============================
    //         Struct Definitions
    // =============================

    /**
     * @title InitArgs
     * @notice Initialization arguments for the DigiftWrapper
     * @dev Contains all necessary parameters to initialize the contract
     */
    struct InitArgs {
        /// @notice Name of the wrapper token
        string name;
        /// @notice Symbol of the wrapper token
        string symbol;
        /// @notice Address of the underlying asset token
        address asset;
        /// @notice Address of the asset price oracle
        address assetPriceOracle;
        /// @notice Address of the Digift stToken
        address stToken;
        /// @notice Address of the Digift price oracle
        address dFeedPriceOracle;
        /// @notice Maximum price deviation allowed (in basis points)
        uint64 priceDeviation;
        /// @notice Maximum time deviation for price updates (in seconds)
        uint64 priceUpdateDeviation;
    }

    /**
     * @title SettleDepositVars
     * @notice Variables used during deposit settlement
     */
    struct SettleDepositVars {
        /// @notice Global pending deposit request amount
        uint256 globalPendingDepositRequest;
        /// @notice Total pending deposit request check for validation
        uint256 totalPendingDepositRequestCheck;
        /// @notice Total shares to mint across all nodes
        uint256 totalSharesToMint;
        /// @notice Total assets to reimburse across all nodes
        uint256 totalAssetsToReimburse;
    }

    /**
     * @title SettleRedeemVars
     * @notice Variables used during redemption settlement
     */
    struct SettleRedeemVars {
        /// @notice Global pending redemption request amount
        uint256 globalPendingRedeemRequest;
        /// @notice Total pending redemption request check for validation
        uint256 totalPendingRedeemRequestCheck;
        /// @notice Total assets to return across all nodes
        uint256 totalAssetsToReturn;
        /// @notice Total shares to reimburse across all nodes
        uint256 totalSharesToReimburse;
    }

    // =============================
    //         Constructor
    // =============================

    /**
     * @notice Constructor for DigiftWrapper
     * @dev Sets up immutable dependencies
     * @param subRedManagement_ Address of the Digift subscription/redemption management contract
     * @param registry_ Address of the registry contract for access control
     * @param digiftEventVerifier_ Address of the Digift event verifier contract
     */
    constructor(address subRedManagement_, address registry_, address digiftEventVerifier_)
        RegistryAccessControl(registry_)
    {
        subRedManagement = ISubRedManagement(subRedManagement_);
        digiftEventVerifier = DigiftEventVerifier(digiftEventVerifier_);
    }

    // =============================
    //         Initialization
    // =============================

    /**
     * @notice Initialize the DigiftWrapper contract
     * @dev Sets up all token parameters, oracles, and initial price
     * @param args Initialization arguments containing all necessary parameters
     */
    function initialize(InitArgs calldata args) external initializer {
        __ERC20_init(args.name, args.symbol);
        __ReentrancyGuard_init();

        // Set up asset token and its oracle
        asset = args.asset;
        assetPriceOracle = IPriceOracle(args.assetPriceOracle);
        _assetPriceOracleDecimals = IPriceOracle(args.assetPriceOracle).decimals();
        _assetDecimals = IERC20Metadata(args.asset).decimals();

        // Set up stToken and its oracle
        stToken = args.stToken;
        _stTokenDecimals = IERC20Metadata(args.stToken).decimals();
        dFeedPriceOracle = IDFeedPriceOracle(args.dFeedPriceOracle);
        _dFeedPriceOracleDecimals = IDFeedPriceOracle(args.dFeedPriceOracle).decimals();

        // Set price deviation parameters
        priceDeviation = args.priceDeviation;
        priceUpdateDeviation = args.priceUpdateDeviation;

        // Initialize price cache with current Digift price
        lastPrice = dFeedPriceOracle.getPrice();
    }

    // =============================
    //         Internal Functions
    // =============================

    /**
     * @notice Validates action parameters for deposit/redemption operations
     * @dev Ensures amount is positive and caller is authorized
     * @param amount The amount to validate
     * @param controller The controller address
     * @param owner The owner address
     */
    function _actionValidation(uint256 amount, address controller, address owner) internal {
        require(amount > 0, ZeroAmount());
        require(controller == msg.sender, ControllerNotSender());
        require(owner == msg.sender, OwnerNotSender());
    }

    /**
     * @notice Checks that no pending operations exist for the calling node
     * @dev Prevents multiple concurrent operations from the same node
     */
    function _nothingPending() internal {
        NodeState memory nodeState = _nodeState[msg.sender];
        require(nodeState.pendingDepositRequest == 0, DepositRequestPending());
        require(nodeState.maxMint == 0, DepositRequestNotClaimed());
        require(nodeState.pendingRedeemRequest == 0, RedeemRequestPending());
        require(nodeState.maxWithdraw == 0, RedeemRequestNotClaimed());
    }

    // =============================
    //         Admin Functions
    // =============================

    /**
     * @notice Set the maximum price deviation allowed
     * @dev Only callable by registry owner, value must be <= WAD (100%)
     * @param value The new price deviation threshold (in basis points)
     */
    function setPriceDeviation(uint64 value) external onlyRegistryOwner {
        require(value <= WAD, InvalidPercentage());
        emit PriceDeviationChange(priceDeviation, value);
        priceDeviation = value;
    }

    /**
     * @notice Set the maximum time deviation for price updates
     * @dev Only callable by registry owner
     * @param value The new price update deviation threshold (in seconds)
     */
    function setPriceUpdateDeviation(uint64 value) external onlyRegistryOwner {
        emit PriceUpdateDeviationChange(priceUpdateDeviation, value);
        priceUpdateDeviation = value;
    }

    /**
     * @notice Set manager whitelist status
     * @dev Only callable by registry owner
     * @param manager The manager address to whitelist/unwhitelist
     * @param whitelisted Whether the manager should be whitelisted
     */
    function setManager(address manager, bool whitelisted) external onlyRegistryOwner {
        managerWhitelisted[manager] = whitelisted;
        emit ManagerWhitelistChange(manager, whitelisted);
    }

    /**
     * @notice Set node whitelist status
     * @dev Only callable by registry owner, node must be registered in registry
     * @param node The node address to whitelist/unwhitelist
     * @param whitelisted Whether the node should be whitelisted
     */
    function setNode(address node, bool whitelisted) external onlyRegistryOwner {
        require(registry.isNode(node), NotNode());
        nodeWhitelisted[node] = whitelisted;
        emit NodeWhitelistChange(node, whitelisted);
    }

    // =============================
    //            Modifiers
    // =============================

    /**
     * @notice Modifier to restrict access to whitelisted managers only
     */
    modifier onlyManager() {
        require(managerWhitelisted[msg.sender] == true, NotManager(msg.sender));
        _;
    }

    /**
     * @notice Modifier to restrict access to whitelisted nodes only
     */
    modifier onlyWhitelistedNode() {
        require(nodeWhitelisted[msg.sender] == true, NotWhitelistedNode(msg.sender));
        _;
    }

    // =============================
    //      Price Management
    // =============================

    /**
     * @notice Force update the last price without deviation checks
     * @dev Only callable by registry owner, bypasses normal price validation
     */
    function forceUpdateLastPrice() external onlyRegistryOwner {
        uint256 price = dFeedPriceOracle.getPrice();
        lastPrice = price;
        emit LastPriceUpdate(price);
    }

    /**
     * @notice Update the last price with deviation checks
     * @dev Only callable by whitelisted managers, enforces price deviation limits
     */
    function updateLastPrice() external onlyManager {
        uint256 price = _getPrice();
        lastPrice = price;
        emit LastPriceUpdate(price);
    }

    /**
     * @notice Get the current Digift price with validation
     * @dev Validates price deviation and staleness
     * @return The validated current price
     */
    function _getPrice() internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = dFeedPriceOracle.latestRoundData();
        require(answer > 0, BadPriceOracle(address(dFeedPriceOracle)));
        uint256 price = uint256(answer);

        // Check if price is within acceptable deviation from last known price
        require(MathLib.withinRange(lastPrice, price, priceDeviation), PriceNotInRange(lastPrice, price));

        // Check if price data is not stale
        require(block.timestamp - updatedAt <= priceUpdateDeviation, StalePriceData(updatedAt, block.timestamp));

        return price;
    }

    /**
     * @notice Get the current asset price with validation
     * @dev Validates price staleness for the underlying asset
     * @return The validated current asset price
     */
    function _getAssetPrice() internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = assetPriceOracle.latestRoundData();
        require(answer > 0, BadPriceOracle(address(assetPriceOracle)));
        uint256 price = uint256(answer);

        // Check if price data is not stale
        require(block.timestamp - updatedAt <= priceUpdateDeviation, StalePriceData(updatedAt, block.timestamp));

        return price;
    }

    // =============================
    //      Deposit Functions
    // =============================

    /**
     * @notice Request a deposit of assets from a whitelisted node
     * @dev Transfers assets from node to contract and tracks the request
     * @param assets The amount of assets to deposit
     * @param controller The controller address (must be msg.sender)
     * @param owner The owner address (must be msg.sender)
     * @return The request ID (always 0 in this implementation)
     */
    function requestDeposit(uint256 assets, address controller, address owner)
        external
        onlyWhitelistedNode
        nonReentrant
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

    /**
     * @notice Settle deposit requests for multiple nodes
     * @dev Verifies Digift settlement event and distributes shares/assets proportionally
     * @param nodes Array of node addresses to settle
     * @param verifyArgs Offchain arguments for event verification
     */
    function settleDeposit(address[] calldata nodes, DigiftEventVerifier.OffchainArgs calldata verifyArgs)
        external
        nonReentrant
        onlyManager
    {
        // Verify the Digift settlement event and get shares/assets amounts
        (uint256 shares, uint256 assets) = digiftEventVerifier.verifySettlementEvent(
            verifyArgs,
            DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.SUBSCRIBE, address(subRedManagement), stToken, asset
            )
        );

        SettleDepositVars memory vars;
        vars.globalPendingDepositRequest = _globalState.pendingDepositRequest;
        require(vars.globalPendingDepositRequest > 0, NothingToSettle());

        // Process each node's deposit request
        for (uint256 i; i < nodes.length; i++) {
            NodeState storage node = _nodeState[nodes[i]];

            uint256 nodePendingDepositRequest = node.pendingDepositRequest;

            // Calculate proportional shares and assets for this node
            uint256 assetsToReimburse = nodePendingDepositRequest.mulDiv(assets, vars.globalPendingDepositRequest);
            uint256 sharesToMint = nodePendingDepositRequest.mulDiv(shares, vars.globalPendingDepositRequest);

            // Track totals for validation
            vars.totalPendingDepositRequestCheck += nodePendingDepositRequest;
            vars.totalSharesToMint += sharesToMint;
            vars.totalAssetsToReimburse += assetsToReimburse;

            // Handle dust accumulation on the last node
            if (i == nodes.length - 1) {
                if (vars.totalSharesToMint < shares || vars.totalAssetsToReimburse < assets) {
                    sharesToMint += shares - vars.totalSharesToMint;
                    assetsToReimburse += assets - vars.totalAssetsToReimburse;
                }
            }

            // Update node state
            node.claimableDepositRequest = nodePendingDepositRequest;
            node.pendingDepositRequest = 0;
            node.maxMint = sharesToMint;
            node.pendingDepositReimbursement = assetsToReimburse;

            emit DepositSettled(nodes[i], sharesToMint, assetsToReimburse);
        }

        // Validate that all nodes have been processed
        require(vars.totalPendingDepositRequestCheck == vars.globalPendingDepositRequest, NotAllNodesSettled());
        _globalState.pendingDepositRequest = 0;
    }

    /**
     * @notice Mint shares for a node after deposit settlement
     * @dev Mints shares and handles asset reimbursement for unused assets
     * @param shares The number of shares to mint (must match maxMint)
     * @param receiver The address to receive the shares
     * @param controller The controller address (must be msg.sender)
     * @return assets The amount of assets used for the deposit
     */
    function mint(uint256 shares, address receiver, address controller)
        public
        onlyWhitelistedNode
        nonReentrant
        returns (uint256 assets)
    {
        _actionValidation(shares, controller, receiver);
        NodeState storage node = _nodeState[msg.sender];

        // Ensure deposit request has been fulfilled and exact shares are minted
        require(node.claimableDepositRequest > 0, DepositRequestNotFulfilled());
        require(node.maxMint == shares, MintAllSharesOnly());

        assets = node.claimableDepositRequest;
        uint256 assetsToReimburse = node.pendingDepositReimbursement;

        // Clear node state
        node.claimableDepositRequest = 0;
        node.maxMint = 0;
        node.pendingDepositReimbursement = 0;

        // Mint shares to the node
        _mint(msg.sender, shares);

        // Reimburse unused assets to the node
        if (assetsToReimburse > 0) {
            IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);
        }

        emit Deposit(controller, receiver, assets - assetsToReimburse, shares);
    }

    // =============================
    //     Redemption Functions
    // =============================

    /**
     * @notice Request a redemption of shares from a whitelisted node
     * @dev Transfers shares from node to contract and tracks the request
     * @param shares The number of shares to redeem
     * @param controller The controller address (must be msg.sender)
     * @param owner The owner address (must be msg.sender)
     * @return The request ID (always 0 in this implementation)
     */
    function requestRedeem(uint256 shares, address controller, address owner)
        external
        onlyWhitelistedNode
        nonReentrant
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

    /**
     * @notice Settle redemption requests for multiple nodes
     * @dev Verifies Digift redemption event and distributes assets/shares proportionally
     * @param nodes Array of node addresses to settle
     * @param verifyArgs Offchain arguments for event verification
     */
    function settleRedeem(address[] calldata nodes, DigiftEventVerifier.OffchainArgs calldata verifyArgs)
        external
        nonReentrant
        onlyManager
    {
        // Verify the Digift redemption event and get shares/assets amounts
        (uint256 shares, uint256 assets) = digiftEventVerifier.verifySettlementEvent(
            verifyArgs,
            DigiftEventVerifier.OnchainArgs(
                DigiftEventVerifier.EventType.REDEEM, address(subRedManagement), stToken, asset
            )
        );

        SettleRedeemVars memory vars;
        vars.globalPendingRedeemRequest = _globalState.pendingRedeemRequest;
        require(vars.globalPendingRedeemRequest > 0, NothingToSettle());

        // Process each node's redemption request
        for (uint256 i; i < nodes.length; i++) {
            NodeState storage node = _nodeState[nodes[i]];

            uint256 nodePendingRedeemRequest = node.pendingRedeemRequest;

            // Calculate proportional assets and shares for this node
            uint256 assetsToReturn = nodePendingRedeemRequest.mulDiv(assets, vars.globalPendingRedeemRequest);
            uint256 sharesToReimburse = nodePendingRedeemRequest.mulDiv(shares, vars.globalPendingRedeemRequest);

            // Track totals for validation
            vars.totalPendingRedeemRequestCheck += nodePendingRedeemRequest;
            vars.totalAssetsToReturn += assetsToReturn;
            vars.totalSharesToReimburse += sharesToReimburse;

            // Handle dust accumulation on the last node
            if (i == nodes.length - 1) {
                if (vars.totalAssetsToReturn < assets || vars.totalSharesToReimburse < shares) {
                    assetsToReturn += assets - vars.totalAssetsToReturn;
                    sharesToReimburse += shares - vars.totalSharesToReimburse;
                }
            }

            // Update node state
            node.claimableRedeemRequest = nodePendingRedeemRequest;
            node.pendingRedeemRequest = 0;
            node.maxWithdraw = assetsToReturn;
            node.pendingRedeemReimbursement = sharesToReimburse;

            emit RedeemSettled(nodes[i], sharesToReimburse, assetsToReturn);
        }

        // Validate that all nodes have been processed
        require(vars.totalPendingRedeemRequestCheck == vars.globalPendingRedeemRequest, NotAllNodesSettled());
        _globalState.pendingRedeemRequest = 0;
    }

    /**
     * @notice Withdraw assets for a node after redemption settlement
     * @dev Burns shares and transfers assets, handles share reimbursement for unused shares
     * @param assets The amount of assets to withdraw (must match maxWithdraw)
     * @param receiver The address to receive the assets
     * @param controller The controller address (must be msg.sender)
     * @return shares The number of shares burned
     */
    function withdraw(uint256 assets, address receiver, address controller)
        external
        onlyWhitelistedNode
        nonReentrant
        returns (uint256 shares)
    {
        _actionValidation(assets, controller, receiver);

        // Ensure redemption request has been fulfilled and exact assets are withdrawn
        require(_nodeState[msg.sender].claimableRedeemRequest > 0, RedeemRequestNotFulfilled());
        require(_nodeState[msg.sender].maxWithdraw == assets, WithdrawAllAssetsOnly());

        shares = _nodeState[msg.sender].claimableRedeemRequest;
        uint256 sharesToReimburse = _nodeState[msg.sender].pendingRedeemReimbursement;
        uint256 sharesToBurn = shares - sharesToReimburse;

        // Clear node state
        _nodeState[msg.sender].claimableRedeemRequest = 0;
        _nodeState[msg.sender].maxWithdraw = 0;
        _nodeState[msg.sender].pendingRedeemReimbursement = 0;

        // Burn shares that were actually used
        _burn(address(this), sharesToBurn);

        // Reimburse unused shares to the node
        if (sharesToReimburse > 0) {
            _transfer(address(this), msg.sender, sharesToReimburse);
        }

        // Transfer assets to the node
        IERC20(asset).safeTransfer(msg.sender, assets);
        emit Withdraw(msg.sender, receiver, controller, assets, shares - sharesToReimburse);
    }

    // =============================
    //    Digift Integration
    // =============================

    /**
     * @notice Forward accumulated requests to Digift protocol
     * @dev Subscribes accumulated deposits and redeems accumulated redemptions
     * @dev Only callable by whitelisted managers when no pending requests exist
     */
    function forwardRequestsToDigift() external onlyManager nonReentrant {
        // Ensure no pending requests exist before forwarding
        require(_globalState.pendingDepositRequest == 0, DepositRequestPending());
        require(_globalState.pendingRedeemRequest == 0, RedeemRequestPending());

        // Handle accumulated deposits
        uint256 pendingAssets = _globalState.accumulatedDeposit;
        if (pendingAssets > 0) {
            _globalState.accumulatedDeposit = 0;
            _globalState.pendingDepositRequest = pendingAssets;

            // Approve and subscribe to Digift
            IERC20(asset).safeIncreaseAllowance(address(subRedManagement), pendingAssets);
            subRedManagement.subscribe(stToken, asset, pendingAssets, block.timestamp + 1);
            emit DigiftSubscribed(pendingAssets);
        }

        // Handle accumulated redemptions
        uint256 pendingShares = _globalState.accumulatedRedemption;
        if (pendingShares > 0) {
            _globalState.accumulatedRedemption = 0;
            _globalState.pendingRedeemRequest = pendingShares;

            // Approve and redeem from Digift
            IERC20(stToken).safeIncreaseAllowance(address(subRedManagement), pendingShares);
            subRedManagement.redeem(stToken, asset, pendingShares, block.timestamp + 1);
            emit DigiftRedeemed(pendingShares);
        }
    }

    // =============================
    //        View Functions
    // =============================

    /**
     * @notice Get the total accumulated deposits across all nodes
     * @return The total accumulated deposit amount
     */
    function accumulatedDeposit() external view returns (uint256) {
        return _globalState.accumulatedDeposit;
    }

    /**
     * @notice Get the total accumulated redemptions across all nodes
     * @return The total accumulated redemption amount
     */
    function accumulatedRedemption() external view returns (uint256) {
        return _globalState.accumulatedRedemption;
    }

    /**
     * @notice Get the global pending deposit request amount
     * @return The total pending deposit request amount
     */
    function globalPendingDepositRequest() external view returns (uint256) {
        return _globalState.pendingDepositRequest;
    }

    /**
     * @notice Get the global pending redemption request amount
     * @return The total pending redemption request amount
     */
    function globalPendingRedeemRequest() external view returns (uint256) {
        return _globalState.pendingRedeemRequest;
    }

    /**
     * @notice Get the pending deposit request for a specific controller
     * @param requestId The request ID (unused in this implementation)
     * @param controller The controller address
     * @return The pending deposit request amount
     */
    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256) {
        return _nodeState[controller].pendingDepositRequest;
    }

    /**
     * @notice Get the claimable deposit request for a specific controller
     * @param requestId The request ID (unused in this implementation)
     * @param controller The controller address
     * @return The claimable deposit request amount
     */
    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256) {
        return _nodeState[controller].claimableDepositRequest;
    }

    /**
     * @notice Get the pending redemption request for a specific controller
     * @param requestId The request ID (unused in this implementation)
     * @param controller The controller address
     * @return The pending redemption request amount
     */
    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256) {
        return _nodeState[controller].pendingRedeemRequest;
    }

    /**
     * @notice Get the claimable redemption request for a specific controller
     * @param requestId The request ID (unused in this implementation)
     * @param controller The controller address
     * @return The claimable redemption request amount
     */
    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256) {
        return _nodeState[controller].claimableRedeemRequest;
    }

    // =============================
    //    Interface Implementations
    // =============================

    /**
     * @notice Check if contract supports a specific interface
     * @dev Implements IERC165, IERC7575, IERC7540Deposit, and IERC7540Redeem
     * @param interfaceId The interface ID to check
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7575).interfaceId
            || interfaceId == type(IERC7540Deposit).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId;
    }

    // =============================
    //    ERC4626 Compatibility
    // =============================

    /**
     * @notice Get the total assets under management
     * @dev Calculates total assets based on current share price
     * @return The total assets value
     */
    function totalAssets() external view returns (uint256) {
        return convertToAssets(totalSupply());
    }

    /**
     * @notice Convert assets to shares using current price
     * @dev Uses current Digift price for conversion
     * @param assets The amount of assets to convert
     * @return shares The equivalent number of shares
     */
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, _getAssetPrice(), _getPrice());
    }

    /**
     * @notice Convert shares to assets using current price
     * @dev Uses current Digift price for conversion
     * @param shares The number of shares to convert
     * @return assets The equivalent amount of assets
     */
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, _getAssetPrice(), _getPrice());
    }

    /**
     * @notice Internal function to convert assets to shares
     * @dev Handles decimal precision and price conversions
     * @param assets The amount of assets to convert
     * @param assetPrice The current asset price
     * @param stTokenPrice The current stToken price
     * @return shares The equivalent number of shares
     */
    function _convertToShares(uint256 assets, uint256 assetPrice, uint256 stTokenPrice)
        internal
        view
        returns (uint256 shares)
    {
        uint256 num = MathLib.pow10(_stTokenDecimals + _dFeedPriceOracleDecimals);
        uint256 den = MathLib.pow10(_assetPriceOracleDecimals + _assetDecimals);
        return assets.mulDiv(num, stTokenPrice).mulDiv(assetPrice, den);
    }

    /**
     * @notice Internal function to convert shares to assets
     * @dev Handles decimal precis              ion and price conversions
     * @param shares The number of shares to convert
     * @param assetPrice The current asset price
     * @param stTokenPrice The current stToken price
     * @return assets The equivalent amount of assets
     */
    function _convertToAssets(uint256 shares, uint256 assetPrice, uint256 stTokenPrice)
        internal
        view
        returns (uint256 assets)
    {
        uint256 num = MathLib.pow10(_assetPriceOracleDecimals);
        // TODO: ensure no underflow? + Fuzz tests
        uint256 den = MathLib.pow10(_stTokenDecimals + _dFeedPriceOracleDecimals - _assetDecimals);
        return shares.mulDiv(stTokenPrice, den).mulDiv(num, assetPrice);
    }

    /**
     * @notice Get the maximum shares that can be minted for a controller
     * @param controller The controller address
     * @return The maximum mintable shares
     */
    function maxMint(address controller) public view returns (uint256) {
        return _nodeState[controller].maxMint;
    }

    /**
     * @notice Get the maximum assets that can be withdrawn for a controller
     * @param controller The controller address
     * @return The maximum withdrawable assets
     */
    function maxWithdraw(address controller) external view returns (uint256) {
        return _nodeState[controller].maxWithdraw;
    }

    /**
     * @notice Get the number of decimals for the token
     * @dev Returns the stToken decimals
     * @return The number of decimals
     */
    function decimals() public view override returns (uint8) {
        return _stTokenDecimals;
    }

    /**
     * @notice Get the share token address
     * @dev Returns the contract address as the share token
     * @return The share token address
     */
    function share() external view returns (address) {
        return address(this);
    }

    // =============================
    //      Unsupported Functions
    // =============================

    /**
     * @notice Unsupported function - use requestDeposit instead
     * @dev This function is not supported in this implementation
     */
    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - use requestDeposit instead
     * @dev This function is not supported in this implementation
     */
    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - use mint with controller instead
     * @dev This function is not supported in this implementation
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - use requestRedeem instead
     * @dev This function is not supported in this implementation
     */
    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - preview functions not supported
     * @dev This function is not supported in this implementation
     */
    function previewDeposit(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - preview functions not supported
     * @dev This function is not supported in this implementation
     */
    function previewMint(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - preview functions not supported
     * @dev This function is not supported in this implementation
     */
    function previewWithdraw(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - preview functions not supported
     * @dev This function is not supported in this implementation
     */
    function previewRedeem(uint256) external pure returns (uint256) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - maxRedeem not supported
     * @dev This function is not supported in this implementation
     */
    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - maxDeposit not supported
     * @dev This function is not supported in this implementation
     */
    function maxDeposit(address controller) public view returns (uint256 maxAssets) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - operator functionality not supported
     * @dev This function is not supported in this implementation
     */
    function setOperator(address operator, bool approved) external returns (bool) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported function - operator functionality not supported
     * @dev This function is not supported in this implementation
     */
    function isOperator(address controller, address operator) external view returns (bool) {
        revert Unsupported();
    }
}
