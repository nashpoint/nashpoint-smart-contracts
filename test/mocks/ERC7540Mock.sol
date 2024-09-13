// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {console2} from "forge-std/Test.sol";

// TODO: Write a test for yield distribution and complex withdrawal. Vault might not be fair

contract ERC7540Mock is IERC7540, ERC4626, ERC165 {
    using Math for uint256;

    // Mappings
    mapping(address => mapping(address => bool)) private _operators;
    mapping(address => uint256) public claimableDepositRequests; // stored as assets
    mapping(address => uint256) public claimableRedeemRequests;
    mapping(address => uint256) public controllerToDepositIndex;
    mapping(address => uint256) public controllerToRedeemIndex;

    // Structs
    struct PendingRequest {
        address controller;
        uint256 amount;
    }

    // Arrays
    PendingRequest[] public pendingDepositRequests; // stored as assets
    PendingRequest[] public pendingRedeemRequests;

    // @dev Requests for Centrifuge pool are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    // Variables
    bool private initialized = false;
    address public poolManager;
    uint256 public claimableShares; // represented as shares that can be minted
    uint256 public pendingAssets; // represented as assets waiting to be deposited
    uint256 public claimableSharePrice; // defined when manager calls processPendingDeposits

    // Events
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    // Errors TODO: rename these errors to be more descriptive and include contract name
    error ERC7540Mock_NoPendingDepositAvailable();
    error ERC7540Mock_NoPendingRedeemAvailable();
    error ERC7540Mock_ExceedsPendingDeposit();
    error ERC7540Mock_ExceedsPendingRedeem();
    error ERC7540Mock_NotImplementedYet();

    // Modifiers
    modifier onlyManager() {
        require(msg.sender == poolManager, "only poolManager can execute");
        _;
    }

    constructor(IERC20 _asset, string memory _name, string memory _symbol, address _manager)
        ERC4626(_asset)
        ERC20(_name, _symbol)
    {
        poolManager = _manager;
    }

    // DEPOSIT FLOW
    // requestDeposit is called by a depositor. Takes value of assets being deposited and adds it to the  pendingDepositRequests struct and pendingDeposits variable. PendingDeposits is used by ProcessPendingDeposits to ensure correct number of shares are allocated for the batch.
    // Always transfers assets from user to vault when requestDeposit is called

    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256) {
        require(assets > 0, "Cannot request deposit of 0 assets");
        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        // Transfer assets from owner to vault
        require(IERC20(asset()).transferFrom(owner, address(this), assets), "Transfer failed");

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
        require(index > 0, "No pending deposit for controller");
        return pendingDepositRequests[index - 1].amount;
    }

    function claimableDepositRequest(uint256, address controller) external view returns (uint256 assets) {
        return claimableDepositRequests[controller];
    }

    // Called by vault manager to fulfill all the pending deposits in one transaction.
    // note: there is a risk that share price will worsen for depositors if they have not minted pendingDeposit before next time processPendingDeposits is called
    function processPendingDeposits() external onlyManager {
        uint256 totalPendingAssets = pendingAssets;
        uint256 pendingDepositCount = pendingDepositRequests.length;

        console2.log("totalPendingAssets :", totalPendingAssets);

        // uses totalPendingAssets to calculate pendingShares to be minted. convertPendingToshares() performs this calculation by adding already pendingShares to the totalSupply, and subtracting pendingDeposits from totalSupply().

        // this ensures that assets that have been transferred to the vault but not deposited are not included in totalAssets(), and that shares for claimableDeposits that are claimable but not yet minted are included in totalSupply()
        uint256 newShares = convertPendingToShares(totalPendingAssets, Math.Rounding.Floor);
        console2.log("newShares :", newShares);

        // newly avaiable shares are appended to claimable Shares
        claimableShares += newShares;

        // claimableShares are divided by pendingDeposits to get shares per asset for minting
        claimableSharePrice = Math.mulDiv(newShares, 1e18, pendingAssets, Math.Rounding.Floor);
        console2.log("claimableSharePrice :", claimableSharePrice);

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

    // REDEMPTION FLOW
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256) {
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
        require(index > 0, "No pending redemption for controller");
        return pendingRedeemRequests[index - 1].amount;
    }

    function claimableRedeemRequest(uint256, address controller) external view returns (uint256 shares) {
        return claimableRedeemRequests[controller];
    }

    function processPendingRedemptions() external onlyManager {
        uint256 totalPendingShares = 0;
        uint256 pendingRedeemCount = pendingRedeemRequests.length;

        // Sum up total pending assets
        for (uint256 i = 0; i < pendingRedeemCount; i++) {
            totalPendingShares += pendingRedeemRequests[i].amount;
        }

        // Calculate total shares to mint
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

    // OPERATOR FUNCTIONS
    function isOperator(address controller, address operator) public view returns (bool) {
        return _operators[controller][operator];
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    // ERC4626 OVERRIDES
    // TODO: Deposit
    // TODO: Redeem

    // TODO: OVERLOADS for all that use an additional controller address

    function deposit(uint256, address) public pure override returns (uint256) {
        revert ERC7540Mock_NotImplementedYet();
    }

    function redeem(uint256, address, address) public pure override returns (uint256) {
        revert ERC7540Mock_NotImplementedYet();
    }

    function mint(uint256 shares, address receiver) public override(ERC4626, IERC7540) returns (uint256 assets) {
        address controller = msg.sender;

        // Check if there's any claimable deposit for the controller
        if (claimableDepositRequests[controller] == 0) {
            revert ERC7540Mock_NoPendingDepositAvailable();
        }

        // Calculate assets based on shares and claimableSharePrice
        assets = Math.mulDiv(shares, claimableSharePrice, 1e18, Math.Rounding.Floor);

        console2.log("claimableDepositRequests[controller] in mint():", claimableDepositRequests[controller]);
        console2.log("shares in mint() :", shares);
        console2.log("claimableSharePrice in mint() :", claimableSharePrice);
        console2.log("assets in mint() :", assets);

        // Check if requested assets exceed the claimable amount
        if (assets > claimableDepositRequests[controller]) {
            revert ERC7540Mock_ExceedsPendingDeposit();
        }

        // Subtract from claimableShares
        claimableShares -= shares;

        // Update claimable balance
        claimableDepositRequests[controller] -= assets;

        // Mint shares to the receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IERC7540)
        returns (uint256 shares)
    {
        address controller = msg.sender;

        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        // Check if there's any claimable redeem for the controller
        if (claimableRedeemRequests[controller] == 0) {
            revert ERC7540Mock_NoPendingRedeemAvailable();
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
        IERC20(asset()).transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    // VIEW FUNCTIONS
    function manager() public view override(IERC7540) returns (address) {
        return address(poolManager);
    }

    function poolId() public pure returns (uint64) {
        return 1234; // dummy value
    }

    function trancheId() public pure returns (bytes16) {
        return bytes16(0x1234567890abcdef1234567890abcdef); // dummy value
    }

    // 4626 OVERIDES

    function approve(address spender, uint256 amount) public override(ERC20, IERC20, IERC7540) returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function balanceOf(address account) public view override(ERC20, IERC20, IERC7540) returns (uint256) {
        return super.balanceOf(account);
    }

    function totalSupply() public view override(IERC7540, ERC20, IERC20) returns (uint256) {
        return super.totalSupply() + claimableShares;
    }

    function totalAssets() public view override(IERC7540, ERC4626) returns (uint256 assets) {
        return super.totalAssets() - pendingAssets;
    }

    function convertToAssets(uint256 shares) public view override(ERC4626, IERC7540) returns (uint256) {
        return super.convertToAssets(shares);
    }

    function convertToShares(uint256 assets) public view override(ERC4626, IERC7540) returns (uint256) {
        return super.convertToShares(assets);
    }

    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        if (initialized) {
            revert("ERC7540: previewDeposit not available for async vault");
        }
        return super.previewDeposit(assets);
    }

    function previewMint(uint256) public view virtual override returns (uint256) {
        revert("ERC7540: previewMint not available for async vault");
    }

    function previewWithdraw(uint256) public view virtual override returns (uint256) {
        revert("ERC7540: previewWithdraw not available for async vault");
    }

    function previewRedeem(uint256) public view virtual override returns (uint256) {
        revert("ERC7540: previewRedeem not available for async vault");
    }

    function maxMint(address controller) public view override(IERC7540, ERC4626) returns (uint256 maxShares) {
        uint256 claimableAssets = claimableDepositRequests[controller];
        maxShares = Math.mulDiv(claimableAssets, 1e18, claimableSharePrice, Math.Rounding.Floor);
        console2.log("maxShares :", maxShares);
    }

    // HELPERS

    // Function takes new pendingAssets and defines new claimableShares.
    // PendingAssets * (totalSupply - claimableShares) / (totalAssets - pendingAssets)
    // Ensure that new shares available to mint account for shares already avaialable to mint but not assets that have been transfered but not minted.
    function convertPendingToShares(uint256 _pendingAssets, Math.Rounding rounding) internal view returns (uint256) {
        return _pendingAssets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), (totalAssets()) + 1, rounding);
    }

    // ERC-165 support
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4626).interfaceId || interfaceId == 0xe3bc4e65 // ERC-7540 operator methods
            || interfaceId == 0x2f0a18c5 // ERC-7575 interface
            || interfaceId == 0xce3bbe50 // Asynchronous deposit methods
            || interfaceId == 0x620ee8e4 // Asynchronous redemption methods
            || super.supportsInterface(interfaceId);
    }

    // ERC-7575 compliance
    function share() public view returns (address) {
        return address(this);
    }

    function asset() public view override(ERC4626, IERC7540) returns (address) {
        return super.asset();
    }
}
