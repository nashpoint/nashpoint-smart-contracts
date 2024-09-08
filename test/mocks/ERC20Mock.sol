// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private decimalValue;

    constructor(string memory name_, string memory symbol_, uint8 _decimalValue) ERC20(name_, symbol_) {
        decimalValue = _decimalValue;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return decimalValue;
    }

    function setDecimalValue(uint8 _newValue) public returns (uint8) {
        decimalValue = _newValue;
        return decimalValue;
    }
}
