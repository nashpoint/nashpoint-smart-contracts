// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {INode, ComponentAllocation, Request, IERC7575, IERC165} from "src/interfaces/INode.sol";
import {IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IQuoterV1} from "src/interfaces/IQuoterV1.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {INodeRegistry, RegistryType} from "src/interfaces/INodeRegistry.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";

contract Node is INode, ERC20, Ownable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    using MathLib for uint256;

    /* IMMUTABLES & CONSTANTS */
    address public immutable registry;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant REQUEST_ID = 0;
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /* COMPONENTS */
    uint64 public targetReserveRatio;
    address public asset;
    address[] internal components;
    address[] public liquidationsQueue;
    mapping(address => ComponentAllocation) internal componentAllocations;

    /* PROTOCOL ADDRESSES */
    IQuoterV1 public quoter;
    address public escrow;
    mapping(address => bool) public isRebalancer;
    mapping(address => bool) public isRouter;
    mapping(address => mapping(address => bool)) public isOperator;

    /* REBALANCE COOLDOWN */
    uint64 public rebalanceCooldown = 23 hours;
    uint64 public rebalanceWindow = 1 hours;
    uint64 public lastRebalance;

    /* FEES & ACCOUNTING */
    uint64 public annualManagementFee;
    uint64 public lastPayment;
    uint256 public maxDepositSize;
    uint256 public sharesExiting;
    uint256 public cacheTotalAssets;
    address public nodeOwnerFeeAddress;
    mapping(address => Request) public requests;

    /* SWING PRICING */
    uint64 public maxSwingFactor;
    bool public swingPricingEnabled;
    bool public isInitialized;

    /* CONSTRUCTOR */
    constructor(
        address registry_,
        string memory name,
        string memory symbol,
        address asset_,
        address owner,
        address[] memory components_,
        ComponentAllocation[] memory componentAllocations_,
        uint64 targetReserveRatio_
    ) ERC20(name, symbol) Ownable(owner) {
        if (registry_ == address(0) || asset_ == address(0)) revert ErrorsLib.ZeroAddress();
        if (components_.length != componentAllocations_.length) revert ErrorsLib.LengthMismatch();

        registry = registry_;
        asset = asset_;
        _setTargetReserveRatio(targetReserveRatio_);
        _setInitialComponents(components_, componentAllocations_);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts if the sender is not a router
    modifier onlyRouter() {
        if (!isRouter[msg.sender]) revert ErrorsLib.InvalidSender();
        _;
    }

    /// @notice Reverts if the sender is not a rebalancer
    modifier onlyRebalancer() {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.InvalidSender();
        _;
    }

    /// @notice Reverts if the sender is not the owner or a rebalancer
    modifier onlyOwnerOrRebalancer() {
        if (msg.sender != owner() && !isRebalancer[msg.sender]) revert ErrorsLib.InvalidSender();
        _;
    }

    /// @notice Reverts if the current block timestamp is outside the rebalance window
    modifier onlyWhenRebalancing() {
        unchecked {
            if (block.timestamp >= lastRebalance + rebalanceWindow) revert ErrorsLib.RebalanceWindowClosed();
        }
        _;
    }

    /// @notice Reverts if the current block timestamp is within the rebalance window
    modifier onlyWhenNotRebalancing() {
        unchecked {
            if (block.timestamp < lastRebalance + rebalanceWindow) {
                revert ErrorsLib.RebalanceWindowOpen();
            }
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INode
    function initialize(address escrow_) external onlyOwner {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();
        if (escrow_ == address(0)) revert ErrorsLib.ZeroAddress();

        escrow = escrow_;
        lastRebalance = uint64(block.timestamp - rebalanceWindow);
        lastPayment = uint64(block.timestamp);
        maxDepositSize = 10_000_000 * 10 ** decimals();
        _setInitialRouters();
        isInitialized = true;

        emit EventsLib.Initialize(escrow_, address(this));
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
        if (!force && IRouter(componentAllocations[component].router).getComponentAssets(component, false) > 0) {
            revert ErrorsLib.NonZeroBalance();
        }

        uint256 length = components.length;
        for (uint256 i = 0; i < length; i++) {
            if (components[i] == component) {
                if (i != length - 1) {
                    components[i] = components[length - 1];
                }
                components.pop();
                delete componentAllocations[component];
                emit EventsLib.ComponentRemoved(component);
                return;
            }
        }
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
        if (newRebalancer == address(0)) revert ErrorsLib.ZeroAddress();
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
        if (newQuoter == address(quoter)) revert ErrorsLib.AlreadySet();
        if (newQuoter == address(0)) revert ErrorsLib.ZeroAddress();
        if (!INodeRegistry(registry).isRegistryType(newQuoter, RegistryType.QUOTER)) revert ErrorsLib.NotWhitelisted();
        quoter = IQuoterV1(newQuoter);
        emit EventsLib.QuoterSet(newQuoter);
    }

    /// @inheritdoc INode
    function setLiquidationQueue(address[] calldata newQueue) external onlyOwner {
        _validateNoDuplicateComponents(newQueue);

        for (uint256 i = 0; i < newQueue.length; i++) {
            address component = newQueue[i];
            if (component == address(0)) revert ErrorsLib.ZeroAddress();
            if (!_isComponent(component)) revert ErrorsLib.InvalidComponent();
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
        if (maxSwingFactor_ > INodeRegistry(registry).protocolMaxSwingFactor()) revert ErrorsLib.InvalidSwingFactor();
        swingPricingEnabled = status_;
        maxSwingFactor = maxSwingFactor_;
        emit EventsLib.SwingPricingStatusUpdated(status_, maxSwingFactor_);
    }

    /// @inheritdoc INode
    function setNodeOwnerFeeAddress(address newNodeOwnerFeeAddress) external onlyOwner {
        if (newNodeOwnerFeeAddress == address(0)) revert ErrorsLib.ZeroAddress();
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
    function startRebalance() external onlyRebalancer {
        if (!_validateComponentRatios()) {
            revert ErrorsLib.InvalidComponentRatios();
        }
        if (block.timestamp < lastRebalance + rebalanceWindow + rebalanceCooldown) revert ErrorsLib.CooldownActive();
        lastRebalance = uint64(block.timestamp);
        _updateTotalAssets();

        emit EventsLib.RebalanceStarted(block.timestamp, rebalanceWindow);
    }

    /// @inheritdoc INode
    function execute(address target, bytes calldata data)
        external
        onlyRouter
        onlyWhenRebalancing
        returns (bytes memory)
    {
        if (target == address(0)) revert ErrorsLib.ZeroAddress();
        bytes memory result = target.functionCall(data);
        emit EventsLib.Execute(target, data, result);
        return result;
    }

    /// @inheritdoc INode
    function payManagementFees() external onlyOwnerOrRebalancer onlyWhenNotRebalancing returns (uint256 feeForPeriod) {
        if (nodeOwnerFeeAddress == address(0)) revert ErrorsLib.ZeroAddress();

        _updateTotalAssets();

        unchecked {
            feeForPeriod =
                (annualManagementFee * cacheTotalAssets * (block.timestamp - lastPayment)) / (SECONDS_PER_YEAR * WAD);

            if (feeForPeriod > 0) {
                uint256 protocolFeeAmount = feeForPeriod * INodeRegistry(registry).protocolManagementFee() / WAD;
                uint256 nodeOwnerFeeAmount = feeForPeriod - protocolFeeAmount;

                if (IERC20(asset).balanceOf(address(this)) < feeForPeriod) {
                    revert ErrorsLib.NotEnoughAssetsToPayFees(feeForPeriod, IERC20(asset).balanceOf(address(this)));
                }

                cacheTotalAssets -= feeForPeriod;
                lastPayment = uint64(block.timestamp);
                IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), protocolFeeAmount);
                IERC20(asset).safeTransfer(nodeOwnerFeeAddress, nodeOwnerFeeAmount);
            }
        }
    }

    /// @inheritdoc INode
    function subtractProtocolExecutionFee(uint256 executionFee) external onlyRouter {
        if (executionFee > IERC20(asset).balanceOf(address(this))) {
            revert ErrorsLib.NotEnoughAssetsToPayFees(executionFee, IERC20(asset).balanceOf(address(this)));
        }
        cacheTotalAssets -= executionFee;
        IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), executionFee);
    }

    function updateTotalAssets() external onlyOwnerOrRebalancer {
        _updateTotalAssets();
    }

    /// @inheritdoc INode
    function fulfillRedeemFromReserve(address controller) external onlyRebalancer onlyWhenRebalancing {
        _fulfillRedeemFromReserve(controller);
    }

    /// @inheritdoc INode
    function fulfillRedeemBatch(address[] memory controllers) external onlyRebalancer onlyWhenRebalancing {
        for (uint256 i = 0; i < controllers.length; i++) {
            _fulfillRedeemFromReserve(controllers[i]);
        }
    }

    /// @inheritdoc INode
    function finalizeRedemption(
        address controller,
        uint256 assetsToReturn,
        uint256 sharesPending,
        uint256 sharesAdjusted
    ) external onlyRouter {
        _finalizeRedemption(controller, assetsToReturn, sharesPending, sharesAdjusted);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7540 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INode
    function requestRedeem(uint256 shares, address controller, address owner) external nonReentrant returns (uint256) {
        _validateOwner(owner);
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();
        if (shares == 0) revert ErrorsLib.ZeroAmount();

        unchecked {
            uint256 adjustedShares = 0;
            if (swingPricingEnabled) {
                uint256 adjustedAssets = quoter.calculateRedeemPenalty(
                    shares, getCashAfterRedemptions(), totalAssets(), maxSwingFactor, targetReserveRatio
                );
                adjustedShares = MathLib.min(convertToShares(adjustedAssets), shares);
            } else {
                adjustedShares = shares;
            }

            Request storage request = requests[controller];
            request.pendingRedeemRequest += shares;
            request.sharesAdjusted += adjustedShares;
            sharesExiting += adjustedShares;
        }

        IERC20(address(this)).safeTransferFrom(owner, address(escrow), shares);
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
    function setOperator(address operator, bool approved) external returns (bool success) {
        if (msg.sender == operator) revert ErrorsLib.CannotSetSelfAsOperator();
        isOperator[msg.sender][operator] = approved;
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

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (assets > maxDeposit(receiver)) {
            revert ErrorsLib.ExceedsMaxDeposit();
        }
        shares = _calculateSharesAfterSwingPricing(assets);
        _deposit(msg.sender, receiver, assets, shares);
        cacheTotalAssets += assets;
        return shares;
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        if (shares > maxMint(receiver)) {
            revert ErrorsLib.ExceedsMaxMint();
        }
        assets = _convertToAssets(shares, MathLib.Rounding.Up);
        _deposit(msg.sender, receiver, assets, shares);
        cacheTotalAssets += assets;
        return assets;
    }

    function withdraw(uint256 assets, address receiver, address controller) external returns (uint256 shares) {
        if (assets == 0) revert ErrorsLib.ZeroAmount();
        _validateController(controller);
        Request storage request = requests[controller];

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (assets > maxAssets) revert ErrorsLib.ExceedsMaxWithdraw();

        shares = MathLib.mulDiv(assets, maxShares, maxAssets, MathLib.Rounding.Up);
        request.claimableRedeemRequest -= shares;
        request.claimableAssets -= assets;

        IERC20(asset).safeTransferFrom(escrow, receiver, assets);
        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
        return shares;
    }

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        if (shares == 0) revert ErrorsLib.ZeroAmount();
        _validateController(controller);
        Request storage request = requests[controller];

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (shares > maxShares) revert ErrorsLib.ExceedsMaxRedeem();

        assets = MathLib.mulDiv(shares, maxAssets, maxShares);
        request.claimableRedeemRequest -= shares;
        request.claimableAssets -= assets;

        IERC20(asset).safeTransferFrom(escrow, receiver, assets);
        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
        return assets;
    }

    /// @inheritdoc INode
    function totalAssets() public view returns (uint256) {
        return cacheTotalAssets;
    }

    /// @inheritdoc INode
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, MathLib.Rounding.Down);
    }

    /// @inheritdoc INode
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, MathLib.Rounding.Down);
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
        return _convertToAssets(shares, MathLib.Rounding.Up);
    }

    /// @inheritdoc INode
    function previewWithdraw(uint256 /* assets */ ) external pure returns (uint256 /* shares */ ) {
        revert();
    }

    /// @inheritdoc INode
    function previewRedeem(uint256 /* shares */ ) external pure returns (uint256 /* assets */ ) {
        revert();
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        (bool success, bytes memory data) = asset.staticcall(abi.encodeWithSignature("decimals()"));
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        } else {
            return 18;
        }
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
        return _validateComponentRatios();
    }

    /// @inheritdoc INode
    function getCashAfterRedemptions() public view returns (uint256 currentCash) {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 exitingAssets = convertToAssets(sharesExiting);

        return balance >= exitingAssets ? balance - exitingAssets : 0;
    }

    /// @inheritdoc INode
    function enforceLiquidationOrder(address component, uint256 assetsToReturn) public view {
        _enforceLiquidationOrder(component, assetsToReturn);
    }

    /// @inheritdoc INode
    function share() public view returns (address) {
        return address(this);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _fulfillRedeemFromReserve(address controller) internal {
        Request storage request = requests[controller];
        if (request.pendingRedeemRequest == 0) revert ErrorsLib.NoPendingRedeemRequest();

        uint256 balance = MathLib.max(IERC20(asset).balanceOf(address(this)), 1);
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

    function _updateTotalAssets() internal {
        uint256 assets = IERC20(asset).balanceOf(address(this));
        uint256 len = components.length;
        for (uint256 i = 0; i < len; i++) {
            address component = components[i];
            address router = componentAllocations[component].router;
            assets += IRouter(router).getComponentAssets(component, false);
        }
        cacheTotalAssets = assets;
    }

    function _validateController(address controller) internal view {
        if (controller == address(0)) revert ErrorsLib.ZeroAddress();
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert ErrorsLib.InvalidController();
    }

    function _validateOwner(address owner) internal view {
        if (owner == address(0)) revert ErrorsLib.ZeroAddress();
        if (owner != msg.sender && !isOperator[owner][msg.sender]) {
            revert ErrorsLib.InvalidOwner();
        }
    }

    function _setTargetReserveRatio(uint64 targetReserveRatio_) internal {
        if (targetReserveRatio_ >= WAD) revert ErrorsLib.InvalidComponentRatios();
        targetReserveRatio = targetReserveRatio_;
        emit EventsLib.TargetReserveRatioUpdated(targetReserveRatio_);
    }

    function _setInitialRouters() internal {
        unchecked {
            uint256 len = components.length;
            for (uint256 i; i < len; ++i) {
                address router = componentAllocations[components[i]].router;
                _validateNewRouter(router);
                isRouter[router] = true;
                emit EventsLib.RouterAdded(router);
            }
        }
    }

    function _setInitialComponents(address[] memory components_, ComponentAllocation[] memory allocations) internal {
        unchecked {
            uint256 len = components_.length;
            for (uint256 i; i < len; ++i) {
                address component = components_[i];
                if (_isComponent(component)) revert ErrorsLib.AlreadySet();
                ComponentAllocation memory allocation = allocations[i];
                _validateNewComponent(component, allocation.router);
                components.push(component);
                componentAllocations[component] = ComponentAllocation({
                    targetWeight: allocation.targetWeight,
                    maxDelta: allocation.maxDelta,
                    router: allocation.router,
                    isComponent: true
                });
            }
        }
        if (!_validateComponentRatios()) {
            revert ErrorsLib.InvalidComponentRatios();
        }
    }

    function _validateNoDuplicateComponents(address[] memory componentArray) internal pure {
        unchecked {
            uint256 len = componentArray.length;
            if (len == 0) return;
            Arrays.sort(componentArray);
            for (uint256 i = 0; i < len - 1; i++) {
                if (componentArray[i] == componentArray[i + 1]) revert ErrorsLib.DuplicateComponent();
            }
        }
    }

    function _validateComponentRatios() internal view returns (bool) {
        unchecked {
            uint256 totalWeight = targetReserveRatio;
            uint256 length = components.length;
            for (uint256 i; i < length; ++i) {
                totalWeight += componentAllocations[components[i]].targetWeight;
            }
            return totalWeight == WAD;
        }
    }

    function _validateNewComponent(address component, address router) internal view {
        if (component == address(0)) revert ErrorsLib.ZeroAddress();
        if (_isComponent(component)) revert ErrorsLib.AlreadySet();
        if (!(IERC7575(component).asset() == asset)) revert ErrorsLib.InvalidComponentAsset();
        if (!IRouter(router).isWhitelisted(component)) revert ErrorsLib.NotWhitelisted();
        if (isInitialized) {
            if (!isRouter[router]) revert ErrorsLib.NotWhitelisted();
        }
    }

    function _validateNewRouter(address newRouter) internal view {
        if (newRouter == address(0)) revert ErrorsLib.ZeroAddress();
        if (!INodeRegistry(registry).isRegistryType(newRouter, RegistryType.ROUTER)) revert ErrorsLib.NotWhitelisted();
        if (isInitialized) {
            if (isRouter[newRouter]) revert ErrorsLib.AlreadySet();
        }
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
                || (MathLib.mulDiv(getCashAfterRedemptions(), WAD, totalAssets()) >= targetReserveRatio)
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

    function _convertToShares(uint256 assets, MathLib.Rounding rounding) internal view returns (uint256) {
        return assets.mulDiv(totalSupply() + 1, totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, MathLib.Rounding rounding) internal view returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 1, rounding);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal {
        SafeERC20.safeTransferFrom(IERC20(asset), caller, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }
}
