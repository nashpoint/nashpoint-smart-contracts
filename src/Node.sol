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
import {IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {MathLib} from "./libraries/MathLib.sol";

// temp import prb math
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

contract Node is INode, ERC20, Ownable {
    using Address for address;
    using SafeERC20 for IERC20;
    using MathLib for uint256;

    /* CONSTANTS */
    uint256 private constant REQUEST_ID = 0;
    uint256 internal constant PRICE_DECIMALS = 18;

    // TEMP swing pricing contstants
    //  percentages: 1e18 == 100%
    uint256 public maxDiscount = 2e16;
    uint256 public targetReserveRatio = 10e16;
    uint256 public maxDelta = 1e16;
    uint256 public asyncMaxDelta = 3e16;
    bool public instantLiquidationsEnabled = true;
    bool public swingPricingEnabled = false;
    bool public liquidateReserveBelowTarget = true;
    int256 public immutable SCALING_FACTOR = -5e18;
    uint256 public immutable WAD = 1e18;

    /// @dev PRBMath types and conversions: used for swing price calculations
    SD59x18 maxDiscountSD = sd(int256(maxDiscount));
    SD59x18 targetReserveRatioSD = sd(int256(targetReserveRatio));
    SD59x18 scalingFactorSD = sd(SCALING_FACTOR);

    /* IMMUTABLES */
    address public immutable registry;
    address public immutable asset;
    address public immutable share;

    /* STORAGE */
    address[] public components;
    mapping(address => ComponentAllocation) public componentAllocations;
    ComponentAllocation public reserveAllocation;

    mapping(address => Request) public requests;

    IQuoter public quoter;
    address public escrow;
    mapping(address => mapping(address => bool)) public isOperator;

    address public rebalancer; // todo: make this a mapping
    mapping(address => bool) public isRouter;

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
    function execute(address target, uint256 value, bytes calldata data) external onlyRouter returns (bytes memory) {
        /// todo: change this so that execute calls the router
        if (target == address(0)) revert ErrorsLib.ZeroAddress();

        bytes memory result = target.functionCallWithValue(data, value);
        emit EventsLib.Execute(target, value, data, result);
        return result;
    }

    /* ERC-7540 FUNCTIONS */
    function requestRedeem(uint256 shares, address controller, address owner) public returns (uint256) {
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();

        if (shares == 0) revert ErrorsLib.ZeroAmount();
        Request storage request = requests[controller];
        request.pendingRedeemRequest = request.pendingRedeemRequest + shares;

        // temp implementation
        // todo do properly with swing pricing
        request.sharesAdjusted = request.sharesAdjusted + shares;

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

    function maxDeposit(address /* controller */ ) public pure returns (uint256 maxAssets) {
        // todo find an actual use for this
        return type(uint256).max;
    }

    /// note: openzeppelin ERC4626 function
    function deposit(uint256 assets, address receiver) public virtual returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ErrorsLib.ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = this.previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    function maxMint(address controller) public view returns (uint256 maxShares) {
        Request storage request = requests[controller];
        maxShares = request.claimableRedeemRequest;
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {}

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

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {}

    function fulfillRedeemFromReserve(address controller) external onlyRebalancer {
        Request storage request = requests[controller];
        if (request.pendingRedeemRequest == 0) revert ErrorsLib.NoPendingRedeemRequest();

        uint256 sharesPending = request.pendingRedeemRequest;
        uint256 sharesAdjusted = request.sharesAdjusted;
        uint256 assetsToReturn = convertToAssets(sharesAdjusted);

        IERC20(asset).safeTransferFrom(address(this), escrow, assetsToReturn);
        _burn(escrow, sharesPending);

        request.pendingRedeemRequest -= sharesPending;
        request.claimableRedeemRequest += sharesPending;
        request.claimableAssets += assetsToReturn;
        request.sharesAdjusted -= sharesAdjusted;

        onRedeemClaimable(controller, assetsToReturn, sharesPending);
    }

    /* INTERNAL */
    function _processDeposit(Request storage request, uint256 sharesUp, uint256 sharesDown, address receiver)
        internal
    {
        // todo: feed both deposit and mint into this
    }

    function _processRedeem(Request storage request, uint256 assetsUp, uint256 assetsDown, address receiver) internal {
        // todo: feed both redeem and withdraw here
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
        return _convertToShares(assets, MathLib.Rounding.Down);
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

    /*//////////////////////////////////////////////////////////////
                        ERC4626 INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IERC4626-totalAssets}.
     */
    function totalAssets() public view virtual returns (uint256) {
        return quoter.getTotalAssets(address(this));
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

    /*//////////////////////////////////////////////////////////////
                        DECIMAL CONVERSION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _calculateShares(uint256 assets, uint256 price, MathLib.Rounding rounding)
        internal
        view
        returns (uint256 shares)
    {
        if (price == 0 || assets == 0) {
            shares = 0;
        } else {
            (uint256 assetDecimals, uint256 nodeDecimals) = _getNodeDecimals();

            uint256 sharesInPriceDecimals =
                _toPriceDecimals(assets, assetDecimals).mulDiv(10 ** PRICE_DECIMALS, price, rounding);

            shares = _fromPriceDecimals(sharesInPriceDecimals, nodeDecimals);
        }
    }

    function _calculateAssets(uint256 shares, uint256 price, MathLib.Rounding rounding)
        internal
        view
        returns (uint256 assets)
    {
        if (price == 0 || shares == 0) {
            assets = 0;
        } else {
            (uint256 assetDecimals, uint256 nodeDecimals) = _getNodeDecimals();

            uint256 assetsInPriceDecimals =
                _toPriceDecimals(shares, nodeDecimals).mulDiv(price, 10 ** PRICE_DECIMALS, rounding);

            assets = _fromPriceDecimals(assetsInPriceDecimals, assetDecimals);
        }
    }

    function _calculatePrice(uint256 assets, uint256 shares) internal view returns (uint256) {
        if (assets == 0 || shares == 0) {
            return 0;
        }

        (uint256 assetDecimals, uint256 nodeDecimals) = _getNodeDecimals();
        return _toPriceDecimals(assets, assetDecimals).mulDiv(
            10 ** PRICE_DECIMALS, _toPriceDecimals(shares, nodeDecimals), MathLib.Rounding.Down
        );
    }

    function _toPriceDecimals(uint256 _value, uint256 decimals) internal pure returns (uint256) {
        if (PRICE_DECIMALS == decimals) return _value;
        return _value * 10 ** (PRICE_DECIMALS - decimals);
    }

    function _fromPriceDecimals(uint256 _value, uint256 decimals) internal pure returns (uint256) {
        if (PRICE_DECIMALS == decimals) return _value;
        return _value / 10 ** (PRICE_DECIMALS - decimals);
    }

    function _getNodeDecimals() internal view returns (uint256 assetDecimals, uint256 nodeDecimals) {
        assetDecimals = IERC20Metadata(asset).decimals();
        nodeDecimals = decimals();
    }

    function _getSwingFactor(int256 reserveImpact) internal view returns (uint256 swingFactor) {
        if (!swingPricingEnabled) {
            return 0;
        }
        // checks if a negative number
        if (reserveImpact < 0) {
            revert ErrorsLib.InvalidInput(reserveImpact);

            // else if reserve exceeds target after deposit no swing factor is applied
        } else if (uint256(reserveImpact) >= targetReserveRatio) {
            return 0;

            // else swing factor is applied
        } else {
            SD59x18 reserveImpactSd = sd(int256(reserveImpact));

            SD59x18 result = maxDiscountSD * exp(scalingFactorSD.mul(reserveImpactSd).div(targetReserveRatioSD));

            return uint256(result.unwrap());
        }
    }

    function enableSwingPricing(bool status) public onlyOwner {
        swingPricingEnabled = status;

        emit EventsLib.SwingPricingStatusUpdated(status);
    }
}
