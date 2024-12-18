// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {INode, ComponentAllocation} from "./interfaces/INode.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {INodeRegistry} from "./interfaces/INodeRegistry.sol";
import {IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {MathLib} from "./libraries/MathLib.sol";
import {ISwingPricingV1} from "./pricers/SwingPricingV1.sol";

contract Node is INode, ERC20, Ownable {
    using Address for address;
    using SafeERC20 for IERC20;
    using MathLib for uint256;

    /* CONSTANTS */
    uint256 private constant REQUEST_ID = 0;
    uint256 internal constant PRICE_DECIMALS = 18;

    /* COOLDOWN */
    uint256 public rebalanceCooldown = 1 days;
    uint256 public rebalanceWindow = 1 hours;
    uint256 public lastRebalance;

    /* IMMUTABLES */
    address public immutable registry;
    address public immutable asset;
    address public immutable share;
    uint256 internal immutable WAD = 1e18;

    /* STORAGE */
    address[] public components;
    address[] public liquidationsQueue;
    mapping(address => ComponentAllocation) public componentAllocations;
    ComponentAllocation public reserveAllocation;

    mapping(address => Request) public requests;
    uint256 public sharesExiting;
    uint256 public cacheTotalAssets;

    IQuoter public quoter;
    ISwingPricingV1 public pricer; // todo: generalize this to IPricer
    address public escrow;
    mapping(address => mapping(address => bool)) public isOperator;

    mapping(address => bool) public isRebalancer;
    mapping(address => bool) public isRouter;

    uint256 public maxSwingFactor;
    bool public swingPricingEnabled;
    bool public isInitialized;

    struct Request {
        /// shares
        uint256 pendingRedeemRequest;
        /// shares
        uint256 claimableRedeemRequest;
        /// assets
        uint256 claimableAssets;
        /// down-weighted shares for swing pricing
        uint256 sharesAdjusted;
    }

    /* CONSTRUCTOR */
    constructor(
        address registry_,
        string memory name,
        string memory symbol,
        address asset_,
        address quoter_,
        address owner,
        address rebalancer_,
        address[] memory routers,
        address[] memory components_,
        ComponentAllocation[] memory componentAllocations_,
        ComponentAllocation memory reserveAllocation_
    ) ERC20(name, symbol) Ownable(owner) {
        if (registry_ == address(0) || asset_ == address(0) || quoter_ == address(0)) revert ErrorsLib.ZeroAddress();
        if (components_.length != componentAllocations_.length) revert ErrorsLib.LengthMismatch();

        registry = registry_;
        asset = asset_;
        share = address(this);
        quoter = IQuoter(quoter_);
        isRebalancer[rebalancer_] = true;
        _setReserveAllocation(reserveAllocation_);
        _setRouters(routers);
        _setInitialComponents(components_, componentAllocations_);
    }

    /* MODIFIERS */
    modifier onlyRouter() {
        if (!isRouter[msg.sender]) revert ErrorsLib.NotRouter();
        _;
    }

    modifier onlyRebalancer() {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.InvalidSender();
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

    /* OWNER FUNCTIONS */
    function initialize(address escrow_) external onlyOwner {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();
        if (escrow_ == address(0)) revert ErrorsLib.ZeroAddress();

        escrow = escrow_;
        swingPricingEnabled = false;
        isInitialized = true;
        lastRebalance = block.timestamp - rebalanceCooldown;

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

    function setCooldownDuration(uint256 newCooldownDuration) external onlyOwner {
        rebalanceCooldown = newCooldownDuration;
        emit EventsLib.CooldownDurationUpdated(newCooldownDuration);
    }

    function setRebalanceWindow(uint256 newRebalanceWindow) external onlyOwner {
        rebalanceWindow = newRebalanceWindow;
        emit EventsLib.RebalanceWindowUpdated(newRebalanceWindow);
    }

    function enableSwingPricing(bool status_, address pricer_, uint256 maxSwingFactor_) public /*onlyOwner*/ {
        swingPricingEnabled = status_;
        pricer = ISwingPricingV1(pricer_);
        maxSwingFactor = maxSwingFactor_;
        emit EventsLib.SwingPricingStatusUpdated(status_);
    }

    function startRebalance() external onlyRebalancer {
        ComponentAllocation[] memory allocations = new ComponentAllocation[](components.length);
        for (uint256 i = 0; i < components.length; i++) {
            allocations[i] = componentAllocations[components[i]];
        }
        if (!_validateComponentRatios()) {
            revert ErrorsLib.InvalidComponentRatios();
        }
        if (block.timestamp < lastRebalance + rebalanceCooldown) revert ErrorsLib.CooldownActive();

        lastRebalance = block.timestamp;
        _updateTotalAssets();
        emit EventsLib.RebalanceStarted(address(this), block.timestamp, rebalanceWindow);
    }

    /* REBALANCER FUNCTIONS */
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

    /* ERC-7540 FUNCTIONS */
    function requestRedeem(uint256 shares, address controller, address owner) public returns (uint256) {
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();
        if (shares == 0) revert ErrorsLib.ZeroAmount();

        // get the cash balance of the node and pending redemptions
        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 pendingRedemptions = convertToAssets(sharesExiting);

        // check if pending redemptions exceed current cash balance
        // if not subtract pending redemptions from balance
        if (pendingRedemptions > balance) {
            balance = 0;
        } else {
            balance = balance - pendingRedemptions;
        }

        // get the asset value of the redeem request
        uint256 assets = convertToAssets(shares);

        // gets the expected reserve ratio after tx
        // check redemption (assets) exceed current cash balance
        // if not get reserve ratio
        int256 reserveRatioAfterTX;
        if (assets > balance) {
            reserveRatioAfterTX = 0;
        } else {
            reserveRatioAfterTX = int256(MathLib.mulDiv(balance - assets, WAD, totalAssets() - assets));
        }

        uint256 adjustedAssets;
        if (swingPricingEnabled) {
            adjustedAssets = MathLib.mulDiv(
                assets,
                (WAD - pricer.getSwingFactor(reserveRatioAfterTX, maxSwingFactor, reserveAllocation.targetWeight)),
                WAD
            );
        } else {
            adjustedAssets = assets;
        }

        uint256 sharesToBurn = convertToShares(adjustedAssets);

        Request storage request = requests[controller];
        request.pendingRedeemRequest = request.pendingRedeemRequest + shares;
        request.sharesAdjusted = request.sharesAdjusted + sharesToBurn;
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

    /* ERC-165 FUNCTIONS */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC7540Redeem).interfaceId || interfaceId == type(IERC7540Operator).interfaceId
            || interfaceId == type(IERC7575).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, MathLib.Rounding.Down);
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, MathLib.Rounding.Down);
    }

    function maxDeposit(address /* controller */ ) public view returns (uint256 maxAssets) {
        maxAssets = cacheIsValid() ? type(uint256).max : 0;
        return maxAssets;
    }

    /// note: openzeppelin ERC4626 function
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        if (assets > maxDeposit(receiver)) {
            revert ErrorsLib.ERC4626ExceededMaxDeposit(receiver, assets, maxDeposit(receiver));
        }

        // Handle initial deposit separately to avoid divide by zero
        // This is the first deposit OR !swingPricingEnabled
        uint256 sharesToMint;
        if (totalAssets() == 0 && totalSupply() == 0 || !swingPricingEnabled) {
            sharesToMint = convertToShares(assets);
            _deposit(_msgSender(), receiver, assets, sharesToMint);
            cacheTotalAssets += assets;
            emit IERC7575.Deposit(receiver, receiver, assets, sharesToMint);
            return sharesToMint;
        }

        uint256 reserveCash = IERC20(asset).balanceOf(address(this));

        int256 reserveImpact =
            int256(pricer.calculateReserveImpact(reserveAllocation.targetWeight, reserveCash, totalAssets(), assets));

        // Adjust the deposited assets based on the swing pricing factor.
        uint256 adjustedAssets = MathLib.mulDiv(
            assets, (WAD + pricer.getSwingFactor(reserveImpact, maxSwingFactor, reserveAllocation.targetWeight)), WAD
        );

        // Calculate the number of shares to mint based on the adjusted assets.
        sharesToMint = convertToShares(adjustedAssets);

        // Mint shares for the receiver.
        _deposit(_msgSender(), receiver, assets, sharesToMint);
        cacheTotalAssets += assets;

        emit IERC7575.Deposit(receiver, receiver, assets, sharesToMint);

        return (sharesToMint);
    }

    function maxMint(address /* controller */ ) public view returns (uint256 maxShares) {
        maxShares = cacheIsValid() ? type(uint256).max : 0;
        return maxShares;
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        if (shares > maxMint(receiver)) {
            revert ErrorsLib.ERC4626ExceededMaxMint(receiver, shares, maxMint(receiver));
        }

        uint256 assetsToDeposit = convertToAssets(shares);
        _deposit(_msgSender(), receiver, assetsToDeposit, shares);
        cacheTotalAssets += assetsToDeposit;
        emit IERC7575.Deposit(receiver, receiver, assetsToDeposit, shares);
        return assetsToDeposit;
    }

    function maxWithdraw(address controller) public view returns (uint256 maxAssets) {
        Request storage request = requests[controller];
        maxAssets = request.claimableAssets;
    }

    function withdraw(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);
        Request storage request = requests[controller];

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);

        if (assets > maxAssets) revert ErrorsLib.ExceedsMaxWithdraw();
        shares = MathLib.mulDiv(assets, maxShares, maxAssets);

        request.claimableRedeemRequest -= shares;
        request.claimableAssets -= assets;

        IERC20(asset).safeTransferFrom(escrow, receiver, assets);

        return shares;
    }

    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        Request storage request = requests[controller];
        maxShares = request.claimableRedeemRequest;
    }

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        _validateController(controller);
        Request storage request = requests[controller];

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);

        if (shares > maxShares) revert ErrorsLib.ExceedsMaxRedeem();
        assets = MathLib.mulDiv(shares, maxAssets, maxShares);

        request.claimableRedeemRequest -= shares;
        request.claimableAssets -= assets;

        IERC20(asset).safeTransferFrom(escrow, receiver, assets);

        return shares;
    }

    function updateTotalAssets() external onlyRebalancer {
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

    /* INTERNAL */
    function finalizeRedemption(address controller, uint256 assetsToReturn) external onlyRouter {
        _finalizeRedemption(controller, assetsToReturn);
    }

    function _fulfillRedeemFromReserve(address controller) internal {
        Request storage request = requests[controller];
        if (request.pendingRedeemRequest == 0) revert ErrorsLib.NoPendingRedeemRequest();

        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 assetsToReturn = convertToAssets(request.sharesAdjusted);

        // check that current reserve is enough for redeem
        if (assetsToReturn > balance) {
            revert ErrorsLib.ExceedsAvailableReserve();
        }

        IERC20(asset).approve(address(this), assetsToReturn); // note: directly calling approve
        IERC20(asset).safeTransferFrom(address(this), escrow, assetsToReturn);

        _finalizeRedemption(controller, assetsToReturn);
    }

    function _finalizeRedemption(address controller, uint256 assetsToReturn) internal {
        Request storage request = requests[controller];
        uint256 sharesPending = request.pendingRedeemRequest;
        uint256 sharesAdjusted = request.sharesAdjusted;

        _burn(escrow, sharesPending);

        request.pendingRedeemRequest -= sharesPending;
        request.claimableRedeemRequest += sharesPending;
        request.claimableAssets += assetsToReturn;
        request.sharesAdjusted -= sharesAdjusted;

        sharesExiting -= sharesPending;
        cacheTotalAssets -= assetsToReturn;

        onRedeemClaimable(controller, assetsToReturn, sharesPending);
    }

    function _updateTotalAssets() internal {
        cacheTotalAssets = quoter.getTotalAssets(address(this));
    }

    function _validateController(address controller) internal view {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert ErrorsLib.InvalidController();
    }

    function _setReserveAllocation(ComponentAllocation memory allocation) internal {
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
                if (!_validateComponentRatios()) {
                    revert ErrorsLib.InvalidComponentRatios();
                }
                emit EventsLib.ComponentAdded(address(this), components_[i], allocations[i]);
            }
        }
    }

    function _validateComponentRatios() internal view returns (bool) {
        uint256 totalWeight = reserveAllocation.targetWeight;
        for (uint256 i = 0; i < components.length; i++) {
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

    /* EVENT EMITTERS */
    function onDepositClaimable(address controller, uint256 assets, uint256 shares) public {
        emit EventsLib.DepositClaimable(controller, REQUEST_ID, assets, shares);
    }

    function onRedeemClaimable(address controller, uint256 assets, uint256 shares) public {
        emit EventsLib.RedeemClaimable(controller, REQUEST_ID, assets, shares);
    }

    /* VIEW FUNCTIONS */
    function targetReserveRatio() public view returns (uint256) {
        return reserveAllocation.targetWeight;
    }

    function pricePerShare() external view returns (uint256) {
        return convertToAssets(10 ** decimals());
    }

    function getComponents() external view returns (address[] memory) {
        return components;
    }

    function getComponentRatio(address component) external view returns (uint256 ratio) {
        return componentAllocations[component].targetWeight;
    }

    function isComponent(address component) external view returns (bool) {
        return _isComponent(component);
    }

    function getMaxDelta(address component) external view returns (uint256) {
        return componentAllocations[component].maxDelta;
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return _convertToShares(assets, MathLib.Rounding.Down);
    }

    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return _convertToAssets(shares, MathLib.Rounding.Down);
    }

    function cacheIsValid() public view returns (bool) {
        return (block.timestamp <= lastRebalance + rebalanceCooldown);
    }

    function previewWithdraw(uint256 /* assets */ ) external pure returns (uint256 /* shares */ ) {
        revert();
    }

    function previewRedeem(uint256 /* shares */ ) external pure returns (uint256 /* assets */ ) {
        revert();
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IERC4626-totalAssets}.
     */
    function totalAssets() public view virtual returns (uint256) {
        return cacheTotalAssets;
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function _convertToShares(uint256 assets, MathLib.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
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
