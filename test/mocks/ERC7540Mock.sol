// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7540Deposit, IERC7540Redeem} from "src/interfaces/IERC7540.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

/**
 * @title ERC7540 Mock Contract
 * @dev Mock implementation of Centrifuge's ERC7540 standard for testing
 * @notice share price for clamable tokens is not accurate enough for testing with interest yet
 * @notice only uses mint() & withdraw(), as deposit() & redeem() can lead to precision loss
 */
contract ERC7540Mock is IERC7540Deposit, IERC7540Redeem, ERC20, ERC165 {
    using Math for uint256;

    address public immutable asset;
    address public poolManager;

    // Mappings
    mapping(address => mapping(address => bool)) private _operators;
    mapping(address => uint256) public claimableDepositRequests; // stored as assets
    mapping(address => uint256) public claimableRedeemRequests; // stored as shares
    mapping(address => uint256) public controllerToDepositIndex;
    mapping(address => uint256) public controllerToRedeemIndex;

    // Structs
    struct PendingRequest {
        address controller;
        uint256 amount;
    }

    // Arrays
    PendingRequest[] public pendingDepositRequests; // stored as assets
    PendingRequest[] public pendingRedeemRequests; // stored as shares

    // @dev Requests for Centrifuge pool are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    /**
     * @dev claimableShares and pendingAssets are used to keep the vault in balance.
     *      claimableShares is used to track the number of shares that can be minted by users.
     *      pendingAssets is used to track the number of assets waiting to be deposited by users.
     *      claimableShares are not included in totalSupply().
     *      pendingAssets are not included in totalAssets().
     */
    uint256 public claimableShares; // represented as shares that can be minted
    uint256 public pendingAssets; // represented as assets waiting to be deposited

    // @dev claimableSharePrice is defined when manager calls processPendingDeposits
    // todo: fix this as will not work when you start earning yield
    uint256 public claimableSharePrice; // defined when manager calls processPendingDeposits

    // Events
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    // Errors
    error ERC7540Mock_NoPendingDepositAvailable();
    error ERC7540Mock_NoPendingRedeemAvailable();
    error ERC7540Mock_NoClaimableRedeemAvailable();
    error ERC7540Mock_ExceedsPendingDeposit();
    error ERC7540Mock_ExceedsPendingRedeem();
    error ERC7540Mock_NotImplementedYet();

    // Modifiers
    modifier onlyManager() {
        require(msg.sender == poolManager, "only poolManager can execute");
        _;
    }

    constructor(IERC20 _asset, string memory _name, string memory _symbol, address _manager) ERC20(_name, _symbol) {
        poolManager = _manager;
        asset = address(_asset);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT FLOW
    //////////////////////////////////////////////////////////////*/
    // requestDeposit is called by a depositor.
    // Transfers assets from user to vault when requestDeposit is called
    // Transferred assets are added to the pendingDepositRequests struct and pendingDeposits variable.
    // PendingDeposits is subtracted from totalAssets until user has minted shares.

    function requestDeposit(uint256 assets, address controller, address owner) public virtual returns (uint256) {
        require(assets > 0, "Cannot request deposit of 0 assets");
        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        // Transfer assets from owner to vault
        require(IERC20(asset).transferFrom(owner, address(this), assets), "Transfer failed");

        // sets the index to the index of the controller if one exists
        uint256 index = controllerToDepositIndex[controller];

        // if an index is found the assets are added to the pending requestDeposit
        if (index > 0) {
            pendingDepositRequests[index - 1].amount += assets;

            // add request amount to pendingAssets
            pendingAssets += assets;

            // or it creates a new pending request struct
        } else {
            PendingRequest memory newRequest = PendingRequest({controller: controller, amount: assets});

            // and adds it to the pendingDepositRequests array and the controllerToDepositIndex
            pendingDepositRequests.push(newRequest);
            controllerToDepositIndex[controller] = pendingDepositRequests.length;

            // add request amount to pendingAssets
            pendingAssets += assets;
        }

        // Emit DepositRequest event
        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);

        return REQUEST_ID;
    }

    function pendingDepositRequest(uint256, address controller) external view returns (uint256 assets) {
        uint256 index = controllerToDepositIndex[controller];
        if (index == 0) {
            return 0;
        } else {
            return pendingDepositRequests[index - 1].amount;
        }
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256 assets) {
        return claimableDepositRequests[controller];
    }

    // Called by vault manager to fulfill all the pending deposits in one transaction.
    // note: there is a risk that share price will worsen for depositors if they have not minted pendingDeposit before next time processPendingDeposits is called
    function processPendingDeposits() public virtual onlyManager {
        uint256 totalPendingAssets = pendingAssets;
        uint256 pendingDepositCount = pendingDepositRequests.length;

        // uses totalPendingAssets to calculate pendingShares to be minted. convertPendingToshares() performs this calculation by adding already pendingShares to the totalSupply, and subtracting pendingDeposits from totalSupply().

        // this ensures that assets that have been transferred to the vault but not deposited are not included in totalAssets(), and that shares for claimableDeposits that are claimable but not yet minted are included in totalSupply()
        uint256 newShares = convertPendingToShares(totalPendingAssets, Math.Rounding.Floor);

        // newly avaiable shares are appended to claimable Shares
        claimableShares += newShares;

        console.log("PENDING assets: ", pendingAssets);
        // claimableShares are divided by pendingDeposits to get shares per asset for minting
        claimableSharePrice = Math.mulDiv(newShares, 1e18, pendingAssets, Math.Rounding.Floor);

        // Move deposits from pending to claimable state
        // Claimable deposits are stored as assets
        for (uint256 i = 0; i < pendingDepositCount; i++) {
            PendingRequest memory request = pendingDepositRequests[i];

            claimableDepositRequests[request.controller] += request.amount;

            // Clear the controllerToIndex entry for this controller
            delete controllerToDepositIndex[request.controller];
        }

        // Clear all processed data
        delete pendingDepositRequests;
        pendingAssets = 0;
    }

    function deposit(uint256 assets, address receiver, address controller) public returns (uint256 shares) {}

    function mint(uint256 shares, address receiver, address /* controller_ */ ) public virtual returns (uint256 assets) {
        address controller = msg.sender;

        // Check if there's any claimable deposit for the controller
        if (claimableDepositRequests[controller] == 0) {
            revert ERC7540Mock_NoPendingDepositAvailable();
        }

        // Calculate assets based on shares and claimableSharePrice
        assets = Math.mulDiv(shares, claimableSharePrice, 1e18, Math.Rounding.Floor);

        // Check if requested assets exceed the claimable amount
        if (assets > claimableDepositRequests[controller]) {
            revert ERC7540Mock_ExceedsPendingDeposit();
        }

        // Subtract from claimableShares
        claimableShares -= shares;

        pendingAssets -= assets;

        // Update claimable balance
        claimableDepositRequests[controller] -= assets;

        // Mint shares to the receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                            REDEMPTION FLOW
    //////////////////////////////////////////////////////////////*/
    function requestRedeem(uint256 shares, address controller, address owner) public virtual returns (uint256) {
        require(shares > 0, "Cannot request redeem of 0 shares");
        require(balanceOf(owner) >= shares, "Insufficient shares");
        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        // Transfer ERC4626 share tokens from owner back to vault
        require(IERC20((address(this))).transferFrom(owner, address(this), shares), "Transfer failed");

        uint256 index = controllerToRedeemIndex[controller];

        if (index > 0) {
            pendingRedeemRequests[index - 1].amount += shares;
        } else {
            PendingRequest memory newRequest = PendingRequest({controller: controller, amount: shares});

            pendingRedeemRequests.push(newRequest);
            controllerToRedeemIndex[controller] = pendingRedeemRequests.length;
        }

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);

        return REQUEST_ID;
    }

    function pendingRedeemRequest(uint256, address controller) external view returns (uint256 shares) {
        uint256 index = controllerToRedeemIndex[controller];
        if (index == 0) {
            return 0;
        } else {
            return pendingRedeemRequests[index - 1].amount;
        }
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256 shares) {
        return claimableRedeemRequests[controller];
    }

    function processPendingRedemptions() public virtual onlyManager {
        uint256 totalPendingShares = 0;
        uint256 pendingRedeemCount = pendingRedeemRequests.length;

        // Sum up total pending shares
        for (uint256 i = 0; i < pendingRedeemCount; i++) {
            totalPendingShares += pendingRedeemRequests[i].amount;
        }

        // Calculate total assets to release
        uint256 _totalAssets = convertToAssets(totalPendingShares);

        // Calculate share/asset ratio
        uint256 assetPerShare = Math.mulDiv(_totalAssets, 1e18, totalPendingShares);

        // Allocate shares to each depositor
        for (uint256 i = 0; i < pendingRedeemCount; i++) {
            PendingRequest memory request = pendingRedeemRequests[i];

            uint256 assets = Math.mulDiv(request.amount, assetPerShare, 1e18);

            claimableRedeemRequests[request.controller] += assets;

            // Clear the controllerToIndex entry for this controller
            delete controllerToRedeemIndex[request.controller];
        }

        // Clear all processed data
        delete pendingRedeemRequests;
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares) {
        address controller = msg.sender;

        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        // Check if there's any claimable redeem for the controller
        if (claimableRedeemRequests[controller] == 0) {
            revert ERC7540Mock_NoClaimableRedeemAvailable();
        }

        // check if the requested assets exceed the claimable amount
        if (assets > claimableRedeemRequests[controller]) {
            revert ERC7540Mock_ExceedsPendingRedeem();
        }

        // calculate shares to burn
        shares = convertToShares(assets);

        // update claimable balance
        claimableRedeemRequests[controller] -= assets;

        // burn excess shares
        _burn(address(this), shares);

        // Transfer assets back to user
        IERC20(asset).transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {}

    /*//////////////////////////////////////////////////////////////
                            OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function isOperator(address controller, address operator) public view returns (bool) {
        return _operators[controller][operator];
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        CFG LIQUIDITY POOL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function manager() public view returns (address) {
        return address(poolManager);
    }

    function poolId() public pure returns (uint64) {
        return 1234; // dummy value
    }

    function trancheId() public pure returns (bytes16) {
        return bytes16(0x1234567890abcdef1234567890abcdef); // dummy value
    }

    /*//////////////////////////////////////////////////////////////
                        4626 OVERIDES
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256) {
        if (IERC20(asset).balanceOf(address(this)) > pendingAssets) {
            return IERC20(asset).balanceOf(address(this)) - pendingAssets;
        }
        return 0;
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function previewDeposit(uint256) public pure returns (uint256) {
        revert("ERC7540: previewDeposit not available for async vault");
    }

    function previewMint(uint256) public pure returns (uint256) {
        revert("ERC7540: previewMint not available for async vault");
    }

    function previewWithdraw(uint256) public pure returns (uint256) {
        revert("ERC7540: previewWithdraw not available for async vault");
    }

    function previewRedeem(uint256) public pure returns (uint256) {
        revert("ERC7540: previewRedeem not available for async vault");
    }

    function maxMint(address controller) public view returns (uint256 maxShares) {
        uint256 claimableAssets = claimableDepositRequests[controller];
        maxShares = Math.mulDiv(claimableAssets, 1e18, claimableSharePrice, Math.Rounding.Floor);
    }

    function maxDeposit(address controller) public view returns (uint256 maxAssets) {
        maxAssets = claimableDepositRequests[controller];
    }

    function maxWithdraw(address controller) public view returns (uint256 maxAssets) {
        uint256 redeemableShares = claimableRedeemRequests[controller];
        maxAssets = convertToAssets(redeemableShares);
    }

    function maxRedeem(address controller) public view returns (uint256 maxShares) {
        maxShares = claimableRedeemRequests[controller];
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    // Function takes new pendingAssets and defines new claimableShares.
    // PendingAssets * (totalSupply - claimableShares) / (totalAssets - pendingAssets)
    // Ensure that new shares available to mint account for shares already avaialable to mint but not assets that have been transfered but not minted.
    function convertPendingToShares(uint256 _pendingAssets, Math.Rounding rounding) internal view returns (uint256) {
        return _pendingAssets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), (totalAssets()) + 1, rounding);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE COMPLIANCE
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }

    function share() public view returns (address) {
        return address(this);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
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
