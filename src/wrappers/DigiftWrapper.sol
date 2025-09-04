// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ISubRedManagement, IDFeedPriceOracle} from "src/interfaces/external/IDigift.sol";
import {RegistryAccessControl} from "src/libraries/RegistryAccessControl.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";

struct State {
    uint256 maxMint;
    uint256 maxWithdraw;
    uint256 pendingDepositRequest;
    uint256 pendingDepositReimbursement;
    uint256 pendingRedeemRequest;
    uint256 pendingRedeemReimbursement;
    uint256 claimableDepositRequest;
    uint256 claimableRedeemRequest;
}

contract DigiftWrapper is ERC20, RegistryAccessControl, IERC7540, IERC7575 {
    using SafeERC20 for IERC20;

    uint256 private constant REQUEST_ID = 0;

    address public immutable asset;
    uint8 internal immutable _assetDecimals;

    address public immutable stToken;
    uint8 internal immutable _stTokenDecimals;

    ISubRedManagement public immutable subRedManagement;
    IDFeedPriceOracle public immutable dFeedPriceOracle;
    uint8 internal immutable _dFeedPriceOracleDecimals;

    mapping(address node => State state) internal _nodeState;

    constructor(
        address asset_,
        address stToken_,
        address subRedManagement_,
        address dFeedPriceOracle_,
        address registry_,
        string memory name_,
        string memory symbol_
    ) RegistryAccessControl(registry_) ERC20(name_, symbol_) {
        asset = asset_;
        stToken = stToken_;
        _assetDecimals = IERC20Metadata(asset_).decimals();
        _stTokenDecimals = IERC20Metadata(stToken_).decimals();
        subRedManagement = ISubRedManagement(subRedManagement_);
        dFeedPriceOracle = IDFeedPriceOracle(dFeedPriceOracle_);
        _dFeedPriceOracleDecimals = IDFeedPriceOracle(dFeedPriceOracle_).decimals();
    }

    function _actionValidation(uint256 amount, address controller, address owner) internal {
        require(amount > 0, "Zero amount");
        require(controller == msg.sender, "Controller should be sender");
        require(owner == msg.sender, "Owner should be sender");
    }

    function requestDeposit(uint256 assets, address controller, address owner) external onlyNode returns (uint256) {
        _actionValidation(assets, controller, owner);
        require(_nodeState[msg.sender].pendingDepositRequest == 0, "Non fulfilled deposit request");
        require(_nodeState[msg.sender].maxMint == 0, "Not claimed deposit request");

        _nodeState[msg.sender].pendingDepositRequest += assets;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(asset).safeIncreaseAllowance(address(subRedManagement), assets);
        subRedManagement.subscribe(stToken, asset, assets, block.timestamp + 1);

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    function requestRedeem(uint256 shares, address controller, address owner) external onlyNode returns (uint256) {
        _actionValidation(shares, controller, owner);
        require(_nodeState[msg.sender].pendingRedeemRequest == 0, "Non fulfilled redeem request");
        require(_nodeState[msg.sender].maxWithdraw == 0, "Not claimed redeem request");

        _nodeState[msg.sender].pendingRedeemRequest += shares;

        IERC20(stToken).safeTransferFrom(msg.sender, address(this), shares);
        IERC20(stToken).safeIncreaseAllowance(address(subRedManagement), shares);
        subRedManagement.redeem(stToken, asset, shares, block.timestamp + 1);

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    function mint(uint256 shares, address receiver, address controller) public onlyNode returns (uint256 assets) {
        _actionValidation(shares, controller, receiver);
        require(_nodeState[msg.sender].claimableDepositRequest > 0, "Non fulfilled deposit request");
        require(_nodeState[msg.sender].maxMint == shares, "Can mint only all shares");

        assets = _nodeState[msg.sender].claimableDepositRequest;

        uint256 assetsToReimburse = _nodeState[msg.sender].pendingDepositReimbursement;

        _nodeState[msg.sender].claimableDepositRequest = 0;
        _nodeState[msg.sender].maxMint = 0;
        _nodeState[msg.sender].pendingDepositReimbursement = 0;

        _mint(msg.sender, shares);

        // if assets are partially used => send back to the node
        if (assetsToReimburse > 0) {
            IERC20(asset).safeTransfer(msg.sender, assetsToReimburse);
        }
        emit Deposit(controller, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address controller)
        external
        onlyNode
        returns (uint256 shares)
    {
        _actionValidation(assets, controller, receiver);

        require(_nodeState[msg.sender].claimableRedeemRequest > 0, "Non fulfilled redeem request");
        require(_nodeState[msg.sender].maxWithdraw == assets, "Can withdraw only all assets");

        shares = _nodeState[msg.sender].claimableRedeemRequest;

        uint256 sharesToReimburse = _nodeState[msg.sender].pendingRedeemReimbursement;
        uint256 sharesToBurn = shares - sharesToReimburse;

        _nodeState[msg.sender].claimableRedeemRequest = 0;
        _nodeState[msg.sender].maxWithdraw = 0;
        _nodeState[msg.sender].pendingRedeemReimbursement = 0;

        _burn(address(this), sharesToBurn);

        if (sharesToReimburse > 0) {
            transfer(msg.sender, sharesToReimburse);
        }

        IERC20(asset).safeTransfer(msg.sender, assets);
        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    function settleDeposit(address node, uint256 shares, uint256 assets) external onlyNodeRebalancer(node) {
        require(_nodeState[node].pendingDepositRequest > 0, "Nothing to settle");
        _nodeState[node].claimableDepositRequest = _nodeState[node].pendingDepositRequest;
        _nodeState[node].pendingDepositRequest = 0;
        _nodeState[node].maxMint = shares;
        _nodeState[node].pendingDepositReimbursement = assets;
        // TODO: we need to protect from malicious or buggy rebalancer
    }

    function settleRedeem(address node, uint256 shares, uint256 assets) external onlyNodeRebalancer(node) {
        require(_nodeState[node].pendingRedeemRequest > 0, "Nothing to settle");
        _nodeState[node].claimableRedeemRequest = _nodeState[node].pendingRedeemRequest;
        _nodeState[node].pendingRedeemRequest = 0;
        _nodeState[node].maxWithdraw = assets;
        _nodeState[node].pendingRedeemReimbursement = shares;
        // TODO: we need to protect from malicious or buggy rebalancer
    }

    function pendingDepositRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].pendingDepositRequest;
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].claimableDepositRequest;
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].pendingRedeemRequest;
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256) {
        return _nodeState[controller].claimableRedeemRequest;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        // TODO:
        return false;
    }

    function totalAssets() external view returns (uint256) {
        return convertToAssets(totalSupply());
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        // TODO: check for the stale update data and big diff ?
        uint256 stTokenPrice = dFeedPriceOracle.getPrice();
        // TODO: asset price should be fetched as well
        // for USDC assume not it's 1 USD;
        return assets * 10 ** (_stTokenDecimals + _dFeedPriceOracleDecimals) / (stTokenPrice * 10 ** (_assetDecimals));
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        // TODO: check for the stale update data and big diff ?
        uint256 stTokenPrice = dFeedPriceOracle.getPrice();
        // TODO: asset price should be fetched as well
        // for USDC assume not it's 1 USD;
        return shares * stTokenPrice * 10 ** (_assetDecimals) / 10 ** (_stTokenDecimals + _dFeedPriceOracleDecimals);
    }

    function maxMint(address controller) public view returns (uint256) {
        return _nodeState[controller].maxMint;
    }

    function maxWithdraw(address controller) external view returns (uint256) {
        return _nodeState[controller].maxWithdraw;
    }

    function decimals() public view override returns (uint8) {
        return _stTokenDecimals;
    }

    function share() external view returns (address) {
        return address(this);
    }

    // Unsupported functions

    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {
        revert();
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        revert();
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        revert();
    }

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        revert();
    }

    function previewDeposit(uint256) external pure returns (uint256) {
        revert();
    }

    function previewMint(uint256) external pure returns (uint256) {
        revert();
    }

    function previewWithdraw(uint256) external pure returns (uint256) {
        revert();
    }

    function previewRedeem(uint256) external pure returns (uint256) {
        revert();
    }

    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        revert();
    }

    function maxDeposit(address controller) public view returns (uint256 maxAssets) {
        revert();
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        revert();
    }

    function isOperator(address controller, address operator) external view returns (bool) {
        revert();
    }
}
