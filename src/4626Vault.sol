// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

contract ERC4626Vault is ERC4626 {
    constructor(address _asset, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC4626(IERC20Metadata(_asset))
    {}
}
