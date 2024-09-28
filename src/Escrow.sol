// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface IEscrow {
    function deposit(address tokenAddress, uint256 tokenAmount) external;
    function withdraw(address withdrawer, address tokenAddress, uint256 tokenAmount) external;
}

contract Escrow is IEscrow, Ownable {
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

    // Deposit function
    function deposit(address tokenAddress, uint256 tokenAmount) external onlyNode {
        // Assume tokens have already been transferred to this contract
        emit Deposit(tokenAddress, tokenAmount);
    }

    // Withdraw function
    function withdraw(address withdrawer, address tokenAddress, uint256 tokenAmount) external onlyNode {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(withdrawer, tokenAmount), "Transfer failed");
        emit Withdrawal(withdrawer, tokenAddress, tokenAmount);
    }

    function setNode(address _node) public onlyOwner {
        node = _node;
    }

    // TODO: rescue function for lost tokens. Ignore for now
}
