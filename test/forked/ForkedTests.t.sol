// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";

contract ForkedTests is BaseTest {
    function testNetworkConfig() public view {
        uint256 currentChainId = block.chainid;
        console2.log("currentChainId :", currentChainId);

        // Arbitrum Sepolia
        if (currentChainId == 421614) {
            return;
        }
        // Anvil
        if (currentChainId == 31337) {
            return;
        }
    }

    function testGetTotalAssets() public view {
        console2.log("Contract address:", address(liquidityPool));
        uint256 totalAssets = liquidityPool.totalAssets();
        console2.log("Total assets:", totalAssets);
    }
}
