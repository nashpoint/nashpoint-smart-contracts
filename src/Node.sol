// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode, ComponentAllocation, NodeInitArgs, Request, IERC7575, IERC165} from "src/interfaces/INode.sol";
import {IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IQuoterV1} from "src/interfaces/IQuoterV1.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {INodeRegistry, RegistryType} from "src/interfaces/INodeRegistry.sol";
import {IPolicy} from "src/interfaces/IPolicy.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeLib} from "src/libraries/NodeLib.sol";

import {MulticallUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";

contract Node is INode, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, MulticallUpgradeable {
    using Address for address;
    using SafeERC20 for IERC20;
    using Math for uint256;

    /* IMMUTABLES & CONSTANTS */
    address public immutable registry;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant REQUEST_ID = 0;
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /* COMPONENTS */
    uint64 public targetReserveRatio;
    address public asset;
    address[] internal components;
    address[] internal liquidationsQueue;
    mapping(address => ComponentAllocation) internal componentAllocations;

    /* PROTOCOL ADDRESSES */
    IQuoterV1 public quoter;
    address public escrow;
    mapping(address => bool) public isRebalancer;
    mapping(address => bool) public isRouter;
    mapping(address => mapping(address => bool)) public isOperator;

    /* REBALANCE COOLDOWN */
    uint64 public rebalanceCooldown;
    uint64 public rebalanceWindow;
    uint64 public lastRebalance;

    /* FEES & ACCOUNTING */
    uint64 public annualManagementFee;
    uint64 public lastPayment;
    uint256 public maxDepositSize;
    uint256 public sharesExiting;
    uint256 internal cacheTotalAssets;
    address public nodeOwnerFeeAddress;
    mapping(address => Request) public requests;

    /* SWING PRICING */
    uint64 public maxSwingFactor;
    bool public swingPricingEnabled;

    mapping(bytes4 => address[]) internal policies;
    mapping(bytes4 => mapping(address => bool)) internal sigPolicy;
    uint8 internal _decimals;

    /* CONSTRUCTOR */
    constructor(address registry_) {
        _disableInitializers();
        registry = registry_;
    }

    /// @inheritdoc INode
    function initialize(NodeInitArgs calldata args, address escrow_) external initializer {
        __ERC20_init(args.name, args.symbol);
        // ownership will be transferred in Factory after setting up the Node (routers, component, etc)
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Multicall_init();

        asset = args.asset;
        nodeOwnerFeeAddress = args.owner;
        escrow = escrow_;

        rebalanceCooldown = 23 hours;
        rebalanceWindow = 1 hours;

        lastRebalance = uint64(block.timestamp - rebalanceWindow);
        lastPayment = uint64(block.timestamp);
        _decimals = IERC20Metadata(args.asset).decimals();
        maxDepositSize = 10_000_000 * 10 ** _decimals;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts if the sender is not a router
    modifier onlyRouter() {
        _onlyRouter();
        _;
    }

    function _onlyRouter() internal view {
        if (!isRouter[msg.sender]) revert ErrorsLib.InvalidSender();
    }

    /// @notice Reverts if the sender is not a rebalancer
    modifier onlyRebalancer() {
        _onlyRebalancer();
        _;
    }

    function _onlyRebalancer() internal view {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.InvalidSender();
    }

    /// @notice Reverts if the sender is not the owner or a rebalancer
    modifier onlyOwnerOrRebalancer() {
        _onlyOwnerOrRebalancer();
        _;
    }

    function _onlyOwnerOrRebalancer() internal view {
        if (msg.sender != owner() && !isRebalancer[msg.sender]) revert ErrorsLib.InvalidSender();
    }

    /// @notice Reverts if the current block timestamp is outside the rebalance window
    modifier onlyWhenRebalancing() {
        _onlyWhenRebalancing();
        _;
    }

    function _onlyWhenRebalancing() internal view {
        if (block.timestamp >= lastRebalance + rebalanceWindow) revert ErrorsLib.RebalanceWindowClosed();
    }

    /// @notice Reverts if the current block timestamp is within the rebalance window
    modifier onlyWhenNotRebalancing() {
        _onlyWhenNotRebalancing();
        _;
    }

    function _onlyWhenNotRebalancing() internal view {
        if (block.timestamp < lastRebalance + rebalanceWindow) revert ErrorsLib.RebalanceWindowOpen();
    }

    function _nonZeroAddress(address address_) internal view {
        if (address_ == address(0)) revert ErrorsLib.ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INode
    function addPolicies(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes4[] calldata sigs,
        address[] calldata policies_
    ) external onlyOwner {
        NodeLib.addPolicies(registry, policies, sigPolicy, proof, proofFlags, sigs, policies_);
    }

    /// @inheritdoc INode
    function removePolicies(bytes4[] calldata sigs, address[] calldata policies_) external onlyOwner {
        NodeLib.removePolicies(policies, sigPolicy, sigs, policies_);
    }

    /// @inheritdoc INode
    function addComponent(address component, uint64 targetWeight, uint64 maxDelta, address router)
        external
        onlyOwner
        onlyWhenNotRebalancing
    {
        _validateNewComponent(component, router);

        components.push(component);
        componentAllocations[component] =
            ComponentAllocation({targetWeight: targetWeight, maxDelta: maxDelta, router: router, isComponent: true});

        emit EventsLib.ComponentAdded(component, targetWeight, maxDelta, router);
    }

    /// @inheritdoc INode
    function removeComponent(address component, bool force) external onlyOwner onlyWhenNotRebalancing {
        if (!_isComponent(component)) revert ErrorsLib.NotSet();
        address router = componentAllocations[component].router;
        if (!force && IRouter(router).getComponentAssets(component, false) > 0) {
            revert ErrorsLib.NonZeroBalance();
        }
        if (force && !IRouter(router).isBlacklisted(component)) {
            revert ErrorsLib.NotBlacklisted();
        }

        NodeLib.remove(components, component);
        delete componentAllocations[component];
        emit EventsLib.ComponentRemoved(component);
    }

    /// @inheritdoc INode
    function updateComponentAllocation(address component, uint64 targetWeight, uint64 maxDelta, address router)
        external
        onlyOwner
        onlyWhenNotRebalancing
    {
        if (!_isComponent(component)) revert ErrorsLib.NotSet();
        if (!isRouter[router]) revert ErrorsLib.NotWhitelisted();
        if (!IRouter(router).isWhitelisted(component)) revert ErrorsLib.NotWhitelisted();
        componentAllocations[component] =
            ComponentAllocation({targetWeight: targetWeight, maxDelta: maxDelta, router: router, isComponent: true});
        emit EventsLib.ComponentAllocationUpdated(component, targetWeight, maxDelta, router);
    }

    /// @inheritdoc INode
    function updateTargetReserveRatio(uint64 targetReserveRatio_) external onlyOwner onlyWhenNotRebalancing {
        if (targetReserveRatio_ >= WAD) revert ErrorsLib.InvalidComponentRatios();
        targetReserveRatio = targetReserveRatio_;
        emit EventsLib.TargetReserveRatioUpdated(targetReserveRatio_);
    }

    /// @inheritdoc INode
    function addRouter(address newRouter) external onlyOwner {
        _validateNewRouter(newRouter);
        isRouter[newRouter] = true;
        emit EventsLib.RouterAdded(newRouter);
    }

    /// @inheritdoc INode
    function removeRouter(address oldRouter) external onlyOwner {
        if (!isRouter[oldRouter]) revert ErrorsLib.NotSet();
        isRouter[oldRouter] = false;
        emit EventsLib.RouterRemoved(oldRouter);
    }

    /// @inheritdoc INode
    function addRebalancer(address newRebalancer) external onlyOwner {
        if (isRebalancer[newRebalancer]) revert ErrorsLib.AlreadySet();
        if (!INodeRegistry(registry).isRegistryType(newRebalancer, RegistryType.REBALANCER)) {
            revert ErrorsLib.NotWhitelisted();
        }
        isRebalancer[newRebalancer] = true;
        emit EventsLib.RebalancerAdded(newRebalancer);
    }

    /// @inheritdoc INode
    function removeRebalancer(address oldRebalancer) external onlyOwner {
        if (!isRebalancer[oldRebalancer]) revert ErrorsLib.NotSet();
        isRebalancer[oldRebalancer] = false;
        emit EventsLib.RebalancerRemoved(oldRebalancer);
    }

    /// @inheritdoc INode
    function setQuoter(address newQuoter) external onlyOwner {
        if (!INodeRegistry(registry).isRegistryType(newQuoter, RegistryType.QUOTER)) revert ErrorsLib.NotWhitelisted();
        quoter = IQuoterV1(newQuoter);
        emit EventsLib.QuoterSet(newQuoter);
    }

    /// @inheritdoc INode
    function setLiquidationQueue(address[] calldata newQueue) external onlyOwner {
        _validateNoDuplicateComponents(newQueue);

        for (uint256 i = 0; i < newQueue.length; i++) {
            if (!_isComponent(newQueue[i])) revert ErrorsLib.InvalidComponent();
        }
        liquidationsQueue = newQueue;
        emit EventsLib.LiquidationQueueUpdated(newQueue);
    }

    /// @inheritdoc INode
    function setRebalanceCooldown(uint64 newRebalanceCooldown) external onlyOwner {
        rebalanceCooldown = newRebalanceCooldown;
        emit EventsLib.CooldownDurationUpdated(newRebalanceCooldown);
    }

    /// @inheritdoc INode
    function setRebalanceWindow(uint64 newRebalanceWindow) external onlyOwner {
        rebalanceWindow = newRebalanceWindow;
        emit EventsLib.RebalanceWindowUpdated(newRebalanceWindow);
    }

    /// @inheritdoc INode
    function enableSwingPricing(bool status_, uint64 maxSwingFactor_) external onlyOwner {
        _nonZeroAddress(address(quoter));
        if (maxSwingFactor_ > INodeRegistry(registry).protocolMaxSwingFactor()) revert ErrorsLib.InvalidSwingFactor();
        swingPricingEnabled = status_;
        maxSwingFactor = maxSwingFactor_;
        emit EventsLib.SwingPricingStatusUpdated(status_, maxSwingFactor_);
    }

    /// @inheritdoc INode
    function setNodeOwnerFeeAddress(address newNodeOwnerFeeAddress) external onlyOwner {
        _nonZeroAddress(newNodeOwnerFeeAddress);
        if (newNodeOwnerFeeAddress == nodeOwnerFeeAddress) revert ErrorsLib.AlreadySet();
        nodeOwnerFeeAddress = newNodeOwnerFeeAddress;
        emit EventsLib.NodeOwnerFeeAddressSet(newNodeOwnerFeeAddress);
    }

    /// @inheritdoc INode
    function setAnnualManagementFee(uint64 newAnnualManagementFee) external onlyOwner {
        if (newAnnualManagementFee >= WAD) revert ErrorsLib.InvalidFee();
        annualManagementFee = newAnnualManagementFee;
        emit EventsLib.AnnualManagementFeeSet(newAnnualManagementFee);
    }

    /// @inheritdoc INode
    function setMaxDepositSize(uint256 newMaxDepositSize) external onlyOwner {
        if (newMaxDepositSize > 1e36) revert ErrorsLib.ExceedsMaxDepositLimit();
        maxDepositSize = newMaxDepositSize;
        emit EventsLib.MaxDepositSizeSet(newMaxDepositSize);
    }

    /// @inheritdoc INode
    function rescueTokens(address token, address recipient, uint256 amount) external onlyOwner {
        if (token == asset) revert ErrorsLib.InvalidToken();
        if (_isComponent(token)) revert ErrorsLib.InvalidToken();
        IERC20(token).safeTransfer(recipient, amount);
        emit EventsLib.RescueTokens(token, recipient, amount);
    }

    /*//////////////////////////////////////////////////////////////
                    REBALANCER & ROUTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INode
    function startRebalance() external onlyRebalancer nonReentrant {
        if (!validateComponentRatios()) revert ErrorsLib.InvalidComponentRatios();
        if (isCacheValid()) revert ErrorsLib.CooldownActive();

        lastRebalance = uint64(block.timestamp);
        _updateTotalAssets();
        _payManagementFees();
        _updateLastPayment();
        _runPolicies();

        emit EventsLib.RebalanceStarted(block.timestamp, rebalanceWindow);
    }

    /// @inheritdoc INode
    function execute(address target, bytes calldata data)
        external
        onlyRouter
        nonReentrant
        onlyWhenRebalancing
        returns (bytes memory)
    {
        _nonZeroAddress(target);
        bytes memory result = target.functionCall(data);
        _runPolicies();
        emit EventsLib.Execute(target, data, result);
        return result;
    }

    /// @inheritdoc INode
    function payManagementFees()
        external
        nonReentrant
        onlyOwnerOrRebalancer
        onlyWhenNotRebalancing
        returns (uint256 feeForPeriod)
    {
        _updateTotalAssets();
        feeForPeriod = _payManagementFees();
        if (feeForPeriod > 0) {
            _updateLastPayment();
        }
        _runPolicies();
    }

    function _payManagementFees() internal returns (uint256 feeForPeriod) {
        feeForPeriod = uint256(annualManagementFee).mulDiv(
            cacheTotalAssets * (block.timestamp - lastPayment), SECONDS_PER_YEAR * WAD
        );

        if (feeForPeriod > 0) {
            uint256 protocolFeeAmount = feeForPeriod.mulDiv(INodeRegistry(registry).protocolManagementFee(), WAD);
            uint256 nodeOwnerFeeAmount = feeForPeriod - protocolFeeAmount;

            if (IERC20(asset).balanceOf(address(this)) < feeForPeriod) {
                revert ErrorsLib.NotEnoughAssetsToPayFees(feeForPeriod, IERC20(asset).balanceOf(address(this)));
            }

            cacheTotalAssets -= feeForPeriod;
            IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), protocolFeeAmount);
            IERC20(asset).safeTransfer(nodeOwnerFeeAddress, nodeOwnerFeeAmount);
            emit EventsLib.ManagementFeePaid(nodeOwnerFeeAddress, nodeOwnerFeeAmount, protocolFeeAmount);
        }
    }

    /// @inheritdoc INode
    function subtractProtocolExecutionFee(uint256 executionFee) external onlyRouter nonReentrant {
        if (executionFee > IERC20(asset).balanceOf(address(this))) {
            revert ErrorsLib.NotEnoughAssetsToPayFees(executionFee, IERC20(asset).balanceOf(address(this)));
        }
        cacheTotalAssets -= executionFee;
        IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), executionFee);
        _runPolicies();
        emit EventsLib.ExecutionFeeTaken(executionFee);
    }

    /// @inheritdoc INode
    function updateTotalAssets() external onlyOwnerOrRebalancer nonReentrant {
        _updateTotalAssets();
        _runPolicies();
    }

    /// @inheritdoc INode
    function fulfillRedeemFromReserve(address controller) external onlyRebalancer onlyWhenRebalancing nonReentrant {
        _fulfillRedeemFromReserve(controller);
        _runPolicies();
    }

    /// @inheritdoc INode
    function finalizeRedemption(
        address controller,
        uint256 assetsToReturn,
        uint256 sharesPending,
        uint256 sharesAdjusted
    ) external onlyRouter onlyWhenRebalancing nonReentrant {
        _finalizeRedemption(controller, assetsToReturn, sharesPending, sharesAdjusted);
        _runPolicies();
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7540 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INode
    function requestRedeem(uint256 shares, address controller, address owner) external nonReentrant returns (uint256) {
        _validateOwner(owner, shares);
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();
        if (shares == 0) revert ErrorsLib.ZeroAmount();

        uint256 adjustedShares = 0;
        if (swingPricingEnabled) {
            uint256 adjustedAssets = quoter.calculateRedeemPenalty(
                shares, getCashAfterRedemptions(), totalAssets(), maxSwingFactor, targetReserveRatio
            );
            adjustedShares = Math.min(convertToShares(adjustedAssets), shares);
        } else {
            adjustedShares = shares;
        }

        Request storage request = requests[controller];
        request.pendingRedeemRequest += shares;
        request.sharesAdjusted += adjustedShares;
        sharesExiting += adjustedShares;
        _transfer(owner, address(escrow), shares);
        _runPolicies();
        emit IERC7540Redeem.RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /// @inheritdoc INode
    function pendingRedeemRequest(uint256, address controller) external view returns (uint256 pendingShares) {
        return requests[controller].pendingRedeemRequest;
    }

    /// @inheritdoc INode
    function claimableRedeemRequest(uint256, address controller) external view returns (uint256 claimableShares) {
        return requests[controller].claimableRedeemRequest;
    }

    /// @inheritdoc INode
    function setOperator(address operator, bool approved) external nonReentrant returns (bool success) {
        if (msg.sender == operator) revert ErrorsLib.CannotSetSelfAsOperator();
        isOperator[msg.sender][operator] = approved;
        _runPolicies();
        emit OperatorSet(msg.sender, operator, approved);
        success = true;
    }

    /// @inheritdoc INode
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC7540Redeem).interfaceId || interfaceId == type(IERC7540Operator).interfaceId
            || interfaceId == type(IERC7575).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-4626 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC7575
    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (assets > maxDeposit(receiver)) {
            revert ErrorsLib.ExceedsMaxDeposit();
        }
        shares = _calculateSharesAfterSwingPricing(assets);
        _deposit(msg.sender, receiver, assets, shares);
        _runPolicies();
        return shares;
    }

    /// @inheritdoc IERC7575
    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        if (shares > maxMint(receiver)) {
            revert ErrorsLib.ExceedsMaxMint();
        }
        assets = _convertToAssets(shares, Math.Rounding.Ceil);
        _deposit(msg.sender, receiver, assets, shares);
        _runPolicies();
        return assets;
    }

    /// @inheritdoc IERC7575
    function withdraw(uint256 assets, address receiver, address controller)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (assets == 0) revert ErrorsLib.ZeroAmount();
        _validateController(controller);
        Request storage request = requests[controller];

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (assets > maxAssets) revert ErrorsLib.ExceedsMaxWithdraw();

        shares = Math.mulDiv(assets, maxShares, maxAssets, Math.Rounding.Ceil);
        request.claimableRedeemRequest -= shares;
        request.claimableAssets -= assets;

        // slither-disable-next-line arbitrary-send-erc20
        IERC20(asset).safeTransferFrom(escrow, receiver, assets);
        _runPolicies();
        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
        return shares;
    }

    /// @inheritdoc IERC7575
    function redeem(uint256 shares, address receiver, address controller)
        external
        nonReentrant
        returns (uint256 assets)
    {
        if (shares == 0) revert ErrorsLib.ZeroAmount();
        _validateController(controller);
        Request storage request = requests[controller];

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (shares > maxShares) revert ErrorsLib.ExceedsMaxRedeem();

        assets = Math.mulDiv(shares, maxAssets, maxShares);
        request.claimableRedeemRequest -= shares;
        request.claimableAssets -= assets;

        // slither-disable-next-line arbitrary-send-erc20
        IERC20(asset).safeTransferFrom(escrow, receiver, assets);
        _runPolicies();
        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
        return assets;
    }

    /// @inheritdoc INode
    function totalAssets() public view returns (uint256) {
        return cacheTotalAssets;
    }

    /// @inheritdoc INode
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc INode
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @inheritdoc INode
    function maxDeposit(address /* controller */ ) public view returns (uint256 maxAssets) {
        return isCacheValid() ? maxDepositSize : 0;
    }

    /// @inheritdoc INode
    function maxMint(address /* controller */ ) public view returns (uint256 maxShares) {
        return isCacheValid() ? convertToShares(maxDepositSize) : 0;
    }

    /// @inheritdoc INode
    function maxWithdraw(address controller) public view returns (uint256 maxAssets) {
        return requests[controller].claimableAssets;
    }

    /// @inheritdoc INode
    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        return requests[controller].claimableRedeemRequest;
    }

    /// @inheritdoc INode
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return _calculateSharesAfterSwingPricing(assets);
    }

    /// @inheritdoc INode
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /// @inheritdoc INode
    function previewWithdraw(uint256 /* assets */ ) external pure returns (uint256 /* shares */ ) {
        revert();
    }

    /// @inheritdoc INode
    function previewRedeem(uint256 /* shares */ ) external pure returns (uint256 /* assets */ ) {
        revert();
    }

    function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    function transfer(address to, uint256 value) public override(ERC20Upgradeable, IERC20) returns (bool) {
        super.transfer(to, value);
        _runPolicies();
        return true;
    }

    function approve(address spender, uint256 value) public override(ERC20Upgradeable, IERC20) returns (bool) {
        super.approve(spender, value);
        _runPolicies();
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        public
        override(ERC20Upgradeable, IERC20)
        returns (bool)
    {
        super.transferFrom(from, to, value);
        _runPolicies();
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INode
    function getComponents() external view returns (address[] memory) {
        return components;
    }

    /// @inheritdoc INode
    function getComponentAllocation(address component) external view returns (ComponentAllocation memory) {
        return componentAllocations[component];
    }

    /// @inheritdoc INode
    function isComponent(address component) external view returns (bool) {
        return _isComponent(component);
    }

    /// @inheritdoc INode
    function isCacheValid() public view returns (bool) {
        return (block.timestamp < lastRebalance + rebalanceWindow + rebalanceCooldown);
    }

    /// @inheritdoc INode
    function validateComponentRatios() public view returns (bool) {
        uint256 totalWeight = targetReserveRatio;
        uint256 length = components.length;
        for (uint256 i; i < length; ++i) {
            totalWeight += componentAllocations[components[i]].targetWeight;
        }
        return totalWeight == WAD;
    }

    /// @inheritdoc INode
    function getCashAfterRedemptions() public view returns (uint256 currentCash) {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 exitingAssets = convertToAssets(sharesExiting);

        return balance >= exitingAssets ? balance - exitingAssets : 0;
    }

    /// @inheritdoc INode
    function enforceLiquidationOrder(address component, uint256 assetsToReturn) external view {
        _enforceLiquidationOrder(component, assetsToReturn);
    }

    /// @inheritdoc INode
    function share() external view returns (address) {
        return address(this);
    }

    /// @inheritdoc INode
    function getLiquidationsQueue() external view returns (address[] memory) {
        return liquidationsQueue;
    }

    /// @inheritdoc INode
    function getUncachedTotalAssets() external view returns (uint256 assets) {
        return _getTotalAssets();
    }

    /// @inheritdoc INode
    function getPolicies(bytes4 sig) external view returns (address[] memory policies_) {
        return policies[sig];
    }

    /// @inheritdoc INode
    function isSigPolicy(bytes4 sig, address policy) external view returns (bool isRegistered) {
        return sigPolicy[sig][policy];
    }

    /*//////////////////////////////////////////////////////////////
                            OTHER USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INode
    function submitPolicyData(bytes4 sig, address policy, bytes calldata data) external {
        NodeLib.submitPolicyData(sigPolicy, sig, policy, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _updateLastPayment() internal {
        lastPayment = uint64(block.timestamp);
    }

    function _fulfillRedeemFromReserve(address controller) internal {
        Request storage request = requests[controller];
        if (request.pendingRedeemRequest == 0) revert ErrorsLib.NoPendingRedeemRequest();

        uint256 balance = Math.max(IERC20(asset).balanceOf(address(this)), 1);
        uint256 assetsToReturn = convertToAssets(request.sharesAdjusted);
        uint256 sharesPending = request.pendingRedeemRequest;
        uint256 sharesAdjusted = request.sharesAdjusted;

        if (assetsToReturn > balance) {
            sharesPending = (sharesPending * balance - 1) / assetsToReturn + 1;
            sharesAdjusted = (sharesAdjusted * balance - 1) / assetsToReturn + 1;
            assetsToReturn = balance;
        }
        _finalizeRedemption(controller, assetsToReturn, sharesPending, sharesAdjusted);
    }

    function _finalizeRedemption(
        address controller,
        uint256 assetsToReturn,
        uint256 sharesPending,
        uint256 sharesAdjusted
    ) internal {
        Request storage request = requests[controller];

        _burn(escrow, sharesPending);

        request.pendingRedeemRequest -= sharesPending;
        request.claimableRedeemRequest += sharesPending;
        request.claimableAssets += assetsToReturn;
        request.sharesAdjusted -= sharesAdjusted;

        sharesExiting -= sharesAdjusted;
        cacheTotalAssets -= assetsToReturn;

        if (assetsToReturn > IERC20(asset).balanceOf(address(this))) {
            revert ErrorsLib.ExceedsAvailableReserve();
        }

        IERC20(asset).safeTransfer(escrow, assetsToReturn);
        emit EventsLib.RedeemClaimable(controller, REQUEST_ID, assetsToReturn, sharesPending);
    }

    function _getTotalAssets() internal view returns (uint256 assets) {
        assets = IERC20(asset).balanceOf(address(this));
        uint256 len = components.length;
        for (uint256 i = 0; i < len; i++) {
            address component = components[i];
            address router = componentAllocations[component].router;
            assets += IRouter(router).getComponentAssets(component, false);
        }
    }

    function _updateTotalAssets() internal {
        uint256 assets = _getTotalAssets();
        cacheTotalAssets = assets;
        emit EventsLib.TotalAssetsUpdated(assets);
    }

    function _validateController(address controller) internal view {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert ErrorsLib.InvalidController();
    }

    function _validateOwner(address owner, uint256 shares) internal {
        if (owner != msg.sender && !isOperator[owner][msg.sender]) {
            _spendAllowance(owner, msg.sender, shares);
        }
    }

    function _validateNoDuplicateComponents(address[] memory componentArray) internal pure {
        uint256 len = componentArray.length;
        if (len == 0) return;
        Arrays.sort(componentArray);
        for (uint256 i = 0; i < len - 1; i++) {
            if (componentArray[i] == componentArray[i + 1]) revert ErrorsLib.DuplicateComponent();
        }
    }

    function _validateNewComponent(address component, address router) internal view {
        if (_isComponent(component)) revert ErrorsLib.AlreadySet();
        if (!(IERC7575(component).asset() == asset)) revert ErrorsLib.InvalidComponentAsset();
        if (!IRouter(router).isWhitelisted(component) || !isRouter[router]) revert ErrorsLib.NotWhitelisted();
    }

    function _validateNewRouter(address newRouter) internal view {
        if (newRouter == address(0)) revert ErrorsLib.ZeroAddress();
        if (!INodeRegistry(registry).isRegistryType(newRouter, RegistryType.ROUTER)) revert ErrorsLib.NotWhitelisted();
        if (isRouter[newRouter]) revert ErrorsLib.AlreadySet();
    }

    function _enforceLiquidationOrder(address component, uint256 assetsToReturn) internal view {
        uint256 len = liquidationsQueue.length;
        for (uint256 i = 0; i < len; i++) {
            address candidate = liquidationsQueue[i];
            address router = componentAllocations[candidate].router;

            uint256 candidateAssets;
            try IRouter(router).getComponentAssets(candidate, true) returns (uint256 assets) {
                candidateAssets = assets;
            } catch {
                continue;
            }

            if (candidateAssets >= assetsToReturn) {
                if (candidate != component) {
                    revert ErrorsLib.IncorrectLiquidationOrder(component, assetsToReturn);
                }
                break;
            }
        }
    }

    function _isComponent(address component) internal view returns (bool) {
        return componentAllocations[component].isComponent;
    }

    function _calculateSharesAfterSwingPricing(uint256 assets) internal view returns (uint256 shares) {
        if (
            (totalAssets() == 0 && totalSupply() == 0) || (!swingPricingEnabled)
                || (Math.mulDiv(getCashAfterRedemptions(), WAD, totalAssets()) >= targetReserveRatio)
        ) {
            shares = convertToShares(assets);
        } else {
            shares = quoter.calculateDepositBonus(
                assets, getCashAfterRedemptions(), totalAssets(), maxSwingFactor, targetReserveRatio
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        return assets.mulDiv(totalSupply() + 1, totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 1, rounding);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal {
        SafeERC20.safeTransferFrom(IERC20(asset), caller, address(this), assets);
        _mint(receiver, shares);
        cacheTotalAssets += assets;
        emit Deposit(caller, receiver, assets, shares);
    }

    function _runPolicies() internal {
        address[] memory policies_ = policies[msg.sig];
        for (uint256 i; i < policies_.length; i++) {
            IPolicy(policies_[i]).onCheck(msg.sender, msg.data);
        }
    }
}
