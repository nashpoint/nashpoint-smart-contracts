// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20MockOwnable is ERC20, Ownable {
    uint8 private _decimals;

    constructor(string memory _name, string memory _symbol, uint8 decimals_)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
