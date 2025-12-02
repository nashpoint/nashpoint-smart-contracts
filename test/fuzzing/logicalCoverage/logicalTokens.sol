// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LogicalTokens is BeforeAfter {
    function logicalTokens() internal {
        _checkTokenCatalogStates();
        _checkAssetSupplyStates();
        _checkTokenDistributionStates();
    }

    function _checkTokenCatalogStates() private {
        uint256 tokenCount = TOKENS.length;
        if (tokenCount == 0) {
            fl.log("TOKEN_catalog_empty");
        } else if (tokenCount <= 5) {
            fl.log("TOKEN_catalog_small");
        } else {
            fl.log("TOKEN_catalog_large");
        }

        if (DONATEES.length == 0) {
            fl.log("TOKEN_no_donatees");
        } else if (DONATEES.length > tokenCount) {
            fl.log("TOKEN_more_donatees_than_tokens");
        }
    }

    function _checkAssetSupplyStates() private {
        uint256 assetSupply = assetToken.totalSupply();
        uint256 stTokenSupply = stToken.totalSupply();

        if (assetSupply == 0) {
            fl.log("TOKEN_asset_supply_zero");
        } else if (assetSupply < 1_000_000 ether) {
            fl.log("TOKEN_asset_supply_small");
        } else {
            fl.log("TOKEN_asset_supply_large");
        }

        if (stTokenSupply == 0) {
            fl.log("TOKEN_sttoken_supply_zero");
        } else {
            fl.log("TOKEN_sttoken_supply_active");
        }
    }

    function _checkTokenDistributionStates() private {
        if (address(node) == address(0)) {
            return;
        }

        for (uint256 i = 0; i < TOKENS.length && i < 5; i++) {
            address tokenAddr = TOKENS[i];
            uint256 nodeBalance = IERC20(tokenAddr).balanceOf(address(node));
            uint256 escrowBalance = IERC20(tokenAddr).balanceOf(address(escrow));
            if (nodeBalance == 0 && escrowBalance == 0) {
                fl.log("TOKEN_unutilized_asset");
            } else if (nodeBalance > escrowBalance) {
                fl.log("TOKEN_node_holds_majority");
            } else {
                fl.log("TOKEN_escrow_holds_majority");
            }
        }
    }
}
