// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {Ownable2Step, Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {INode} from "./interfaces/INode.sol";
import {IQueueManager} from "./interfaces/IQueueManager.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";


/**
 * @title Node
 * @author ODND Studios
 */
contract Node is ERC20, Ownable2Step, INode {
    using UtilsLib for uint256;
    using Address for address;

    /* CONSTANTS */

    /// @dev Requests are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    /* IMMUTABLES */

    /// @inheritdoc IERC7575
    address public immutable asset;

    /// @inheritdoc IERC7575
    address public immutable share;

    /* STORAGE */

    /// @inheritdoc INode
    address public escrow;

    /// @inheritdoc INode
    IQueueManager public manager;

    /// @inheritdoc INode
    mapping(address => bool) public isRebalancer;

    /// @inheritdoc INode
    address[] public components;

    /// @inheritdoc INode
    mapping(address => ComponentTargetWeight) public componentTargetWeights;

    /// @inheritdoc IERC7540Operator
    mapping(address => mapping(address => bool)) public isOperator;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param asset_ The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param escrow_ The address of the escrow.
    /// @param rebalancers The addresses of the initial rebalancers.
    /// @param owner The owner of the contract.
    constructor(
        address asset_,
        string memory name,
        string memory symbol,
        address escrow_,
        address manager_,
        address[] memory rebalancers,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        asset = asset_;
        share = address(this);
        escrow = escrow_;
        manager = IQueueManager(manager_);

        for (uint256 i = 0; i < rebalancers.length; i++) {
            isRebalancer[rebalancers[i]] = true;
        }
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not a rebalancer.
    modifier onlyRebalancer() {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.NotRebalancer();
        _;
    }

    /* OWNER */

    /// @inheritdoc INode
    function setEscrow(address newEscrow) external onlyOwner {
        if (newEscrow == escrow) revert ErrorsLib.AlreadySet();
        escrow = newEscrow;
        emit EventsLib.SetEscrow(newEscrow);
    }

    /// @inheritdoc INode
    function addRebalancer(address newRebalancer) external onlyOwner {
        if (isRebalancer[newRebalancer]) revert ErrorsLib.AlreadySet();
        isRebalancer[newRebalancer] = true;
        emit EventsLib.AddRebalancer(newRebalancer);
    }

    /// @inheritdoc INode
    function removeRebalancer(address oldRebalancer) external onlyOwner {
        if (!isRebalancer[oldRebalancer]) revert ErrorsLib.NotSet();
        isRebalancer[oldRebalancer] = false;
        emit EventsLib.RemoveRebalancer(oldRebalancer);
    }

    /* REBALANCER */

    /// @inheritdoc INode
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyRebalancer returns (bytes memory result) {
        result = target.functionCallWithValue(data, value);
        emit EventsLib.Execute(target, value, data, result);
    }

    /* ERC-7540 */

    /// @inheritdoc IERC7540Deposit
    function requestDeposit(uint256 assets, address controller, address owner) public returns (uint256) {
        if (owner != msg.sender && !isOperator[owner][msg.sender]) revert ErrorsLib.InvalidOwner();
        if (IERC20(asset).balanceOf(owner) < assets) revert ErrorsLib.InsufficientBalance();

        require(
            manager.requestDeposit(address(this), assets, controller, owner, msg.sender),
            ErrorsLib.RequestDepositFailed()
        );
        SafeTransferLib.safeTransferFrom(asset, owner, address(escrow), assets);

        emit EventsLib.DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    /// @inheritdoc IERC7540Deposit
    function pendingDepositRequest(uint256, address controller) public view returns (uint256 pendingAssets) {
        pendingAssets = manager.pendingDepositRequest(address(this), controller);
    }

    /// @inheritdoc IERC7540Deposit
    function claimableDepositRequest(uint256, address controller) external view returns (uint256 claimableAssets) {
        claimableAssets = maxDeposit(controller);
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint256 shares, address controller, address owner) public returns (uint256) {
        if (balanceOf(owner) < shares) revert ErrorsLib.InsufficientBalance();

        // If msg.sender is operator of owner, the transfer is executed as if
        // the sender is the owner, to bypass the allowance check
        address sender = isOperator[owner][msg.sender] ? owner : msg.sender;

        require(
            manager.requestRedeem(address(this), shares, controller, owner, sender),
            ErrorsLib.RequestRedeemFailed()
        );
        SafeTransferLib.safeTransferFrom(share, owner, address(escrow), shares);

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /// @inheritdoc IERC7540Redeem
    function pendingRedeemRequest(uint256, address controller) public view returns (uint256 pendingShares) {
        pendingShares = manager.pendingRedeemRequest(address(this), controller);
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

    /* ERC-165 */

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC7540Deposit).interfaceId || interfaceId == type(IERC7540Redeem).interfaceId
            || interfaceId == type(IERC7540Operator).interfaceId || interfaceId == type(IERC7575).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    /* ERC-4626 */

    /// @inheritdoc IERC7575
    function totalAssets() external view returns (uint256) {
        return convertToAssets(IERC20Metadata(share).totalSupply());
    }

    /// @inheritdoc IERC7575
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        shares = manager.convertToShares(address(this), assets);
    }

    /// @inheritdoc IERC7575
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = manager.convertToAssets(address(this), shares);
    }

    /// @inheritdoc IERC7575
    function maxDeposit(address controller) public view returns (uint256 maxAssets) {
        maxAssets = manager.maxDeposit(address(this), controller);
    }

    /// @inheritdoc IERC7540Deposit
    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);
        shares = manager.deposit(address(this), assets, receiver, controller);
        emit Deposit(receiver, controller, assets, shares);
    }

    /// @inheritdoc IERC7575
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = deposit(assets, receiver, msg.sender);
    }

    /// @inheritdoc IERC7575
    function maxMint(address controller) public view returns (uint256 maxShares) {
        maxShares = manager.maxMint(address(this), controller);
    }

    /// @inheritdoc IERC7540Deposit
    function mint(uint256 shares, address receiver, address controller) public returns (uint256 assets) {
        _validateController(controller);
        assets = manager.mint(address(this), shares, receiver, controller);
        emit Deposit(receiver, controller, assets, shares);
    }

    /// @inheritdoc IERC7575
    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = mint(shares, receiver, msg.sender);
    }

    /// @inheritdoc IERC7575
    function maxWithdraw(address controller) public view returns (uint256 maxAssets) {
        maxAssets = manager.maxWithdraw(address(this), controller);
    }

    /// @inheritdoc IERC7575
    /// @notice     DOES NOT support controller != msg.sender since shares are already transferred on requestRedeem
    function withdraw(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        _validateController(controller);
        shares = manager.withdraw(address(this), assets, receiver, controller);
        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @inheritdoc IERC7575
    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        maxShares = manager.maxRedeem(address(this), controller);
    }

    /// @inheritdoc IERC7575
    /// @notice     DOES NOT support controller != msg.sender since shares are already transferred on requestRedeem.
    ///             When claiming redemption requests using redeem(), there can be some precision loss leading to dust.
    ///             It is recommended to use withdraw() to claim redemption requests instead.
    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        _validateController(controller);
        assets = manager.redeem(address(this), shares, receiver, controller);
        emit Withdraw(msg.sender, receiver, controller, assets, shares);
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

    /* INTERNAL */

    /// @notice Ensures msg.sender can operate on behalf of controller.
    function _validateController(address controller) internal view {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) revert ErrorsLib.InvalidController();
    }
}
