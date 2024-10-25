// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {
    IERC20,
    IERC4626,
    ERC20,
    ERC4626,
    Math,
    SafeERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable2Step, Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {INode} from "./interfaces/INode.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/**
 * @title Node
 * @author ODND Studios
 */
contract Node is ERC4626, Ownable2Step, INode {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    /* IMMUTABLES */

    /// @notice OpenZeppelin decimals offset used by the ERC4626 implementation.
    /// @dev Calculated to be max(0, 18 - underlyingDecimals) at construction, so the initial conversion rate maximizes
    /// precision between shares and assets.
    uint8 public immutable DECIMALS_OFFSET;

    /* STORAGE */

    address public escrow;

    mapping(address => bool) public isRebalancer;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param escrow_ The address of the escrow.
    /// @param rebalancers The addresses of the initial rebalancers.
    /// @param owner The owner of the contract.
    constructor(
        address asset,
        string memory name,
        string memory symbol,
        address escrow_,
        address[] memory rebalancers,
        address owner
    ) ERC4626(IERC20(asset)) ERC20(name, symbol) Ownable(owner) {
        escrow = escrow_;

        for (uint256 i = 0; i < rebalancers.length; i++) {
            isRebalancer[rebalancers[i]] = true;
        }

        DECIMALS_OFFSET = uint8(uint256(18) - IERC20Metadata(asset).decimals());
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not a rebalancer.
    modifier onlyRebalancer() {
        if (!isRebalancer[msg.sender]) revert ErrorsLib.NotRebalancer();
        _;
    }

    /* ONLY OWNER FUNCTIONS */

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

    /* COMPONENT MANAGEMENT */

    /* REBALANCER FUNCTIONS */

    /// @inheritdoc INode
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyRebalancer returns (bytes memory result) {
        result = target.functionCallWithValue(data, value);

        emit EventsLib.Execute(target, value, data, result);

        return result;
    }

    /* EXTERNAL */

    /* ERC-7540 METHODS */

    /* ERC4626 (PUBLIC) */

    /// @inheritdoc IERC20Metadata
    function decimals() public view override(ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    // /// @inheritdoc IERC4626
    // function totalAssets() public view override(ERC4626) returns (uint256) {
    //     return valuer.getTotalAssets();
    // }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = _convertToSharesWithTotals(assets, totalSupply(), totalAssets(), Math.Rounding.Floor);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = _convertToAssetsWithTotals(shares, totalSupply(), totalAssets(), Math.Rounding.Ceil);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /* ERC4626 (INTERNAL) */

    /// @inheritdoc ERC4626
    function _decimalsOffset() internal view override returns (uint8) {
        return DECIMALS_OFFSET;
    }

    /// @dev Returns the amount of shares that the vault would exchange for the amount of `assets` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToSharesWithTotals(
        uint256 assets,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        return assets.mulDiv(newTotalSupply + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /// @dev Returns the amount of assets that the vault would exchange for the amount of `shares` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToAssetsWithTotals(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 10 ** _decimalsOffset(), rounding);
    }
}
