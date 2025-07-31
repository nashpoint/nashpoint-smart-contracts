// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC4626BaseTest} from "./ERC4626BaseTest.sol";

contract MorphoVaultForTest is ERC4626BaseTest {
    function _setupErc4626Test() internal override {
        erc4626Vault = IERC4626(0x7c574174DA4b2be3f705c6244B4BfA0815a8B3Ed); // Morpho - Gauntlet USDC Prime Vault
    }
}
