// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ERC7540Mock is ERC4626, ERC165 {
    using Math for uint256;

    // Mappings
    mapping(address => mapping(address => bool)) private _operators;
    mapping(uint256 => mapping(address => uint256)) public claimableDepositRequests;
    mapping(uint256 => mapping(address => uint256)) private claimableRedeemRequests;
    mapping(address => uint256) public controllerToDepositIndex;
    mapping(address => uint256) public controllerToRedeemIndex;

    // Structs
    struct PendingRequest {
        address controller;
        uint256 amount;
        uint256 requestId;
    }

    // Arrays
    PendingRequest[] public pendingDepositRequests;
    PendingRequest[] public pendingRedeemRequests;

    // Events
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    // Errors
    error NoPendingDepositAvailable();
    error ExceedsPendingDeposit();

    // Variables
    uint256 public currentRequestId = 0; // matches centrifuge implementation
    address public poolManager;

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

    // ERC-7540 specific functions
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId) {
        require(assets > 0, "Cannot request deposit of 0 assets");
        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        requestId = currentRequestId;

        // Transfer assets from owner to vault
        require(IERC20(asset()).transferFrom(owner, address(this), assets), "Transfer failed");

        uint256 index = controllerToDepositIndex[controller];

        if (index > 0) {
            pendingDepositRequests[index - 1].amount += assets;
        } else {
            PendingRequest memory newRequest =
                PendingRequest({controller: controller, amount: assets, requestId: requestId});

            pendingDepositRequests.push(newRequest);
            controllerToDepositIndex[controller] = pendingDepositRequests.length;
        }

        // Emit DepositRequest event
        emit DepositRequest(controller, owner, requestId, msg.sender, assets);

        return requestId;
    }

    // requestId commented out as unused and causing erro.
    // TODO: check this later as this might break standard
    function pendingDepositRequest( /* uint256 RequestId, */ address controller)
        external
        view
        returns (uint256 assets)
    {
        uint256 index = controllerToDepositIndex[controller];
        require(index > 0, "No pending deposit for controller");
        return pendingDepositRequests[index - 1].amount;
    }

    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets) {
        return claimableDepositRequests[requestId][controller];
    }

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId) {
        require(shares > 0, "Cannot request redeem of 0 shares");
        require(balanceOf(owner) >= shares, "Insufficient shares");
        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        requestId = currentRequestId;

        // Transfer ERC4626 share tokens from owner back to vault
        require(IERC20((address(this))).transferFrom(owner, address(this), shares), "Transfer failed");

        uint256 index = controllerToRedeemIndex[controller];

        if (index > 0) {
            pendingRedeemRequests[index - 1].amount += shares;
        } else {
            PendingRequest memory newRequest =
                PendingRequest({controller: controller, amount: shares, requestId: requestId});

            pendingRedeemRequests.push(newRequest);
            controllerToRedeemIndex[controller] = pendingRedeemRequests.length;
        }

        emit RedeemRequest(controller, owner, requestId, msg.sender, shares);

        return requestId;
    }

    function pendingRedeemRequest( /* uint256 RequestId, */ address controller)
        external
        view
        returns (uint256 shares)
    {
        uint256 index = controllerToRedeemIndex[controller];
        require(index > 0, "No pending redemption for controller");
        return pendingRedeemRequests[index - 1].amount;
    }

    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares) {
        return claimableRedeemRequests[requestId][controller];
    }

    function isOperator(address controller, address operator) public view returns (bool) {
        return _operators[controller][operator];
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    // Pool Manager Functions
    function processPendingDeposits() external onlyManager {
        uint256 totalPendingAssets = 0;
        uint256 pendingDepositCount = pendingDepositRequests.length;

        // Sum up total pending assets
        for (uint256 i = 0; i < pendingDepositCount; i++) {
            totalPendingAssets += pendingDepositRequests[i].amount;
        }

        // create a new function here that converts pending assets to shares
        uint256 totalShares = convertPendingToShares(totalPendingAssets, Math.Rounding.Floor);

        // Calculate share/asset ratio
        uint256 sharePerAsset = Math.mulDiv(totalShares, 1e18, totalPendingAssets);

        // Allocate shares to each depositor
        for (uint256 i = 0; i < pendingDepositCount; i++) {
            PendingRequest memory request = pendingDepositRequests[i];

            uint256 shares = Math.mulDiv(request.amount, sharePerAsset, 1e18, Math.Rounding.Floor);

            claimableDepositRequests[request.requestId][request.controller] += shares;

            // Clear the controllerToIndex entry for this controller
            delete controllerToDepositIndex[request.controller];
        }

        // Clear all processed data
        delete pendingDepositRequests;
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

            claimableRedeemRequests[request.requestId][request.controller] += assets;

            // Clear the controllerToIndex entry for this controller
            delete controllerToRedeemIndex[request.controller];
        }

        // Clear all processed data
        delete pendingRedeemRequests;
    }

    // ERC4626 overrides

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        uint256 requestId = currentRequestId;
        address controller = msg.sender;

        // Check if there's any claimable deposit for the controller
        if (claimableDepositRequests[requestId][controller] == 0) {
            revert NoPendingDepositAvailable();
        }

        // Check if requested shares exceed the claimable amount
        if (shares > claimableDepositRequests[requestId][controller]) {
            revert ExceedsPendingDeposit();
        }

        // Calculate assets based on shares
        assets = convertToAssets(shares);

        // Update claimable balance
        claimableDepositRequests[requestId][controller] -= shares;

        // Mint shares to the receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function convertPendingToShares(uint256 _pendingAssets, Math.Rounding rounding) internal view returns (uint256) {
        return _pendingAssets.mulDiv(
            totalSupply() + 10 ** _decimalsOffset(), (totalAssets() - _pendingAssets) + 1, rounding
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
}
