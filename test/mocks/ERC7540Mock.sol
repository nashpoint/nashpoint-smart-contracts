// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ERC7540Mock is ERC4626, ERC165 {
    // Mappings
    mapping(address => mapping(address => bool)) private _operators;
    mapping(uint256 => mapping(address => uint256)) public claimableDepositRequests;
    mapping(uint256 => mapping(address => uint256)) private _pendingRedeemRequests;
    mapping(uint256 => mapping(address => uint256)) private _claimableRedeemRequests;

    // Events
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    // structs
    struct PendingDepositRequest {
        address controller;
        uint256 assets;
        uint256 requestId;
    }

    PendingDepositRequest[] public pendingDepositRequests;
    mapping(address => uint256) public controllerToIndex;

    uint256 public currentRequestId = 0; // matches centrifuge implementation
    address public poolManager;

    // When requestId==0, the Vault MUST use purely the controller to discriminate the request state.
    // The Pending and Claimable state of multiple requests from the same controller would be aggregated.
    // If a Vault returns 0 for the requestId of any request, it MUST return 0 for all requests.

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

        uint256 index = controllerToIndex[controller];

        if (index > 0) {
            pendingDepositRequests[index - 1].assets += assets;
        } else {
            PendingDepositRequest memory newRequest =
                PendingDepositRequest({controller: controller, assets: assets, requestId: requestId});

            pendingDepositRequests.push(newRequest);
            controllerToIndex[controller] = pendingDepositRequests.length;
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
        uint256 index = controllerToIndex[controller];
        require(index > 0, "No pending deposit for controller");
        return pendingDepositRequests[index - 1].assets;
    }

    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets) {
        return claimableDepositRequests[requestId][controller];
    }

    // function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId) {
    //     // Implementation
    // }

    // function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares) {
    //     return _pendingRedeemRequests[requestId][controller];
    // }

    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares) {
        return _claimableRedeemRequests[requestId][controller];
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
            totalPendingAssets += pendingDepositRequests[i].assets;
        }

        // Calculate total shares to mint
        uint256 totalShares = convertToShares(totalPendingAssets);

        // Calculate share/asset ratio
        // uint256 sharePerAsset = totalShares * 1e18 / totalPendingAssets; // Use 1e18 for precision
        uint256 sharePerAsset = Math.mulDiv(totalShares, 1e18, totalPendingAssets);

        // Allocate shares to each depositor
        for (uint256 i = 0; i < pendingDepositCount; i++) {
            PendingDepositRequest memory request = pendingDepositRequests[i];
            // uint256 shares = (request.assets * sharePerAsset) / 1e18;
            uint256 shares = Math.mulDiv(request.assets, sharePerAsset, 1e18);

            claimableDepositRequests[request.requestId][request.controller] += shares;

            // Clear the controllerToIndex entry for this controller
            delete controllerToIndex[request.controller];
        }

        // Clear all processed data
        delete pendingDepositRequests;
    }

    // ERC4626 overrides

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        uint256 requestId = currentRequestId;
        address controller = msg.sender;

        // replace these with custom errors
        require(claimableDepositRequests[requestId][controller] > 0, "No claimableDeposit for address");
        require(shares <= claimableDepositRequests[requestId][controller]);
        require(msg.sender == controller || isOperator(controller, msg.sender), "Address is not controller or operater");

        // Calculate assets based on shares 
        assets = convertToAssets(shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        // Mint shares to the receiver
        _mint(receiver, shares);
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
