// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    bool public failApprovals;
    uint8 private _decimals;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _decimals = 18; // Default to 18 decimals
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function setDecimals(uint8 newDecimals) external {
        _decimals = newDecimals;
    }

    function setFailApprovals(bool fail) external {
        failApprovals = fail;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        if (failApprovals) {
            return false;
        }
        return super.approve(spender, amount);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function setBalance(address account, uint256 amount) external {
        _burn(account, balanceOf(account));
        _mint(account, amount);
    }
}
