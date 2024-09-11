// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// TODO: Write a test for yield distribution and complex withdrawal. Vault might not be fair

contract ERC7540Mock is IERC7540, ERC4626, ERC165 {
    using Math for uint256;

    // Mappings
    mapping(address => mapping(address => bool)) private _operators;
    mapping(address => uint256) public claimableDepositRequests;
    mapping(address => uint256) public claimableRedeemRequests;
    mapping(address => uint256) public controllerToDepositIndex;
    mapping(address => uint256) public controllerToRedeemIndex;

    // Structs
    struct PendingRequest {
        address controller;
        uint256 amount;
    }

    // Arrays
    PendingRequest[] public pendingDepositRequests;
    PendingRequest[] public pendingRedeemRequests;

    // @dev Requests for Centrifuge pool are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    // Variables
    address public poolManager;
    uint256 public pendingShares; // represented as shares that can be minted
    uint256 public pendingAssets;
    bool private initialized = false;

    // Events
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    // Errors TODO: rename these errors to be more descriptive and include contract name
    error NoPendingDepositAvailable();
    error NoPendingRedeemAvailable();
    error ExceedsPendingDeposit();
    error ExceedsPendingRedeem();
    error NotImplementedYet();

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

    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256) {
        require(assets > 0, "Cannot request deposit of 0 assets");
        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        // Transfer assets from owner to vault
        require(IERC20(asset()).transferFrom(owner, address(this), assets), "Transfer failed");

        // sets the index to the index of the controller if one exists
        uint256 index = controllerToDepositIndex[controller];

        // if an index is found the assets are added to the pending request
        if (index > 0) {
            pendingDepositRequests[index - 1].amount += assets;
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

    function processPendingDeposits() external onlyManager {
        uint256 totalPendingAssets = pendingAssets;
        uint256 pendingDepositCount = pendingDepositRequests.length;

        // create a new function here that converts pending assets to shares
        uint256 totalShares = convertPendingToShares(totalPendingAssets, Math.Rounding.Floor);
        pendingShares += totalShares;

        // Allocate shares to each depositor
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
        revert NotImplementedYet();
    }

    function redeem(uint256, address, address) public pure override returns (uint256) {
        revert NotImplementedYet();
    }

    function mint(uint256 shares, address receiver) public override(ERC4626, IERC7540) returns (uint256 assets) {
        address controller = msg.sender;

        // Check if there's any claimable deposit for the controller
        if (claimableDepositRequests[controller] == 0) {
            revert NoPendingDepositAvailable();
        }

        // Check if requested shares exceed the claimable amount
        if (shares > claimableDepositRequests[controller]) {
            revert ExceedsPendingDeposit();
        }

        // Calculate assets based on shares
        assets = convertToAssets(shares);

        // Update claimable balance
        claimableDepositRequests[controller] -= shares;

        // subtract newly minted shares from pending shares
        pendingShares -= shares;

        // Mint shares to the receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
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
            revert NoPendingRedeemAvailable();
        }

        // check if the requested assets exceed the claimable amount
        if (assets > claimableRedeemRequests[controller]) {
            revert ExceedsPendingRedeem();
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
        return super.totalSupply();
    }

    function totalAssets() public view override(IERC7540, ERC4626) returns (uint256 assets) {
        return super.totalAssets();
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
        return convertToShares(claimableDepositRequests[controller]);
    }

    // HELPERS
    function convertPendingToShares(uint256 _pendingAssets, Math.Rounding rounding) internal view returns (uint256) {
        return _pendingAssets.mulDiv(
            totalSupply() + pendingShares + 10 ** _decimalsOffset(), (totalAssets() - _pendingAssets) + 1, rounding
        );
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
