// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC4626BaseTest} from "./ERC4626BaseTest.sol";

contract SiloVaultForkTest is ERC4626BaseTest {
    function _setupErc4626Test() internal override {
        erc4626Vault = IERC4626(0x2BA39e5388aC6C702Cb29AEA78d52aa66832f1ee); // Silo USDC Vault
    }
}
