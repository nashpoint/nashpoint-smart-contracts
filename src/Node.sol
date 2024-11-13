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
import {IERC7540Deposit, IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {MathLib} from "./libraries/MathLib.sol";

contract Node is INode, ERC20, Ownable {
    using Address for address;
    using SafeERC20 for IERC20;
    using MathLib for uint256;

    /* CONSTANTS */
    uint256 private constant REQUEST_ID = 0;
    uint8 internal constant PRICE_DECIMALS = 18;

    /* IMMUTABLES */
    address public immutable registry;
    address public immutable asset;
    address public immutable share;

    /* STORAGE */
    address[] public components;
    mapping(address => ComponentAllocation) public componentAllocations;
    ComponentAllocation public reserveAllocation;

    // QueueManager variables
    mapping(address => QueueState) public queueStates;

    IQuoter public quoter;
    address public escrow;
    mapping(address => mapping(address => bool)) public isOperator;

    address public rebalancer;
    mapping(address => bool) public isRouter;

    bool public isInitialized;

    struct QueueState {
        uint128 pendingDepositRequest;
        uint128 pendingRedeemRequest;
        uint128 maxMint;
        uint128 maxWithdraw;
        uint256 depositPrice;
        uint256 redeemPrice;
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
        if (registry_ == address(0) || asset_ == address(0)) revert ErrorsLib.ZeroAddress();
        if (components_.length != componentAllocations_.length) revert ErrorsLib.LengthMismatch();

        registry = registry_;
        asset = asset_;
        share = address(this);
        quoter = IQuoter(quoter_);
        rebalancer = rebalancer_;
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
        if (msg.sender != rebalancer) revert ErrorsLib.InvalidSender();
        _;
    }

    /* OWNER FUNCTIONS */
    function initialize(address escrow_) external onlyOwner {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();
        if (escrow_ == address(0)) revert ErrorsLib.ZeroAddress();

        escrow = escrow_;
        isInitialized = true;

        emit EventsLib.Initialize(escrow_, address(this));
    }

    function addComponent(address component, ComponentAllocation memory allocation) external onlyOwner {
        if (component == address(0)) revert ErrorsLib.ZeroAddress();
        if (_isComponent(component)) revert ErrorsLib.AlreadySet();
        
        components.push(component);
        componentAllocations[component] = allocation;
        
        emit EventsLib.ComponentAdded(address(this), component, allocation);
    }

    function removeComponent(address component) external onlyOwner {
        if (!_isComponent(component)) revert ErrorsLib.NotSet();
        if (IERC20(component).balanceOf(address(this)) > 0) revert ErrorsLib.NonZeroBalance();

        for (uint256 i = 0; i < components.length; i++) {
            if (components[i] == component) {
                components[i] = components[components.length - 1];
                components.pop();
                break;
            }
        }
        delete componentAllocations[component];
        
        emit EventsLib.ComponentRemoved(address(this), component);
    }

    function updateComponentAllocation(address component, ComponentAllocation memory allocation) external onlyOwner {
        if (!_isComponent(component)) revert ErrorsLib.NotSet();
        componentAllocations[component] = allocation;
        emit EventsLib.ComponentAllocationUpdated(address(this), component, allocation);
    }

    function updateReserveAllocation(ComponentAllocation memory allocation) external onlyOwner {
        reserveAllocation = allocation;
        emit EventsLib.ReserveAllocationUpdated(address(this), allocation);
    }

    function addRouter(address newRouter) external onlyOwner {
        if (isRouter[newRouter]) revert ErrorsLib.AlreadySet();
        if (newRouter == address(0)) revert ErrorsLib.ZeroAddress();
        isRouter[newRouter] = true;
        emit EventsLib.AddRouter(newRouter);
    }

    function removeRouter(address oldRouter) external onlyOwner {
        if (!isRouter[oldRouter]) revert ErrorsLib.NotSet();
        isRouter[oldRouter] = false;
        emit EventsLib.RemoveRouter(oldRouter);
    }

    function setRebalancer(address newRebalancer) external onlyOwner {
        if (newRebalancer == rebalancer) revert ErrorsLib.AlreadySet();
        if (newRebalancer == address(0)) revert ErrorsLib.ZeroAddress();
        rebalancer = newRebalancer;
        emit EventsLib.SetRebalancer(newRebalancer);
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

    /* REBALANCER FUNCTIONS */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyRouter
        returns (bytes memory)
    {
        if (target == address(0)) revert ErrorsLib.ZeroAddress();

        bytes memory result = target.functionCallWithValue(data, value);
        emit EventsLib.Execute(target, value, data, result);
        return result;
    }

    /* ERC-7540 FUNCTIONS */
    function requestDeposit(uint256 assets, address controller, address owner) public returns (uint256) {
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert ErrorsLib.InvalidOwner();
        if (IERC20(asset).balanceOf(owner) < assets) revert ErrorsLib.InsufficientBalance();

        uint128 _assets = assets.toUint128();
        if (_assets == 0) revert ErrorsLib.ZeroAmount();
        QueueState storage state = queueStates[controller];
        state.pendingDepositRequest = state.pendingDepositRequest + _assets;

        IERC20(asset).safeTransferFrom(owner, address(escrow), assets);

        emit IERC7540Deposit.DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    function pendingDepositRequest(uint256, address controller) public view returns (uint256 pendingAssets) {
        QueueState storage state = queueStates[controller];
        pendingAssets = state.pendingDepositRequest;
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256 claimableAssets) {
        claimableAssets = maxDeposit(controller);
    }

    function requestRedeem(uint256 shares, address controller, address owner) public returns (uint256) {
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();

        uint128 _shares = shares.toUint128();
        if (_shares == 0) revert ErrorsLib.ZeroAmount();
        QueueState storage state = queueStates[controller];
        state.pendingRedeemRequest = state.pendingRedeemRequest + _shares;

        IERC20(share).safeTransferFrom(owner, address(escrow), shares);

        emit IERC7540Redeem.RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function pendingRedeemRequest(uint256, address controller) public view returns (uint256 pendingShares) {
        QueueState storage state = queueStates[controller];
        pendingShares = state.pendingRedeemRequest;
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

    /* ERC-165 FUNCTIONS */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC7540Deposit).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId
            || interfaceId == type(IERC7540Operator).interfaceId || interfaceId == type(IERC7575).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    /* ERC-4626 FUNCTIONS */
    function totalAssets() external view returns (uint256) {
        return convertToAssets(totalSupply());
    }       

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        uint128 latestPrice = IQuoter(quoter).getPrice(address(this));
        shares = uint256(_calculateShares(assets.toUint128(), latestPrice, MathLib.Rounding.Down));
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        uint128 latestPrice = IQuoter(quoter).getPrice(address(this));
        assets = uint256(_calculateAssets(shares.toUint128(), latestPrice, MathLib.Rounding.Down));
    }

    function maxDeposit(address controller) public view returns (uint256 maxAssets) {
        maxAssets = uint256(_maxDeposit(controller));
    }

    function _maxDeposit(address controller) internal view returns (uint128 assets) {
        QueueState storage state = queueStates[controller];
        assets = _calculateAssets(state.maxMint, state.depositPrice, MathLib.Rounding.Down);
    }

    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);

        if (assets > maxDeposit(controller)) revert ErrorsLib.ExceedsMaxDeposit();

        QueueState storage state = queueStates[controller];
        uint128 sharesUp = _calculateShares(assets.toUint128(), state.depositPrice, MathLib.Rounding.Up);
        uint128 sharesDown = _calculateShares(assets.toUint128(), state.depositPrice, MathLib.Rounding.Down);
        _processDeposit(state, sharesUp, sharesDown, receiver);
        shares = uint256(sharesDown);

        emit IERC7575.Deposit(receiver, controller, assets, shares);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = deposit(assets, receiver, msg.sender);
    }

    function maxMint(address controller) public view returns (uint256 maxShares) {
        QueueState storage state = queueStates[controller];
        maxShares = state.maxMint;
    }

    function mint(uint256 shares, address receiver, address controller) public returns (uint256 assets) {
        _validateController(controller);

        QueueState storage state = queueStates[controller];
        uint128 shares_ = shares.toUint128();
        _processDeposit(state, shares_, shares_, receiver);
        assets = uint256(_calculateAssets(shares_, state.depositPrice, MathLib.Rounding.Down));

        emit IERC7575.Deposit(receiver, controller, assets, shares);
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = mint(shares, receiver, msg.sender);
    }

    function maxWithdraw(address controller) public view returns (uint256 maxAssets) {
        QueueState storage state = queueStates[controller];
        maxAssets = state.maxWithdraw;
    }

    function withdraw(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);

        QueueState storage state = queueStates[controller];
        uint128 assets_ = assets.toUint128();
        _processRedeem(state, assets_, assets_, receiver);
        shares = uint256(_calculateShares(assets_, state.redeemPrice, MathLib.Rounding.Down));

        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        maxShares = uint256(_maxRedeem(controller));
    }

    function _maxRedeem(address controller) internal view returns (uint128 shares) {
        QueueState storage state = queueStates[controller];
        shares = _calculateShares(state.maxWithdraw, state.redeemPrice, MathLib.Rounding.Down);
    }

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        _validateController(controller);

        if (shares > maxRedeem(controller)) revert ErrorsLib.ExceedsMaxRedeem();

        QueueState storage state = queueStates[controller];
        uint128 assetsUp = _calculateAssets(shares.toUint128(), state.redeemPrice, MathLib.Rounding.Up);
        uint128 assetsDown = _calculateAssets(shares.toUint128(), state.redeemPrice, MathLib.Rounding.Down);
        _processRedeem(state, assetsUp, assetsDown, receiver);
        assets = uint256(assetsDown);

        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    function fulfillDepositRequest(address controller, uint128 assetsToFulfill, uint128 sharesToMint) 
        external 
        onlyRebalancer 
    {
        QueueState storage state = queueStates[controller];
        if (state.pendingDepositRequest == 0) revert ErrorsLib.NoPendingDepositRequest();
        
        IERC20(asset).safeTransferFrom(escrow, address(this), assetsToFulfill);
        _mint(escrow, sharesToMint);
        
        state.pendingDepositRequest = state.pendingDepositRequest > assetsToFulfill ? 
            state.pendingDepositRequest - assetsToFulfill : 
            0;
        state.maxMint += sharesToMint;
        state.depositPrice = _calculatePrice(assetsToFulfill, sharesToMint);
        
        onDepositClaimable(controller, assetsToFulfill, sharesToMint);
    }

    function fulfillRedeemRequest(address controller, uint128 sharesToFulfill, uint128 assetsToReturn)
        external
        onlyRebalancer
    {
        QueueState storage state = queueStates[controller];
        if (state.pendingRedeemRequest == 0) revert ErrorsLib.NoPendingRedeemRequest();
        
        IERC20(asset).safeTransferFrom(address(this), escrow, assetsToReturn);
        _burn(escrow, sharesToFulfill);
        
        state.pendingRedeemRequest = state.pendingRedeemRequest > sharesToFulfill ? 
            state.pendingRedeemRequest - sharesToFulfill : 
            0;
        state.maxWithdraw += assetsToReturn;
        state.redeemPrice = _calculatePrice(assetsToReturn, sharesToFulfill);
        
        onRedeemClaimable(controller, assetsToReturn, sharesToFulfill);
    }

    /* INTERNAL */
    function _processDeposit(QueueState storage state, uint128 sharesUp, uint128 sharesDown, address receiver)
        internal
    {
        if (sharesUp > state.maxMint) revert ErrorsLib.ExceedsMaxDeposit();
        state.maxMint = state.maxMint > sharesUp ? state.maxMint - sharesUp : 0;
        if (sharesDown > 0) {
            IERC20(address(this)).safeTransferFrom(escrow, receiver, sharesDown);
        }
    }

    function _processRedeem(QueueState storage state, uint128 assetsUp, uint128 assetsDown, address receiver)
        internal
    {
        if (assetsUp > state.maxWithdraw) revert ErrorsLib.ExceedsMaxWithdraw();
        state.maxWithdraw = state.maxWithdraw > assetsUp ? state.maxWithdraw - assetsUp : 0;
        if (assetsDown > 0) IERC20(asset).safeTransferFrom(escrow, receiver, assetsDown);
    }

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

    function _calculatePrice(uint128 assets, uint128 shares) internal view returns (uint256) {
        if (assets == 0 || shares == 0) {
            return 0;
        }

        (uint8 assetDecimals, uint8 nodeDecimals) = _getNodeDecimals();
        return _toPriceDecimals(assets, assetDecimals).mulDiv(
            10 ** PRICE_DECIMALS, _toPriceDecimals(shares, nodeDecimals), MathLib.Rounding.Down
        );
    }

    function _toPriceDecimals(uint128 _value, uint8 decimals) internal pure returns (uint256) {
        if (PRICE_DECIMALS == decimals) return uint256(_value);
        return uint256(_value) * 10 ** (PRICE_DECIMALS - decimals);
    }

    function _fromPriceDecimals(uint256 _value, uint8 decimals) internal pure returns (uint128) {
        if (PRICE_DECIMALS == decimals) return _value.toUint128();
        return (_value / 10 ** (PRICE_DECIMALS - decimals)).toUint128();
    }

    function _getNodeDecimals() internal view returns (uint8 assetDecimals, uint8 nodeDecimals) {
        assetDecimals = IERC20Metadata(asset).decimals();
        nodeDecimals = decimals();
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

    function _setInitialComponents(
        address[] memory components_,
        ComponentAllocation[] memory allocations
    ) internal {
        unchecked {
            for (uint256 i; i < components_.length; ++i) {
                if (components_[i] == address(0)) revert ErrorsLib.ZeroAddress();
                components.push(components_[i]);
                componentAllocations[components_[i]] = allocations[i];
                emit EventsLib.ComponentAdded(address(this), components_[i], allocations[i]);
            }
        }
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

    /* ERC-20 MINT/BURN FUNCTIONS */
    function mint(address user, uint256 value) external {
        require(msg.sender == address(this), "Only contract can mint");
        _mint(user, value);
    }

    function burn(address user, uint256 value) external {
        require(msg.sender == address(this), "Only contract can burn");
        _burn(user, value);
    }

    /* VIEW FUNCTIONS */
    function pricePerShare() external view returns (uint256) {
        return convertToAssets(10 ** decimals());
    }

    function getComponents() external view returns (address[] memory) {
        return components;
    }

    function isComponent(address component) external view returns (bool) {
        return _isComponent(component);
    }
    
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        // TODO: Implement preview deposit logic
        return 0;
    }

    function previewMint(uint256 shares) external view returns (uint256 assets) {
        // TODO: Implement preview mint logic
        return 0;
    }

    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        // TODO: Implement preview withdraw logic
        return 0;
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        // TODO: Implement preview redeem logic
        return 0;
    }

    // ... rest of existing code ...
}
