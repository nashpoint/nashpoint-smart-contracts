// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {INode, ComponentAllocation, Request} from "src/interfaces/INode.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";

contract Node is INode, ERC20, Ownable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    using MathLib for uint256;

    /* IMMUTABLES */
    address public immutable asset;
    address public immutable share;
    address public immutable registry;
    uint256 internal immutable WAD = 1e18;
    uint256 private immutable REQUEST_ID = 0;
    uint256 public immutable MAX_DEPOSIT = 1e36;
    uint256 public immutable SECONDS_PER_YEAR = 365 days;

    /* COMPONENTS */
    address[] public components;
    address[] public liquidationsQueue;
    mapping(address => ComponentAllocation) public componentAllocations;
    ComponentAllocation public reserveAllocation;

    /* PROTOCOL ADDRESSES */
    IQuoter public quoter;
    address public escrow;
    mapping(address => bool) public isRebalancer;
    mapping(address => bool) public isRouter;
    mapping(address => mapping(address => bool)) public isOperator;

    /* REBALANCE COOLDOWN */
    uint64 public rebalanceCooldown = 1 days;
    uint64 public rebalanceWindow = 1 hours;
    uint64 public lastRebalance;

    /* FEES & ACCOUNTING */
    uint64 public annualManagementFee;
    uint64 public lastPayment;
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
        address[] memory routers,
        address[] memory components_,
        ComponentAllocation[] memory componentAllocations_,
        ComponentAllocation memory reserveAllocation_
    ) ERC20(name, symbol) Ownable(owner) {
        if (registry_ == address(0) || asset_ == address(0)) revert ErrorsLib.ZeroAddress();
        if (components_.length != componentAllocations_.length) revert ErrorsLib.LengthMismatch();

        registry = registry_;
        asset = asset_;
        share = address(this);
        _setReserveAllocation(reserveAllocation_);
        _setRouters(routers);
        _setInitialComponents(components_, componentAllocations_);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyRouter() {
        if (!isRouter[msg.sender]) revert ErrorsLib.InvalidSender();
        _;
    }

    modifier onlyRebalancer() {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.InvalidSender();
        _;
    }

    modifier onlyOwnerOrRebalancer() {
        if (msg.sender != owner() && !isRebalancer[msg.sender]) revert ErrorsLib.InvalidSender();
        _;
    }

    modifier onlyWhenRebalancing() {
        if (block.timestamp >= lastRebalance + rebalanceWindow) revert ErrorsLib.RebalanceWindowClosed();
        _;
    }

    modifier onlyWhenNotRebalancing() {
        if (block.timestamp >= lastRebalance && block.timestamp <= lastRebalance + rebalanceWindow) {
            revert ErrorsLib.RebalanceWindowOpen();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function initialize(address escrow_) external onlyOwner {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();
        if (escrow_ == address(0)) revert ErrorsLib.ZeroAddress();

        escrow = escrow_;
        swingPricingEnabled = false;
        isInitialized = true;
        lastRebalance = uint64(block.timestamp - rebalanceCooldown);
        lastPayment = uint64(block.timestamp);

        // todo: add setLiquidationQueue to initialize

        emit EventsLib.Initialize(escrow_, address(this));
    }

    function addComponent(address component, ComponentAllocation memory allocation)
        external
        onlyOwner
        onlyWhenNotRebalancing
    {
        if (component == address(0)) revert ErrorsLib.ZeroAddress();
        if (_isComponent(component)) revert ErrorsLib.AlreadySet();

        components.push(component);
        componentAllocations[component] = allocation;

        emit EventsLib.ComponentAdded(address(this), component, allocation);
    }

    function removeComponent(address component) external onlyOwner onlyWhenNotRebalancing {
        if (!_isComponent(component)) revert ErrorsLib.NotSet();
        if (IERC20(component).balanceOf(address(this)) > 0) revert ErrorsLib.NonZeroBalance();

        uint256 length = components.length;
        for (uint256 i = 0; i < length; i++) {
            if (components[i] == component) {
                if (i != length - 1) {
                    components[i] = components[length - 1];
                }
                components.pop();
                delete componentAllocations[component];
                emit EventsLib.ComponentRemoved(address(this), component);
                return;
            }
        }
    }

    function updateComponentAllocation(address component, ComponentAllocation memory allocation)
        external
        onlyOwner
        onlyWhenNotRebalancing
    {
        if (!_isComponent(component)) revert ErrorsLib.NotSet();
        componentAllocations[component] = allocation;
        emit EventsLib.ComponentAllocationUpdated(address(this), component, allocation);
    }

    function updateReserveAllocation(ComponentAllocation memory allocation) external onlyOwner onlyWhenNotRebalancing {
        reserveAllocation = allocation;
        emit EventsLib.ReserveAllocationUpdated(address(this), allocation);
    }

    function addRouter(address newRouter) external onlyOwner {
        if (isRouter[newRouter]) revert ErrorsLib.AlreadySet();
        if (newRouter == address(0)) revert ErrorsLib.ZeroAddress();
        if (!INodeRegistry(registry).isRouter(newRouter)) revert ErrorsLib.NotWhitelisted();
        isRouter[newRouter] = true;
        emit EventsLib.AddRouter(newRouter);
    }

    function removeRouter(address oldRouter) external onlyOwner {
        if (!isRouter[oldRouter]) revert ErrorsLib.NotSet();
        isRouter[oldRouter] = false;
        emit EventsLib.RemoveRouter(oldRouter);
    }

    function addRebalancer(address newRebalancer) external onlyOwner {
        if (isRebalancer[newRebalancer]) revert ErrorsLib.AlreadySet();
        if (newRebalancer == address(0)) revert ErrorsLib.ZeroAddress();
        isRebalancer[newRebalancer] = true;
        if (!INodeRegistry(registry).isRebalancer(newRebalancer)) revert ErrorsLib.NotWhitelisted();
        emit EventsLib.RebalancerAdded(newRebalancer);
    }

    function removeRebalancer(address oldRebalancer) external onlyOwner {
        if (!isRebalancer[oldRebalancer]) revert ErrorsLib.NotSet();
        isRebalancer[oldRebalancer] = false;
        emit EventsLib.RebalancerRemoved(oldRebalancer);
    }

    function setEscrow(address newEscrow) external onlyOwner {
        if (newEscrow == escrow) revert ErrorsLib.AlreadySet();
        if (newEscrow == address(0)) revert ErrorsLib.ZeroAddress();
        escrow = newEscrow;
        emit EventsLib.SetEscrow(newEscrow);
    }

    function setQuoter(address newQuoter) external onlyOwner {
        if (newQuoter == address(quoter)) revert ErrorsLib.AlreadySet();
        if (newQuoter == address(0)) revert ErrorsLib.ZeroAddress();
        quoter = IQuoter(newQuoter);
        emit EventsLib.SetQuoter(newQuoter);
    }

    function setLiquidationQueue(address[] calldata newQueue) external onlyOwner {
        for (uint256 i = 0; i < newQueue.length; i++) {
            address component = newQueue[i];
            if (component == address(0)) revert ErrorsLib.ZeroAddress();
            if (!_isComponent(component)) revert ErrorsLib.InvalidComponent();
        }
        liquidationsQueue = newQueue;
        emit EventsLib.LiquidationQueueUpdated(newQueue);
    }

    function setRebalanceCooldown(uint64 newRebalanceCooldown) external onlyOwner {
        rebalanceCooldown = newRebalanceCooldown;
        emit EventsLib.CooldownDurationUpdated(newRebalanceCooldown);
    }

    function setRebalanceWindow(uint64 newRebalanceWindow) external onlyOwner {
        rebalanceWindow = newRebalanceWindow;
        emit EventsLib.RebalanceWindowUpdated(newRebalanceWindow);
    }

    function enableSwingPricing(bool status_, uint64 maxSwingFactor_) public onlyOwner {
        swingPricingEnabled = status_;
        maxSwingFactor = maxSwingFactor_;
        emit EventsLib.SwingPricingStatusUpdated(status_);
    }

    function setNodeOwnerFeeAddress(address newNodeOwnerFeeAddress) external onlyOwner {
        if (newNodeOwnerFeeAddress == address(0)) revert ErrorsLib.ZeroAddress();
        if (newNodeOwnerFeeAddress == nodeOwnerFeeAddress) revert ErrorsLib.AlreadySet();
        nodeOwnerFeeAddress = newNodeOwnerFeeAddress;
        emit EventsLib.NodeOwnerFeeAddressSet(newNodeOwnerFeeAddress);
    }

    function setAnnualManagementFee(uint64 newAnnualManagementFee) external onlyOwner {
        annualManagementFee = newAnnualManagementFee;
        emit EventsLib.ProtocolManagementFeeSet(newAnnualManagementFee);
    }

    /*//////////////////////////////////////////////////////////////
                    REBALANCER & ROUTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function startRebalance() external onlyRebalancer {
        if (!_validateComponentRatios()) {
            revert ErrorsLib.InvalidComponentRatios();
        }
        if (block.timestamp < lastRebalance + rebalanceCooldown) revert ErrorsLib.CooldownActive();
        lastRebalance = uint64(block.timestamp);
        _updateTotalAssets();

        emit EventsLib.RebalanceStarted(address(this), block.timestamp, rebalanceWindow);
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyRouter
        onlyWhenRebalancing
        returns (bytes memory)
    {
        if (target == address(0)) revert ErrorsLib.ZeroAddress();
        bytes memory result = target.functionCallWithValue(data, value);
        emit EventsLib.Execute(target, value, data, result);
        return result;
    }

    function payManagementFees() public onlyOwnerOrRebalancer onlyWhenNotRebalancing returns (uint256 feeForPeriod) {
        if (nodeOwnerFeeAddress == address(0)) revert ErrorsLib.ZeroAddress();

        _updateTotalAssets();

        uint256 timePeriod = block.timestamp - lastPayment;
        feeForPeriod = (annualManagementFee * cacheTotalAssets * timePeriod) / (SECONDS_PER_YEAR * WAD);

        if (feeForPeriod > 0) {
            uint256 protocolFeeAmount =
                MathLib.mulDiv(feeForPeriod, INodeRegistry(registry).protocolManagementFee(), WAD);
            uint256 nodeOwnerFeeAmount = feeForPeriod - protocolFeeAmount;

            if (IERC20(asset).balanceOf(address(this)) < feeForPeriod) {
                revert ErrorsLib.NotEnoughAssetsToPayFees(feeForPeriod, IERC20(asset).balanceOf(address(this)));
            }

            cacheTotalAssets = cacheTotalAssets - feeForPeriod;
            lastPayment = uint64(block.timestamp);
            IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), protocolFeeAmount);
            IERC20(asset).safeTransfer(nodeOwnerFeeAddress, nodeOwnerFeeAmount);
            return feeForPeriod;
        }
    }

    function subtractProtocolExecutionFee(uint256 executionFee) external onlyRouter {
        cacheTotalAssets -= executionFee;
        IERC20(asset).safeTransfer(INodeRegistry(registry).protocolFeeAddress(), executionFee);
    }

    // todo: remove this function after audit
    function updateTotalAssets() external onlyOwnerOrRebalancer {
        _updateTotalAssets();
    }

    function fulfillRedeemFromReserve(address controller) external onlyRebalancer onlyWhenRebalancing {
        _fulfillRedeemFromReserve(controller);
    }

    function fulfillRedeemBatch(address[] memory controllers) external onlyRebalancer onlyWhenRebalancing {
        for (uint256 i = 0; i < controllers.length; i++) {
            _fulfillRedeemFromReserve(controllers[i]);
        }
    }

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

    function requestRedeem(uint256 shares, address controller, address owner) public nonReentrant returns (uint256) {
        _validateOwner(owner);
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();
        if (shares == 0) revert ErrorsLib.ZeroAmount();

        uint256 adjustedShares = 0;
        if (swingPricingEnabled) {
            uint256 adjustedAssets =
                quoter.getAdjustedAssets(asset, sharesExiting, shares, maxSwingFactor, reserveAllocation.targetWeight);
            adjustedShares = convertToShares(adjustedAssets);
        } else {
            adjustedShares = shares;
        }

        Request storage request = requests[controller];
        request.pendingRedeemRequest = request.pendingRedeemRequest + shares;
        request.sharesAdjusted = request.sharesAdjusted + adjustedShares;
        sharesExiting += shares;

        IERC20(share).safeTransferFrom(owner, address(escrow), shares);
        emit IERC7540Redeem.RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function pendingRedeemRequest(uint256, address controller) public view returns (uint256 pendingShares) {
        Request storage request = requests[controller];
        pendingShares = request.pendingRedeemRequest;
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256 claimableShares) {
        claimableShares = maxRedeem(controller);
    }

    function setOperator(address operator, bool approved) public virtual returns (bool success) {
        if (msg.sender == operator) revert ErrorsLib.CannotSetSelfAsOperator();
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        success = true;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC7540Redeem).interfaceId || interfaceId == type(IERC7540Operator).interfaceId
            || interfaceId == type(IERC7575).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-4626 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 sharesToMint) {
        if (assets > maxDeposit(msg.sender)) {
            revert ErrorsLib.ExceedsMaxDeposit();
        }
        sharesToMint = _calculateSharesAfterSwingPricing(assets);
        _deposit(_msgSender(), receiver, assets, sharesToMint);
        cacheTotalAssets += assets;
        emit IERC7575.Deposit(receiver, receiver, assets, sharesToMint);
        return sharesToMint;
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        if (shares > maxMint(receiver)) {
            revert ErrorsLib.ExceedsMaxMint();
        }
        uint256 assetsToDeposit = convertToAssets(shares);
        _deposit(_msgSender(), receiver, assetsToDeposit, shares);
        cacheTotalAssets += assetsToDeposit;
        emit IERC7575.Deposit(receiver, receiver, assetsToDeposit, shares);
        return assetsToDeposit;
    }

    function withdraw(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        if (assets == 0) revert ErrorsLib.ZeroAmount();
        _validateController(controller);
        Request storage request = requests[controller];

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (assets > maxAssets) revert ErrorsLib.ExceedsMaxWithdraw();

        shares = MathLib.mulDiv(assets, maxShares, maxAssets);
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
        return shares;
    }

    function totalAssets() public view virtual returns (uint256) {
        return cacheTotalAssets;
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, MathLib.Rounding.Down);
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, MathLib.Rounding.Down);
    }

    function maxDeposit(address /* controller */ ) public view returns (uint256 maxAssets) {
        maxAssets = isCacheValid() ? MAX_DEPOSIT : 0;
        return maxAssets;
    }

    function maxMint(address /* controller */ ) public view returns (uint256 maxShares) {
        maxShares = isCacheValid() ? convertToShares(MAX_DEPOSIT) : 0;
        return maxShares;
    }

    function maxWithdraw(address controller) public view returns (uint256 maxAssets) {
        Request storage request = requests[controller];
        maxAssets = request.claimableAssets;
    }

    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        Request storage request = requests[controller];
        maxShares = request.claimableRedeemRequest;
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return _calculateSharesAfterSwingPricing(assets);
    }

    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return _convertToAssets(shares, MathLib.Rounding.Down);
    }

    function previewWithdraw(uint256 /* assets */ ) external pure returns (uint256 /* shares */ ) {
        revert();
    }

    function previewRedeem(uint256 /* shares */ ) external pure returns (uint256 /* assets */ ) {
        revert();
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return IERC20Metadata(asset).decimals();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRequestState(address controller)
        external
        view
        returns (
            uint256 pendingRedeemRequest_,
            uint256 claimableRedeemRequest_,
            uint256 claimableAssets_,
            uint256 sharesAdjusted_
        )
    {
        Request storage request = requests[controller];
        return (
            request.pendingRedeemRequest,
            request.claimableRedeemRequest,
            request.claimableAssets,
            request.sharesAdjusted
        );
    }

    function getLiquidationsQueue() external view returns (address[] memory) {
        return liquidationsQueue;
    }

    function getSharesExiting() external view returns (uint256) {
        return sharesExiting;
    }

    function targetReserveRatio() public view returns (uint64) {
        return reserveAllocation.targetWeight;
    }

    function getComponents() external view returns (address[] memory) {
        return components;
    }

    function getComponentRatio(address component) external view returns (uint64 ratio) {
        return componentAllocations[component].targetWeight;
    }

    function isComponent(address component) external view returns (bool) {
        return _isComponent(component);
    }

    function getMaxDelta(address component) external view returns (uint64) {
        return componentAllocations[component].maxDelta;
    }

    function isCacheValid() public view returns (bool) {
        return (block.timestamp <= lastRebalance + rebalanceCooldown);
    }

    function validateComponentRatios() public view returns (bool) {
        return _validateComponentRatios();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _fulfillRedeemFromReserve(address controller) internal {
        Request storage request = requests[controller];
        if (request.pendingRedeemRequest == 0) revert ErrorsLib.NoPendingRedeemRequest();

        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 assetsToReturn = convertToAssets(request.sharesAdjusted);

        // check that current reserve is enough for redeem
        if (assetsToReturn > balance) {
            revert ErrorsLib.ExceedsAvailableReserve();
        }

        _finalizeRedemption(controller, assetsToReturn, request.pendingRedeemRequest, request.sharesAdjusted);
        IERC20(asset).safeIncreaseAllowance(address(this), assetsToReturn);
        IERC20(asset).safeTransferFrom(address(this), escrow, assetsToReturn);
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

        sharesExiting -= sharesPending;
        cacheTotalAssets -= assetsToReturn;

        emit EventsLib.RedeemClaimable(controller, REQUEST_ID, assetsToReturn, sharesPending);
    }

    function _updateTotalAssets() internal {
        cacheTotalAssets = quoter.getTotalAssets();
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

    function _setReserveAllocation(ComponentAllocation memory allocation) internal {
        if (allocation.targetWeight >= WAD) revert ErrorsLib.InvalidComponentRatios();
        reserveAllocation = allocation;
        emit EventsLib.ReserveAllocationUpdated(address(this), allocation);
    }

    function _setRouters(address[] memory routers) internal {
        unchecked {
            for (uint256 i; i < routers.length; ++i) {
                isRouter[routers[i]] = true;
                emit EventsLib.AddRouter(routers[i]);
            }
        }
    }

    function _setInitialComponents(address[] memory components_, ComponentAllocation[] memory allocations) internal {
        unchecked {
            for (uint256 i; i < components_.length; ++i) {
                if (components_[i] == address(0)) revert ErrorsLib.ZeroAddress();
                components.push(components_[i]);
                componentAllocations[components_[i]] = allocations[i];

                emit EventsLib.ComponentAdded(address(this), components_[i], allocations[i]);
            }
        }
        if (!_validateComponentRatios()) {
            revert ErrorsLib.InvalidComponentRatios();
        }
    }

    function _validateComponentRatios() internal view returns (bool) {
        uint256 totalWeight = reserveAllocation.targetWeight;
        uint256 length = components.length;
        for (uint256 i; i < length; ++i) {
            totalWeight += componentAllocations[components[i]].targetWeight;
        }
        return totalWeight == WAD;
    }

    function _isComponent(address component) internal view returns (bool) {
        uint256 length = components.length;
        unchecked {
            for (uint256 i; i < length; ++i) {
                if (components[i] == component) return true;
            }
        }
        return false;
    }

    function _calculateSharesAfterSwingPricing(uint256 assets) internal view returns (uint256 shares) {
        if (totalAssets() == 0 && totalSupply() == 0 || !swingPricingEnabled) {
            shares = convertToShares(assets);
        } else {
            return quoter.calculateDeposit(asset, assets, reserveAllocation.targetWeight, maxSwingFactor);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _convertToShares(uint256 assets, MathLib.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, MathLib.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(IERC20(asset), caller, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }
}
