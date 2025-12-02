// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LogicalDonate is BeforeAfter {
    function logicalDonate() internal {
        _checkDonationInventory();
        _checkDonationLiquidity();
    }

    function _checkDonationInventory() private {
        uint256 tokenCount = TOKENS.length;
        uint256 donateeCount = DONATEES.length;

        if (tokenCount == 0) {
            fl.log("DONATE_no_tokens_available");
        } else if (tokenCount <= 3) {
            fl.log("DONATE_small_token_pool");
        } else {
            fl.log("DONATE_large_token_pool");
        }

        if (donateeCount == 0) {
            fl.log("DONATE_no_donatees_available");
        } else if (donateeCount <= 5) {
            fl.log("DONATE_small_donatee_pool");
        } else {
            fl.log("DONATE_large_donatee_pool");
        }

        if (tokenCount > donateeCount) {
            fl.log("DONATE_tokens_outnumber_donatees");
        } else if (donateeCount > tokenCount) {
            fl.log("DONATE_donatees_outnumber_tokens");
        }
    }

    function _checkDonationLiquidity() private {
        for (uint256 i = 0; i < DONATEES.length && i < 5; i++) {
            address donatee = DONATEES[i];
            uint256 balance = asset.balanceOf(donatee);
            if (balance > 0) {
                fl.log("DONATE_donatee_funded");
            } else {
                fl.log("DONATE_donatee_unfunded");
            }
        }

        if (currentActor != address(0)) {
            uint256 actorTokenOptions;
            for (uint256 i = 0; i < TOKENS.length; i++) {
                IERC20 token = IERC20(TOKENS[i]);
                if (token.balanceOf(currentActor) > 0) {
                    actorTokenOptions++;
                }
            }

            if (actorTokenOptions == 0) {
                fl.log("DONATE_actor_cannot_donate");
            } else {
                fl.log("DONATE_actor_has_donation_balance");
            }
        }
    }
}
