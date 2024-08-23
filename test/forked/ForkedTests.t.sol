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

    function testGetPoolData() public view {
        console2.log("Contract address:", address(liquidityPool));
        console2.log("Asset address:", liquidityPool.asset());

              
        // console2.log("Share address:", liquidityPool.share());        
        // console2.log("Total assets:", totalAssets);

        // get manager and pool id
    }
}
