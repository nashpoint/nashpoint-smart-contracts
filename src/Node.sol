// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {INode, ComponentAllocation} from "./interfaces/INode.sol";
import {IQueueManager} from "./interfaces/IQueueManager.sol";
import {IERC7540Deposit, IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";

/**
 * @title Node
 * @author ODND Studios
 */
contract Node is INode, ERC20, Ownable {
    using Address for address;
    using SafeERC20 for IERC20;
    using UtilsLib for uint256;

    /* CONSTANTS */
    uint256 private constant REQUEST_ID = 0;

    /* IMMUTABLES */
    /// @inheritdoc IERC7575
    address public immutable asset;
    /// @inheritdoc IERC7575
    address public immutable share;

    /* STORAGE */
    address[] public components;
    mapping(address => ComponentAllocation) public componentAllocations;
    /// @inheritdoc INode
    address public escrow;
    /// @inheritdoc INode
    mapping(address => bool) public isRebalancer;
    /// @inheritdoc IERC7540Operator
    mapping(address => mapping(address => bool)) public isOperator;
    /// @inheritdoc INode
    IQueueManager public manager;

    /* CONSTRUCTOR */
    /// @notice Initializes the vault with asset, escrow, and rebalancer configuration
    /// @param asset_ Underlying asset address
    /// @param name ERC20 token name
    /// @param symbol ERC20 token symbol
    /// @param escrow_ Escrow contract address
    /// @param manager_ Queue manager address
    /// @param rebalancers Initial set of rebalancer addresses
    /// @param owner Initial owner address
    constructor(
        address asset_,
        string memory name,
        string memory symbol,
        address escrow_,
        address manager_,
        address[] memory rebalancers,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        if (asset_ == address(0) || escrow_ == address(0)) revert ErrorsLib.ZeroAddress();
        
        asset = asset_;
        share = address(this);
        escrow = escrow_;
        manager = IQueueManager(manager_);

        unchecked {
            for (uint256 i; i < rebalancers.length; ++i) {
                isRebalancer[rebalancers[i]] = true;
            }
        }
    }

    /* MODIFIERS */
    modifier onlyRebalancer() {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.NotRebalancer();
        _;
    }

    modifier onlyQueueManager() {
        if (msg.sender != address(manager)) revert ErrorsLib.InvalidSender();
        _;
    }

    /* OWNER FUNCTIONS */
    /// @inheritdoc INode
    function addRebalancer(address newRebalancer) external onlyOwner {
        if (isRebalancer[newRebalancer]) revert ErrorsLib.AlreadySet();
        if (newRebalancer == address(0)) revert ErrorsLib.ZeroAddress();
        isRebalancer[newRebalancer] = true;
        emit EventsLib.AddRebalancer(newRebalancer);
    }

    /// @inheritdoc INode
    function removeRebalancer(address oldRebalancer) external onlyOwner {
        if (!isRebalancer[oldRebalancer]) revert ErrorsLib.NotSet();
        isRebalancer[oldRebalancer] = false;
        emit EventsLib.RemoveRebalancer(oldRebalancer);
    }

    /// @inheritdoc INode
    function setEscrow(address newEscrow) external onlyOwner {
        if (newEscrow == escrow) revert ErrorsLib.AlreadySet();
        if (newEscrow == address(0)) revert ErrorsLib.ZeroAddress();
        escrow = newEscrow;
        emit EventsLib.SetEscrow(newEscrow);
    }

    /// @inheritdoc INode
    function setManager(address newManager) external onlyOwner {
        if (newManager == address(manager)) revert ErrorsLib.AlreadySet();
        if (newManager == address(0)) revert ErrorsLib.ZeroAddress();
        manager = IQueueManager(newManager);
        emit EventsLib.SetManager(newManager);
    }

    /* REBALANCER FUNCTIONS */
    /// @inheritdoc INode
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyRebalancer returns (bytes memory) {
        if (target == address(0)) revert ErrorsLib.ZeroAddress();
        
        bytes memory result = target.functionCallWithValue(data, value);
        emit EventsLib.Execute(target, value, data, result);
        return result;
    }

    /* ERC-7540 FUNCTIONS */
    /// @inheritdoc IERC7540Deposit
    function requestDeposit(uint256 assets, address controller, address owner) public returns (uint256) {
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert ErrorsLib.InvalidOwner();
        if (IERC20(asset).balanceOf(owner) < assets) revert ErrorsLib.InsufficientBalance();

        if (!manager.requestDeposit(assets, controller)) {
            revert ErrorsLib.RequestDepositFailed();
        }
        IERC20(asset).safeTransferFrom(owner, address(escrow), assets);

        emit IERC7540Deposit.DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    /// @inheritdoc IERC7540Deposit
    function pendingDepositRequest(uint256, address controller) public view returns (uint256 pendingAssets) {
        pendingAssets = manager.pendingDepositRequest(controller);
    }

    /// @inheritdoc IERC7540Deposit
    function claimableDepositRequest(uint256, address controller) external view returns (uint256 claimableAssets) {
        claimableAssets = maxDeposit(controller);
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint256 shares, address controller, address owner) public returns (uint256) {
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();

        if (!manager.requestRedeem(shares, controller)) {
            revert ErrorsLib.RequestRedeemFailed();
        }
        IERC20(share).safeTransferFrom(owner, address(escrow), shares);

        emit IERC7540Redeem.RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /// @inheritdoc IERC7540Redeem
    function pendingRedeemRequest(uint256, address controller) public view returns (uint256 pendingShares) {
        pendingShares = manager.pendingRedeemRequest(controller);
    }

    /// @inheritdoc IERC7540Redeem
    function claimableRedeemRequest(uint256, address controller) external view returns (uint256 claimableShares) {
        claimableShares = maxRedeem(controller);
    }

    /// @inheritdoc IERC7540Operator
    function setOperator(address operator, bool approved) public virtual returns (bool success) {
        if (msg.sender == operator) revert ErrorsLib.CannotSetSelfAsOperator();
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        success = true;
    }

    /* ERC-165 FUNCTIONS */
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC7540Deposit).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId
            || interfaceId == type(IERC7540Operator).interfaceId || interfaceId == type(IERC7575).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    /* ERC-4626 FUNCTIONS */
    /// @inheritdoc IERC7575
    function totalAssets() external view returns (uint256) {
        return convertToAssets(totalSupply());
    }

    /// @inheritdoc IERC7575
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        shares = manager.convertToShares(assets);
    }

    /// @inheritdoc IERC7575
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = manager.convertToAssets(shares);
    }

    /// @inheritdoc IERC7575
    function maxDeposit(address controller) public view returns (uint256 maxAssets) {
        maxAssets = manager.maxDeposit(controller);
    }

    /// @inheritdoc IERC7540Deposit
    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);
        shares = manager.deposit(assets, receiver, controller);
        emit IERC7575.Deposit(receiver, controller, assets, shares);
    }

    /// @inheritdoc IERC7575
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = deposit(assets, receiver, msg.sender);
    }

    /// @inheritdoc IERC7575
    function maxMint(address controller) public view returns (uint256 maxShares) {
        maxShares = manager.maxMint(controller);
    }

    /// @inheritdoc IERC7540Deposit
    function mint(uint256 shares, address receiver, address controller) public returns (uint256 assets) {
        _validateController(controller);
        assets = manager.mint(shares, receiver, controller);
        emit IERC7575.Deposit(receiver, controller, assets, shares);
    }

    /// @inheritdoc IERC7575
    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = mint(shares, receiver, msg.sender);
    }

    /// @inheritdoc IERC7575
    function maxWithdraw(address controller) public view returns (uint256 maxAssets) {
        maxAssets = manager.maxWithdraw(controller);
    }

    /// @inheritdoc IERC7575
    /// @notice     DOES NOT support controller != msg.sender since shares are already transferred on requestRedeem
    function withdraw(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);
        shares = manager.withdraw(assets, receiver, controller);
        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @inheritdoc IERC7575
    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        maxShares = manager.maxRedeem(controller);
    }

    /// @inheritdoc IERC7575
    /// @notice     DOES NOT support controller != msg.sender since shares are already transferred on requestRedeem.
    ///             When claiming redemption requests using redeem(), there can be some precision loss leading to dust.
    ///             It is recommended to use withdraw() to claim redemption requests instead.
    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        _validateController(controller);
        assets = manager.redeem(shares, receiver, controller);
        emit IERC7575.Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewDeposit(uint256) external pure returns (uint256) {
        revert();
    }

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewMint(uint256) external pure returns (uint256) {
        revert();
    }

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewWithdraw(uint256) external pure returns (uint256) {
        revert();
    }

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewRedeem(uint256) external pure returns (uint256) {
        revert();
    }

    /// @notice Price of 1 unit of share, quoted in the decimals of the asset.
    function pricePerShare() external view returns (uint256) {
        return convertToAssets(10 ** decimals());
    }

    /// @notice Returns the components of the node
    function getComponents() external view returns (address[] memory) {
        return components;
    }

    /* ERC-20 MINT/BURN FUNCTIONS */
    /// @inheritdoc INode
    function mint(address user, uint256 value) external onlyQueueManager {
        _mint(user, value);
    }

    /// @inheritdoc INode
    function burn(address user, uint256 value) external onlyQueueManager {
        _burn(user, value);
    }

    /* EVENT EMITTERS */
    function onDepositClaimable(address controller, uint256 assets, uint256 shares) public {
        emit DepositClaimable(controller, REQUEST_ID, assets, shares);
    }

    function onRedeemClaimable(address controller, uint256 assets, uint256 shares) public {
        emit RedeemClaimable(controller, REQUEST_ID, assets, shares);
    }

    /* INTERNAL */
    /// @notice Ensures msg.sender can operate on behalf of controller.
    function _validateController(address controller) internal view {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert ErrorsLib.InvalidController();
    }
}
