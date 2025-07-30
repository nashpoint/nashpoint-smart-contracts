// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC4626BaseTest} from "./ERC4626BaseTest.sol";

contract EulerVaultFortTest is ERC4626BaseTest {
    function _setupErc4626Test() internal override {
        erc4626Vault = IERC4626(0x0a1eCC5Fe8C9be3C809844fcBe615B46A869b899); // Euler USDC Vault
    }
}
