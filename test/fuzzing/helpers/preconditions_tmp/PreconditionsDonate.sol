// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PreconditionsDonate is PreconditionsBase {
    struct DonateParams {
        address token;
        address recipient;
        uint256 amount;
    }

    function preconditionsDonate(uint256 tokenSeed, uint256 recipientSeed, uint256 amount)
        internal
        returns (DonateParams memory params)
    {
        params.token = TOKENS[tokenSeed % TOKENS.length];
        params.recipient = DONATEES[recipientSeed % DONATEES.length];
        params.amount = fl.clamp(amount, 0, IERC20(params.token).balanceOf(currentActor));
    }
}
