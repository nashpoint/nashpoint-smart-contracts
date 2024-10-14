// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IEscrow {
    function deposit(address tokenAddress, uint256 tokenAmount) external;
    function withdraw(address withdrawer, address tokenAddress, uint256 tokenAmount) external;
}

contract Escrow is IEscrow, Ownable {
    using SafeERC20 for IERC20;

    address public node;

    modifier onlyNode() {
        require(msg.sender == node, "Only Node contract can call this");
        _;
    }

    // Constructor
    constructor() Ownable(msg.sender) {}

    // Events
    event Deposit(address indexed tokenAddress, uint256 tokenAmount);
    event Withdrawal(address indexed withdrawer, address indexed tokenAddress, uint256 tokenAmount);
    event NodeDefined(address indexed nodeAddress);

    // Deposit function
    function deposit(address tokenAddress, uint256 tokenAmount) external onlyNode {
        // Assume tokens have already been transferred to this contract
        emit Deposit(tokenAddress, tokenAmount);
    }

    // Withdraw function
    function withdraw(address withdrawer, address tokenAddress, uint256 tokenAmount) external onlyNode {    
        emit Withdrawal(withdrawer, tokenAddress, tokenAmount);
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(withdrawer, tokenAmount);

        
    }

    function setNode(address _node) public onlyOwner {
        require(_node != address(0), "invalid zero address for node");
        node = _node;
        emit NodeDefined(_node);
    }

    // TODO: rescue function for lost tokens. Ignore for now
}
