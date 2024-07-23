// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// controller: own the request, can claim assets or shares
// operator: manages the request on the behalf of a controller

contract ERC7540Mock is ERC4626, ERC165 {
    // Mapping to store operators for each controller
    mapping(address => mapping(address => bool)) private _operators;

    // Mapping to store pending deposit requests
    mapping(uint256 => mapping(address => uint256)) private _pendingDepositRequests;

    // Mapping to store claimable deposit requests
    mapping(uint256 => mapping(address => uint256)) private _claimableDepositRequests;

    // Mapping to store pending redeem requests
    mapping(uint256 => mapping(address => uint256)) private _pendingRedeemRequests;

    // Mapping to store claimable redeem requests
    mapping(uint256 => mapping(address => uint256)) private _claimableRedeemRequests;

    // Events
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    
    // When requestId==0, the Vault MUST use purely the controller to discriminate the request state. 
    // The Pending and Claimable state of multiple requests from the same controller would be aggregated. 
    // If a Vault returns 0 for the requestId of any request, it MUST return 0 for all requests.
    uint256 public currentRequestId = 0;

    constructor(IERC20 _asset, string memory _name, string memory _symbol) ERC4626(_asset) ERC20(_name, _symbol) {}

    // ERC-7540 specific functions
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId) {

        // Transfers assets from owner into the Vault and submits a Request for asynchronous deposit.
        // This places the Request in Pending state,
        // with a corresponding increase in pendingDepositRequest for the amount assets.

        require(assets > 0, "Cannot request deposit of 0 assets");
        require(owner == msg.sender || isOperator(owner, msg.sender), "Not authorized");

        requestId = currentRequestId;

        // Transfer assets from owner to vault
        require(IERC20(asset()).transferFrom(owner, address(this), assets), "Transfer failed");

        // Update pending deposit requests
        _pendingDepositRequests[requestId][controller] += assets;

        // Emit DepositRequest event
        emit DepositRequest(controller, owner, requestId, msg.sender, assets);

        return requestId;
    }

    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets) {
        return _pendingDepositRequests[requestId][controller];
    }

    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets) {
        return _claimableDepositRequests[requestId][controller];
    }

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId) {
        // Implementation
    }

    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares) {
        return _pendingRedeemRequests[requestId][controller];
    }

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

    // Overrides for ERC-4626 functions
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        return deposit(assets, receiver, msg.sender);
    }

    function deposit(uint256 assets, address receiver, address controller) public virtual returns (uint256) {
        require(controller == msg.sender || _operators[controller][msg.sender], "Not authorized");
        // Implementation (don't transfer assets, use claimable amount)
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        return mint(shares, receiver, msg.sender);
    }

    function mint(uint256 shares, address receiver, address controller) public virtual returns (uint256) {
        require(controller == msg.sender || _operators[controller][msg.sender], "Not authorized");
        // Implementation (don't transfer assets, use claimable amount)
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        require(owner == msg.sender || _operators[owner][msg.sender], "Not authorized");
        // Implementation (don't transfer shares, use claimable amount)
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        require(owner == msg.sender || _operators[owner][msg.sender], "Not authorized");
        // Implementation (don't transfer shares, use claimable amount)
        return super.redeem(shares, receiver, owner);
    }

    // Override preview functions to revert for async flows
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        revert("Async deposit: preview not available");
    }

    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        revert("Async mint: preview not available");
    }

    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        revert("Async withdraw: preview not available");
    }

    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        revert("Async redeem: preview not available");
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
